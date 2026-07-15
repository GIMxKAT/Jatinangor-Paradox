--!strict
-- RoleService
--
-- Owns role assignment and is the single source of truth for "can this
-- player do this role-gated thing." Nothing else in the codebase should
-- decide role access independently.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local RoleConstants = require(ReplicatedStorage.Shared.Constants.RoleConstants)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("RoleService")

type Role = RoleConstants.Role

local RoleService = {}

local playerRoles: { [Player]: Role } = {}
local nextRoleIndex = 1
local DataService: any

function RoleService.Init(registry: { [string]: any })
    DataService = registry.Data
end

function RoleService.Start()
    Players.PlayerRemoving:Connect(function(player)
        playerRoles[player] = nil
    end)

    -- NOTE: In practice, call RoleService.AssignRole(player) from
    -- PlayerService/DataService's join flow *after* the profile has
    -- finished loading (see ARCHITECTURE.md §6.1) rather than here, since
    -- role assignment may depend on profile data (rejoin persistence).
end

-- Call this once DataService has finished loading the player's profile.
function RoleService.AssignRole(player: Player)
    local profile = DataService.GetProfile(player)
    local existingRole = profile and (profile.Data.role :: Role?)

    local role: Role
    if existingRole then
        role = existingRole
    else
        role = RoleConstants.All[nextRoleIndex]
        nextRoleIndex = (nextRoleIndex % #RoleConstants.All) + 1
        if profile then
            profile.Data.role = role
        end
    end

    playerRoles[player] = role

    -- Display-only replication. Any *gameplay* check still goes through
    -- RoleService.CanAccess on the server — this Attribute/remote is not
    -- itself a security boundary.
    player:SetAttribute("Role", role)
    Net.FireClient(player, RemoteNames.Role_Assigned, role)

    log:Info(("Assigned role %s to %s"):format(role, player.Name))
end

function RoleService.GetRole(player: Player): Role?
    return playerRoles[player]
end

-- The actual authorization check every mechanism interaction must call.
function RoleService.CanAccess(player: Player, requiredRole: Role): boolean
    return playerRoles[player] == requiredRole
end

return RoleService
