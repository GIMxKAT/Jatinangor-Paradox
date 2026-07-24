--!strict
-- FamilySystem (PlayArea)
--
-- Reads the TeleportData ReadyCheckSystem (Lobby) attached to the
-- Lobby -> PlayArea teleport: familyId (continuity identifier — see
-- FamilyRosterSystem in Lobby for why this, not the reserved-server access
-- code, is what threads a family across places) and roleAssignments (the
-- balancing result computed in the Lobby, handed over directly instead of
-- requiring a DataStore round-trip before the teleport even completes).
--
-- Every server instance in the PlayArea place is one reserved family
-- session — this system's job is exposing "who's in this family" and
-- "what role did the Lobby assign them" cleanly to everything else,
-- exactly like the original PlayerService did for the single-place design.

local Players = game:GetService("Players")

local FamilySystem = { Name = "FamilySystem", Dependencies = {} }

local familyId: string = "unknown-family"
local roleAssignmentsFromLobby: { [number]: string } = {}

-- Init() runs at server boot, before TeleportService has delivered any
-- teleporting player -- Players:GetPlayers() is reliably empty there, so
-- reading TeleportData only in Init() meant familyId/roleAssignments never
-- actually populated on a live server. Ingest per-player instead, on
-- PlayerAdded (and once for whoever is already present when Start() runs,
-- covering any player that connected between Init and Start).
local function ingestTeleportData(player: Player)
    local joinData = player:GetJoinData()
    local teleportData = joinData and joinData.TeleportData
    if teleportData and typeof(teleportData) == "table" then
        if typeof(teleportData.familyId) == "string" then
            familyId = teleportData.familyId
        end
        if typeof(teleportData.roleAssignments) == "table" then
            for userIdStr, role in teleportData.roleAssignments :: any do
                roleAssignmentsFromLobby[tonumber(userIdStr) or userIdStr] = role
            end
        end
    end
end

function FamilySystem.Init(_registry: { [string]: any }) end

function FamilySystem.Start()
    Players.PlayerAdded:Connect(ingestTeleportData)
    for _, player in Players:GetPlayers() do
        ingestTeleportData(player)
    end
end

function FamilySystem.GetFamilyId(): string
    return familyId
end

function FamilySystem.GetFamilyPlayers(): { Player }
    -- Every server instance in this place is single-family, so this is
    -- simply every connected player. Kept as its own function so the rest
    -- of the codebase never assumes "all players in this server" directly.
    return Players:GetPlayers()
end

-- The role the Lobby's RoleBalancingSystem assigned this player before
-- teleport, if any (absent for a player who joined this server directly,
-- e.g. in-Studio testing without going through Hub/Lobby).
function FamilySystem.GetRoleFromLobby(player: Player): string?
    return roleAssignmentsFromLobby[player.UserId]
end

return FamilySystem
