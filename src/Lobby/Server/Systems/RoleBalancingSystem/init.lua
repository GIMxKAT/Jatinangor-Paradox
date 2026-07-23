--!strict
-- RoleBalancingSystem (Lobby)
--
-- Spreads the family (~20-25 players) across the 5 roles (Navigator,
-- Detective, Scout, Code-Breaker, Support) as evenly as possible, honoring
-- each player's stated preference where it doesn't unbalance the family.
-- This is what the prerequisite diagram's "Auto balancing" step is: player
-- stats/preference in, an assigned role out, before Amphiteater.
--
-- Players may request a preferred role (Lobby_RequestRole) at any time
-- before the ready check locks in; the server is always the one that
-- performs the actual assignment (client preference is advisory only —
-- same server-authoritative rule as everything else in this codebase, see
-- docs/ARCHITECTURE.md §1).
--
-- Algorithm (documented so it's easy to swap later without touching
-- callers): greedy balanced-preference assignment.
--   1. Compute the target ceiling per role: ceil(memberCount / 5).
--   2. Walk members in join order; assign each to their preferred role if
--      that role is currently below the ceiling, otherwise assign to
--      whichever role currently has the fewest members (ties broken by
--      role declaration order in RoleConstants.All).
-- This guarantees no role exceeds the ceiling by more than one member and
-- respects preference whenever the family size allows it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local RoleConstants = require(ReplicatedStorage.Shared.Constants.RoleConstants)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

type Role = RoleConstants.Role

local log = Log.new("RoleBalancingSystem")

local RoleBalancingSystem =
    { Name = "RoleBalancingSystem", Dependencies = { "FamilyRosterSystem" } }

local FamilyRosterSystem: any

local function broadcastAssignments()
    local roster = FamilyRosterSystem.GetRoster()
    -- Keyed by tostring(UserId) -- see ReadyCheckSystem.broadcastReadyState
    -- for why numeric UserId keys don't survive a RemoteEvent round-trip.
    local assignments: { [string]: string } = {}
    for player, member in roster do
        if member.assignedRole then
            assignments[tostring(player.UserId)] = member.assignedRole
        end
    end
    Net.FireClients(
        FamilyRosterSystem.GetMembers(),
        RemoteNames.Lobby_RoleAssignmentsUpdated,
        assignments
    )
end

function RoleBalancingSystem.AutoBalance()
    local roster = FamilyRosterSystem.GetRoster()
    local members = FamilyRosterSystem.GetMembers()
    local memberCount = #members
    if memberCount == 0 then
        return
    end

    local ceiling = math.ceil(memberCount / #RoleConstants.All)
    local countPerRole: { [Role]: number } = {}
    for _, role in RoleConstants.All do
        countPerRole[role] = 0
    end

    for _, player in members do
        local rosterMember = roster[player]
        if not rosterMember then
            continue
        end

        local chosen: Role? = nil
        local preferred = rosterMember.preferredRole :: Role?
        if preferred and countPerRole[preferred] and countPerRole[preferred] < ceiling then
            chosen = preferred
        else
            local lowestRole: Role = RoleConstants.All[1]
            local lowestCount = countPerRole[lowestRole]
            for _, role in RoleConstants.All do
                if countPerRole[role] < lowestCount then
                    lowestRole = role
                    lowestCount = countPerRole[role]
                end
            end
            chosen = lowestRole
        end

        rosterMember.assignedRole = chosen
        countPerRole[chosen] = countPerRole[chosen] + 1
    end

    broadcastAssignments()
    log:Info(("Auto-balanced %d members across %d roles"):format(memberCount, #RoleConstants.All))
end

function RoleBalancingSystem.Init(registry: { [string]: any })
    FamilyRosterSystem = registry.FamilyRosterSystem
end

function RoleBalancingSystem.Start()
    Net.OnServerEvent(RemoteNames.Lobby_RequestRole, function(player, role)
        if typeof(role) ~= "string" then
            return
        end
        local isValidRole = table.find(RoleConstants.All, role) ~= nil
        if not isValidRole then
            return
        end

        local roster = FamilyRosterSystem.GetRoster()
        local member = roster[player]
        if member then
            member.preferredRole = role :: Role
            RoleBalancingSystem.AutoBalance() -- re-balance live so the UI updates as preferences change
        end
    end)
end

return RoleBalancingSystem
