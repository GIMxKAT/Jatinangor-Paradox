--!strict
-- InventoryController — mirrors InventorySystem's ADAPTER NOTE: thin relay,
-- should need no changes when the real inventory implementation replaces
-- the server-side reference version, as long as the Inventory_Updated
-- payload shape ({[itemId]: count}) is kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local InventoryController = { Name = "InventoryController", Dependencies = {} }

InventoryController.InventoryUpdated = Signal.new() -- ({[itemId]: count})

local familyInventory: { [string]: number } = {}

function InventoryController.Start()
    Net.OnClientEvent(RemoteNames.Inventory_Updated, function(inventory: { [string]: number })
        familyInventory = inventory
        InventoryController.InventoryUpdated:Fire(inventory)
    end)
end

function InventoryController.GetFamilyInventory(): { [string]: number }
    return familyInventory
end

function InventoryController.UseItem(itemId: string)
    Net.FireServer(RemoteNames.Inventory_UseItem, itemId)
end

return InventoryController
