--!strict
-- MatchmakingSystem (Hub)
--
-- Owns invite-code family grouping while players are still standing
-- together in a public Hub server, then hands off to
-- SessionAdmissionSystem to gate the actual Lobby teleport behind the
-- event-wide concurrency cap.
--
-- Flow:
--   1. A player fires Hub_CreateFamily -> becomes the family leader,
--      gets a 6-character invite code back via Hub_FamilyUpdated.
--   2. Other players fire Hub_JoinFamily(code) -> join that pending
--      family, still standing in this same Hub server (this is exactly
--      what "Spawn ke Lobby, yang bisa masuk cuma yang pake invite code
--      yang sama" describes: only players who typed the same code end up
--      teleported into the same Lobby/PlayArea reserved server).
--   3. The leader fires Hub_StartFamily -> MatchmakingSystem asks
--      SessionAdmissionSystem for a slot. If the concurrency cap is full,
--      the family stays queued in the Hub and retries on a short
--      interval, with Hub_QueueStatus updates so the UI can show
--      "waiting for a slot" instead of looking frozen. Once admitted, the
--      whole family is reserved into the Lobby place together, carrying
--      familyId + accessCode as TeleportData so Lobby/PlayArea can re-use
--      the same reserved server for both stages.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("MatchmakingSystem")

-- Multi-place Universe created in Studio (docs/ARCHITECTURE.md §3).
local LOBBY_PLACE_ID = 75501887739491

local ADMISSION_RETRY_SECONDS = 5
local INVITE_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no ambiguous chars (I/O/0/1)
local INVITE_CODE_LENGTH = 6

type PendingFamily = {
    familyId: string,
    accessCode: string,
    leaderUserId: number,
    members: { Player },
    cancelled: boolean,
}

local MatchmakingSystem =
    { Name = "MatchmakingSystem", Dependencies = { "SessionAdmissionSystem" } }

local pendingByCode: { [string]: PendingFamily } = {}
local codeByPlayer: { [Player]: string } = {}

local SessionAdmissionSystem: any

local function generateInviteCode(): string
    local code: string
    repeat
        local chars = {}
        for _ = 1, INVITE_CODE_LENGTH do
            local idx = math.random(1, #INVITE_CODE_ALPHABET)
            table.insert(chars, INVITE_CODE_ALPHABET:sub(idx, idx))
        end
        code = table.concat(chars)
    until not pendingByCode[code]
    return code
end

local function broadcastRoster(family: PendingFamily)
    local names = {}
    for _, p in family.members do
        table.insert(names, p.Name)
    end
    Net.FireClients(family.members, RemoteNames.Hub_FamilyUpdated, {
        accessCode = family.accessCode,
        leaderUserId = family.leaderUserId,
        memberNames = names,
    })
end

local function removePlayerFromFamily(player: Player)
    local code = codeByPlayer[player]
    if not code then
        return
    end
    codeByPlayer[player] = nil

    local family = pendingByCode[code]
    if not family then
        return
    end

    for i, p in family.members do
        if p == player then
            table.remove(family.members, i)
            break
        end
    end

    if #family.members == 0 then
        family.cancelled = true
        pendingByCode[code] = nil
        return
    end

    if family.leaderUserId == player.UserId then
        family.leaderUserId = family.members[1].UserId
    end

    broadcastRoster(family)
end

local function handleCreateFamily(player: Player)
    removePlayerFromFamily(player)

    local code = generateInviteCode()
    local family: PendingFamily = {
        familyId = code, -- the invite code doubles as the familyId; unique among pending families
        accessCode = "",
        leaderUserId = player.UserId,
        members = { player },
        cancelled = false,
    }
    pendingByCode[code] = family
    codeByPlayer[player] = code

    broadcastRoster(family)
    log:Info(("%s created family %s"):format(player.Name, code))
end

local function handleJoinFamily(player: Player, code: unknown)
    if typeof(code) ~= "string" then
        return
    end
    local normalized = code:upper()
    local family = pendingByCode[normalized]
    if not family then
        Net.FireClient(player, RemoteNames.Hub_QueueStatus, { state = "InvalidCode" })
        return
    end

    removePlayerFromFamily(player)
    table.insert(family.members, player)
    codeByPlayer[player] = normalized

    broadcastRoster(family)
    log:Info(("%s joined family %s"):format(player.Name, normalized))
end

local function teleportFamily(family: PendingFamily)
    if LOBBY_PLACE_ID == 0 then
        log:Error(
            "LOBBY_PLACE_ID is not configured — cannot teleport. See TODO(ops) in this file."
        )
        return
    end

    -- ReserveServer also returns a privateServerId; not needed here since
    -- accessCode is sufficient to TeleportToPrivateServer.
    local reserveOk, accessCodeOrErr = pcall(function()
        return TeleportService:ReserveServer(LOBBY_PLACE_ID)
    end)

    if not reserveOk then
        log:Error(
            ("ReserveServer failed for family %s: %s"):format(
                family.familyId,
                tostring(accessCodeOrErr)
            )
        )
        SessionAdmissionSystem.Release(family.familyId)
        Net.FireClients(family.members, RemoteNames.Hub_QueueStatus, { state = "TeleportFailed" })
        return
    end

    family.accessCode = accessCodeOrErr :: string

    local teleportOk, teleportErr = pcall(function()
        TeleportService:TeleportToPrivateServer(
            LOBBY_PLACE_ID,
            family.accessCode,
            family.members,
            nil,
            { familyId = family.familyId, accessCode = family.accessCode }
        )
    end)

    if not teleportOk then
        log:Error(
            ("TeleportToPrivateServer failed for family %s: %s"):format(
                family.familyId,
                tostring(teleportErr)
            )
        )
        SessionAdmissionSystem.Release(family.familyId)
        Net.FireClients(family.members, RemoteNames.Hub_QueueStatus, { state = "TeleportFailed" })
        return
    end

    -- From here, delivering the family into the Lobby is Roblox's job. The
    -- admission slot stays held for the family's entire Lobby+PlayArea
    -- session; PlayArea's GameSystem releases it on session end (see
    -- docs/ARCHITECTURE.md §8.3 for the known crash-before-release gap).
    pendingByCode[family.accessCode] = nil -- stop tracking as a Hub-local pending family
    for _, p in family.members do
        codeByPlayer[p] = nil
    end
end

local function tryStartFamily(family: PendingFamily)
    task.spawn(function()
        while not family.cancelled do
            if SessionAdmissionSystem.TryAdmit(family.familyId) then
                teleportFamily(family)
                return
            end

            Net.FireClients(
                family.members,
                RemoteNames.Hub_QueueStatus,
                { state = "WaitingForSlot" }
            )
            task.wait(ADMISSION_RETRY_SECONDS)
        end
    end)
end

local function handleStartFamily(player: Player)
    local code = codeByPlayer[player]
    local family = code and pendingByCode[code]
    if not family then
        return
    end
    if family.leaderUserId ~= player.UserId then
        return -- only the leader may start the session
    end

    tryStartFamily(family)
end

function MatchmakingSystem.Init(registry: { [string]: any })
    SessionAdmissionSystem = registry.SessionAdmissionSystem
end

function MatchmakingSystem.Start()
    Players.PlayerRemoving:Connect(removePlayerFromFamily)

    Net.OnServerEvent(RemoteNames.Hub_CreateFamily, function(player)
        handleCreateFamily(player)
    end)

    Net.OnServerEvent(RemoteNames.Hub_JoinFamily, function(player, code)
        handleJoinFamily(player, code)
    end)

    Net.OnServerEvent(RemoteNames.Hub_StartFamily, function(player)
        handleStartFamily(player)
    end)
end

return MatchmakingSystem
