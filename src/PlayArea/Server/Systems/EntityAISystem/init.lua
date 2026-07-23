--!strict
-- EntityAISystem (PlayArea)
--
-- Spawns/starts behavior for tagged AI entities (NPCs, creatures — the
-- diagram's "Entity AI System" branching into NPC / Ular Jatinangor /
-- Laba-laba Jatinangor). Builders tag a Model "AIEntity" and set an
-- EntityType Attribute referencing a content plugin under Entities/
-- (loaded via ContentRegistry) implementing OnSpawn. Adding a new
-- creature TYPE is a new folder there; placing another instance of an
-- existing type is pure Studio tagging, no code.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local ContentRegistry = require(ReplicatedStorage.Shared.Registry.ContentRegistry)
local Types = require(ReplicatedStorage.Shared.Types.Types)

local log = Log.new("EntityAISystem")

local AI_ENTITY_TAG = "AIEntity"

local EntityAISystem = { Name = "EntityAISystem", Dependencies = {} }

local entityTypes: { [string]: Types.EntityDefinition } = {}
local spawnedInstances: { [Instance]: boolean } = {}
local systemRegistry: { [string]: any } = {}

local function spawnInstance(instance: Instance)
    if spawnedInstances[instance] then
        return
    end

    local entityType = instance:GetAttribute("EntityType")
    if typeof(entityType) ~= "string" then
        log:Warn(
            ("Instance %s tagged '%s' is missing an EntityType Attribute — skipping"):format(
                instance:GetFullName(),
                AI_ENTITY_TAG
            )
        )
        return
    end

    local definition = entityTypes[entityType]
    if not definition then
        log:Warn(
            ("Instance %s references EntityType '%s' with no registered implementation under Entities/ — skipping"):format(
                instance:GetFullName(),
                entityType
            )
        )
        return
    end

    spawnedInstances[instance] = true
    local ok, err = pcall(definition.OnSpawn, instance, { registry = systemRegistry })
    if not ok then
        log:Error(("Entity '%s' OnSpawn errored: %s"):format(entityType, tostring(err)))
    end
end

function EntityAISystem.Init(registry: { [string]: any })
    systemRegistry = registry
    entityTypes = ContentRegistry.Load(script.Entities, "Entities") :: any
end

function EntityAISystem.Start()
    for _, instance in CollectionService:GetTagged(AI_ENTITY_TAG) do
        spawnInstance(instance)
    end
    CollectionService:GetInstanceAddedSignal(AI_ENTITY_TAG):Connect(spawnInstance)
    CollectionService:GetInstanceRemovedSignal(AI_ENTITY_TAG):Connect(function(instance)
        spawnedInstances[instance] = nil
    end)
end

return EntityAISystem
