--!strict
-- ItemSystem (PlayArea)
--
-- World-placed, interactable items (the diagram's "item system": UV
-- light, smart decoder, tablet ajaib, ...). Two layers, same split as
-- DoorLockSystem/mechanisms:
--   - PLACEMENT is data: builders tag a Part/Model with CollectionService
--     tag "WorldItem" and set Attributes WorldItemId (unique per placed
--     instance, e.g. "UVLight_GreenhouseShelf"), ItemType (which content
--     plugin handles it, e.g. "UVLight"), and optionally RequiredRole. No
--     scripter involvement to place a new instance of an existing item
--     type.
--   - BEHAVIOR is code: each ItemType is a content plugin under Items/
--     (loaded via ContentRegistry) implementing OnInteract. Adding a new
--     item TYPE is a new folder there, zero edits here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ContentRegistry = require(ReplicatedStorage.Shared.Registry.ContentRegistry)
local Types = require(ReplicatedStorage.Shared.Types.Types)

local log = Log.new("ItemSystem")

local WORLD_ITEM_TAG = "WorldItem"
local MAX_INTERACT_DISTANCE = 10 -- studs; tune once level design lands

type PlacedItem = {
    instance: Instance,
    worldItemId: string,
    itemType: string,
    requiredRole: string?,
}

local ItemSystem = { Name = "ItemSystem", Dependencies = { "RoleSystem", "FamilySystem" } }

local itemTypes: { [string]: Types.ItemDefinition } = {}
local placedItems: { [string]: PlacedItem } = {}

local RoleSystem: any
local FamilySystem: any
local systemRegistry: { [string]: any } = {}

local function registerInstance(instance: Instance)
    local worldItemId = instance:GetAttribute("WorldItemId")
    local itemType = instance:GetAttribute("ItemType")

    if not (typeof(worldItemId) == "string" and typeof(itemType) == "string") then
        log:Warn(
            ("Instance %s tagged '%s' is missing WorldItemId/ItemType Attributes — skipping"):format(
                instance:GetFullName(),
                WORLD_ITEM_TAG
            )
        )
        return
    end

    if not itemTypes[itemType] then
        log:Warn(
            ("Instance %s references ItemType '%s' with no registered implementation under Items/ — skipping"):format(
                instance:GetFullName(),
                itemType
            )
        )
        return
    end

    if placedItems[worldItemId] then
        log:Warn(
            ("Instance %s has WorldItemId '%s', already registered by %s — skipping (WorldItemId must be unique per placed instance)"):format(
                instance:GetFullName(),
                worldItemId,
                placedItems[worldItemId].instance:GetFullName()
            )
        )
        return
    end

    placedItems[worldItemId] = {
        instance = instance,
        worldItemId = worldItemId,
        itemType = itemType,
        requiredRole = instance:GetAttribute("RequiredRole") :: string?,
    }
end

local function handleInteract(player: Player, worldItemId: unknown)
    if typeof(worldItemId) ~= "string" then
        return
    end

    local placed = placedItems[worldItemId]
    if not placed then
        return
    end

    if not RoleSystem.CanAccess(player, placed.requiredRole) then
        return
    end

    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local itemPart = placed.instance:IsA("BasePart") and placed.instance
        or placed.instance:FindFirstChildWhichIsA("BasePart")
    if not (rootPart and itemPart) then
        return
    end
    if (rootPart.Position - itemPart.Position).Magnitude > MAX_INTERACT_DISTANCE then
        return
    end

    local definition = itemTypes[placed.itemType]
    local context = {
        familyPlayers = FamilySystem.GetFamilyPlayers(),
        registry = systemRegistry,
    }

    local ok, accepted = pcall(definition.OnInteract, player, placed.instance, context)
    if not ok then
        log:Error(("Item '%s' OnInteract errored: %s"):format(placed.itemType, tostring(accepted)))
        return
    end

    if accepted then
        Net.FireClients(
            FamilySystem.GetFamilyPlayers(),
            RemoteNames.Item_WorldStateUpdated,
            worldItemId
        )
    end
end

function ItemSystem.Init(registry: { [string]: any })
    RoleSystem = registry.RoleSystem
    FamilySystem = registry.FamilySystem
    systemRegistry = registry
    itemTypes = ContentRegistry.Load(script.Items, "Items") :: any
end

function ItemSystem.Start()
    for _, instance in CollectionService:GetTagged(WORLD_ITEM_TAG) do
        registerInstance(instance)
    end
    CollectionService:GetInstanceAddedSignal(WORLD_ITEM_TAG):Connect(registerInstance)
    CollectionService:GetInstanceRemovedSignal(WORLD_ITEM_TAG):Connect(function(instance)
        for id, placed in placedItems do
            if placed.instance == instance then
                placedItems[id] = nil
            end
        end
    end)

    Net.OnServerEvent(
        RemoteNames.Item_Interact,
        handleInteract,
        5 --[[ max 5 interactions/sec/player ]]
    )
end

return ItemSystem
