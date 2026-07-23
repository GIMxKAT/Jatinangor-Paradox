--!strict
-- ReadyCheckSystem (Lobby)
--
-- Once every member has readied up (post role-balancing), mints a FRESH
-- reserved server for the PlayArea place and teleports the whole family
-- there together. A reserved-server access code from ReserveServer is only
-- valid for the placeId it was reserved against, so this is a genuinely
-- new ReserveServer(PLAYAREA_PLACE_ID) call, not a re-use of the Hub ->
-- Lobby access code — familyId (carried in TeleportData both times) is
-- what actually threads the family's identity across all three places.
--
-- Role assignments are handed to PlayArea directly via TeleportData rather
-- than requiring a DataStore round-trip before the teleport — RoleSystem
-- in PlayArea still persists them to the player's profile once loaded, so
-- a later rejoin-into-the-same-session restores the same role (see
-- PlayArea/Server/Systems/RoleSystem).

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("ReadyCheckSystem")

-- Multi-place Universe created in Studio (docs/ARCHITECTURE.md §3).
local PLAYAREA_PLACE_ID = 131820325951907
local COUNTDOWN_SECONDS = 5

local ReadyCheckSystem =
    { Name = "ReadyCheckSystem", Dependencies = { "FamilyRosterSystem", "RoleBalancingSystem" } }

local FamilyRosterSystem: any
local countdownActive = false

local function allReady(): boolean
    local roster = FamilyRosterSystem.GetRoster()
    local members = FamilyRosterSystem.GetMembers()
    if #members == 0 then
        return false
    end
    for _, player in members do
        local member = roster[player]
        if not member or not member.ready or not member.assignedRole then
            return false
        end
    end
    return true
end

local function broadcastReadyState()
    local roster = FamilyRosterSystem.GetRoster()
    local state: { [number]: boolean } = {}
    for player, member in roster do
        state[player.UserId] = member.ready
    end
    Net.FireClients(FamilyRosterSystem.GetMembers(), RemoteNames.Lobby_ReadyStateUpdated, state)
end

local function teleportToPlayArea()
    if PLAYAREA_PLACE_ID == 0 then
        log:Error(
            "PLAYAREA_PLACE_ID is not configured — cannot teleport. See TODO(ops) in this file."
        )
        return
    end

    local familyId = FamilyRosterSystem.GetFamilyId()
    local roster = FamilyRosterSystem.GetRoster()
    local members = FamilyRosterSystem.GetMembers()

    local roleAssignments: { [number]: string } = {}
    for player, member in roster do
        if member.assignedRole then
            roleAssignments[player.UserId] = member.assignedRole
        end
    end

    local reserveOk, accessCodeOrErr = pcall(function()
        return TeleportService:ReserveServer(PLAYAREA_PLACE_ID)
    end)
    if not reserveOk then
        log:Error(
            ("ReserveServer(PlayArea) failed for family %s: %s"):format(
                familyId,
                tostring(accessCodeOrErr)
            )
        )
        return
    end

    local teleportOk, teleportErr = pcall(function()
        TeleportService:TeleportToPrivateServer(
            PLAYAREA_PLACE_ID,
            accessCodeOrErr :: string,
            members,
            nil,
            { familyId = familyId, roleAssignments = roleAssignments }
        )
    end)
    if not teleportOk then
        log:Error(
            ("TeleportToPrivateServer(PlayArea) failed for family %s: %s"):format(
                familyId,
                tostring(teleportErr)
            )
        )
    end
end

local function beginCountdownIfReady()
    if countdownActive or not allReady() then
        return
    end
    countdownActive = true

    task.spawn(function()
        for secondsLeft = COUNTDOWN_SECONDS, 1, -1 do
            if not allReady() then
                countdownActive = false
                Net.FireClients(FamilyRosterSystem.GetMembers(), RemoteNames.Lobby_Countdown, nil)
                return
            end
            Net.FireClients(
                FamilyRosterSystem.GetMembers(),
                RemoteNames.Lobby_Countdown,
                secondsLeft
            )
            task.wait(1)
        end

        if allReady() then
            teleportToPlayArea()
        end
        countdownActive = false
        -- Always clear the countdown display once the loop ends, whether the
        -- teleport succeeded (players are leaving anyway) or failed (e.g. the
        -- Studio-only ReserveServer 403) -- otherwise the label freezes on
        -- "1" forever since no further Lobby_Countdown event would fire.
        Net.FireClients(FamilyRosterSystem.GetMembers(), RemoteNames.Lobby_Countdown, nil)
    end)
end

function ReadyCheckSystem.Init(registry: { [string]: any })
    FamilyRosterSystem = registry.FamilyRosterSystem
    -- RoleBalancingSystem is declared as a Dependency purely to guarantee
    -- boot order (it must exist before players can have an assignedRole);
    -- this system never calls into it directly, it just reads
    -- member.assignedRole via FamilyRosterSystem's shared roster table.
end

function ReadyCheckSystem.Start()
    Net.OnServerEvent(RemoteNames.Lobby_SetReady, function(player, isReady)
        if typeof(isReady) ~= "boolean" then
            return
        end
        local roster = FamilyRosterSystem.GetRoster()
        local member = roster[player]
        if member then
            member.ready = isReady
            broadcastReadyState()
            beginCountdownIfReady()
        end
    end)
end

return ReadyCheckSystem
