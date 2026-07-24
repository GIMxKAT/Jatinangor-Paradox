--!strict
-- RoleSystem (PlayArea)
--
-- Owns role assignment and is the single source of truth for "can this
-- player do this role-gated thing." Nothing else in the codebase should
-- decide role access independently.
--
-- Assignment priority: (1) role the Lobby's RoleBalancingSystem already
-- computed, handed over via TeleportData through FamilySystem — this is
-- the normal path; (2) role persisted on the player's profile from a
-- previous session (rejoin-after-disconnect restores the same role); (3)
-- round-robin fallback, only reachable in Studio testing where a player
-- joined this PlayArea server directly without going through Hub/Lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local RoleConstants = require(ReplicatedStorage.Shared.Constants.RoleConstants)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("RoleSystem")

type Role = RoleConstants.Role

local RoleSystem = { Name = "RoleSystem", Dependencies = { "DataSystem", "FamilySystem" } }

local playerRoles: { [Player]: Role } = {}
local nextRoleIndex = 1
local DataSystem: any
local FamilySystem: any

function RoleSystem.Init(registry: { [string]: any })
    DataSystem = registry.DataSystem
    FamilySystem = registry.FamilySystem
end

function RoleSystem.Start()
    Players.PlayerRemoving:Connect(function(player)
        playerRoles[player] = nil
    end)

    -- Assign once the profile is actually loaded (fallback assignment
    -- reads profile.Data.role) — see docs/ARCHITECTURE.md §6.1.
    DataSystem.ProfileLoaded:Connect(RoleSystem.AssignRole)
end

function RoleSystem.AssignRole(player: Player)
    local lobbyRole = FamilySystem.GetRoleFromLobby(player) :: Role?
    local profile = DataSystem.GetProfile(player)
    local persistedRole = profile and (profile.Data.role :: Role?)

    local role: Role
    if lobbyRole then
        role = lobbyRole
    elseif persistedRole then
        role = persistedRole
    else
        role = RoleConstants.All[nextRoleIndex]
        nextRoleIndex = (nextRoleIndex % #RoleConstants.All) + 1
    end

    if profile then
        profile.Data.role = role
    end

    playerRoles[player] = role

    -- Display-only replication. Any *gameplay* check still goes through
    -- RoleSystem.CanAccess on the server — this Attribute/remote is not
    -- itself a security boundary.
    player:SetAttribute("Role", role)
    Net.FireClient(player, RemoteNames.Role_Assigned, role)

    log:Info(("Assigned role %s to %s"):format(role, player.Name))
end

function RoleSystem.GetRole(player: Player): Role?
    return playerRoles[player]
end

-- The actual authorization check every mechanism/item/skill interaction
-- must call. `requiredRole = nil` means "any role may interact."
function RoleSystem.CanAccess(player: Player, requiredRole: Role?): boolean
    if requiredRole == nil then
        return true
    end
    return playerRoles[player] == requiredRole
end

return RoleSystem
