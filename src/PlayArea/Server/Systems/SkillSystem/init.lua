--!strict
-- SkillSystem (PlayArea)
--
-- Executes the per-role abilities the user asked to be "scalable later":
-- adding a new skill is dropping a module under Skills/<SkillName>/init.lua
-- returning a Shared.Types.SkillDefinition (Id, DisplayName, Description,
-- CooldownSeconds, Execute) — no edit to this file, RoleSystem, or
-- RoleDefinitions.lua's SkillIds list beyond adding the new Id to whichever
-- role(s) should have it. ContentRegistry (Shared/Registry) does the
-- actual folder-scanning + Id-indexing; this System is just the runtime
-- (ownership check, cooldown, dispatch) on top of that index.
--
-- Ownership + cooldown are re-validated server-side on every activation —
-- same server-authoritative rule as every other gameplay decision in this
-- codebase (docs/ARCHITECTURE.md §1). A skill's own Execute function may
-- assume ownership was already checked, but should still guard against
-- mutating shared state unsafely (e.g. re-check target validity).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local RoleDefinitions = require(ReplicatedStorage.Shared.Content.RoleDefinitions)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ContentRegistry = require(ReplicatedStorage.Shared.Registry.ContentRegistry)
local Types = require(ReplicatedStorage.Shared.Types.Types)

local log = Log.new("SkillSystem")

local SkillSystem = { Name = "SkillSystem", Dependencies = { "RoleSystem", "FamilySystem" } }

local skills: { [string]: Types.SkillDefinition } = {}
local lastActivatedAt: { [Player]: { [string]: number } } = {}

local RoleSystem: any
local FamilySystem: any
local systemRegistry: { [string]: any } = {}

local function validateRoleSkillMappings()
    for role, definition in RoleDefinitions do
        for _, skillId in definition.SkillIds do
            if not skills[skillId] then
                log:Warn(
                    ("RoleDefinitions.%s references skill '%s' which has no registered implementation under Skills/ — that ability will be a no-op until it's added"):format(
                        role,
                        skillId
                    )
                )
            end
        end
    end
end

local function roleOwnsSkill(role: string?, skillId: string): boolean
    if not role then
        return false
    end
    local definition = RoleDefinitions[role]
    return definition ~= nil and table.find(definition.SkillIds, skillId) ~= nil
end

local function handleActivate(player: Player, skillId: unknown)
    if typeof(skillId) ~= "string" then
        return
    end

    local skill = skills[skillId]
    if not skill then
        return
    end

    local role = RoleSystem.GetRole(player)
    if not roleOwnsSkill(role, skillId) then
        return
    end

    local playerCooldowns = lastActivatedAt[player]
    if not playerCooldowns then
        playerCooldowns = {}
        lastActivatedAt[player] = playerCooldowns
    end

    local now = os.clock()
    local last = playerCooldowns[skillId]
    if last and now - last < skill.CooldownSeconds then
        return
    end

    -- `registry` is handed through so a skill can reach another System's
    -- *public* API (e.g. Support_TeamAssist calling PlayerStatsSystem.Restore)
    -- the same way any System does — via the injected registry, never a
    -- raw cross-file require. Skills are content plugins, not Systems
    -- themselves, so PluginRegistry never injects a registry into them
    -- directly; SkillSystem forwards its own here instead.
    local context = { familyPlayers = FamilySystem.GetFamilyPlayers(), registry = systemRegistry }
    local ok, succeeded = pcall(skill.Execute, player, context)
    if not ok then
        log:Error(
            ("Skill '%s' Execute errored for %s: %s"):format(
                skillId,
                player.Name,
                tostring(succeeded)
            )
        )
        return
    end
    if not succeeded then
        return
    end

    playerCooldowns[skillId] = now
    Net.FireClients(
        FamilySystem.GetFamilyPlayers(),
        RemoteNames.Skill_Activated,
        player.UserId,
        skillId
    )
    Net.FireClient(player, RemoteNames.Skill_CooldownUpdated, skillId, skill.CooldownSeconds)
end

function SkillSystem.Init(registry: { [string]: any })
    RoleSystem = registry.RoleSystem
    FamilySystem = registry.FamilySystem
    systemRegistry = registry
    skills = ContentRegistry.Load(script.Skills, "Skills") :: any
    validateRoleSkillMappings()
end

function SkillSystem.Start()
    local Players = game:GetService("Players")
    Players.PlayerRemoving:Connect(function(player)
        lastActivatedAt[player] = nil
    end)

    Net.OnServerEvent(
        RemoteNames.Skill_Activate,
        handleActivate,
        3 --[[ max 3 activations/sec/player ]]
    )
end

return SkillSystem
