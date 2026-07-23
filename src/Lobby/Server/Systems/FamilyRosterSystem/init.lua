--!strict
-- FamilyRosterSystem (Lobby)
--
-- Owns "who is in this family" for the Lobby place. Reads familyId from
-- the TeleportData MatchmakingSystem (Hub) attached to the
-- TeleportToPrivateServer call. familyId — NOT the reserved-server access
-- code — is the durable identifier that follows a family across all three
-- places: a reserved-server access code is scoped to one specific place
-- (TeleportService:ReserveServer(placeId) mints a code valid only for that
-- placeId), so Lobby -> PlayArea requires ReadyCheckSystem to mint its OWN
-- fresh access code via a new ReserveServer(PLAYAREA_PLACE_ID) call — see
-- that system for the actual teleport. familyId is what ties the whole
-- journey together (and is also the SessionAdmission counter's key).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("FamilyRosterSystem")

export type RosterMember = {
    player: Player,
    preferredRole: string?,
    assignedRole: string?,
    ready: boolean,
}

local FamilyRosterSystem = { Name = "FamilyRosterSystem", Dependencies = {} }

local familyId: string = "unknown-family"
local roster: { [Player]: RosterMember } = {}

local function registerPlayer(player: Player)
    local joinData = player:GetJoinData()
    local teleportData = joinData and joinData.TeleportData

    if
        teleportData
        and typeof(teleportData) == "table"
        and typeof(teleportData.familyId) == "string"
    then
        if familyId == "unknown-family" then
            familyId = teleportData.familyId
        elseif familyId ~= teleportData.familyId then
            -- Should never happen: MatchmakingSystem only ever teleports one
            -- family per reserved server. Log loudly if it does.
            log:Error(
                ("Player %s arrived with familyId '%s' but this server is already familyId '%s'"):format(
                    player.Name,
                    teleportData.familyId,
                    familyId
                )
            )
        end
    else
        log:Warn(
            ("%s joined with no/invalid TeleportData.familyId — did they connect to this server directly instead of via MatchmakingSystem?"):format(
                player.Name
            )
        )
    end

    roster[player] = { player = player, preferredRole = nil, assignedRole = nil, ready = false }
end

function FamilyRosterSystem.Start()
    Players.PlayerAdded:Connect(registerPlayer)
    for _, player in Players:GetPlayers() do
        registerPlayer(player)
    end

    Players.PlayerRemoving:Connect(function(player)
        roster[player] = nil
    end)
end

function FamilyRosterSystem.GetFamilyId(): string
    return familyId
end

function FamilyRosterSystem.GetRoster(): { [Player]: RosterMember }
    return roster
end

function FamilyRosterSystem.GetMembers(): { Player }
    return Players:GetPlayers()
end

return FamilyRosterSystem
