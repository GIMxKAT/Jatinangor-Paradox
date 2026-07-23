--!strict
-- InventorySystem (PlayArea)
--
-- ADAPTER NOTE: reference implementation standing in for the "semi-working
-- inventory system" already in progress by another programmer. As with
-- PlayerStatsSystem (see its ADAPTER NOTE), the point here is the shape —
-- GameSystem contract, small stable public API (AddItem/RemoveItem/
-- HasItem/GetFamilyInventory) — so the real implementation can drop in
-- without any *other* file changing, as long as it keeps this API. Models
-- the inventory as FAMILY-shared (one pool of item counts), matching the
-- project's existing "collaborative state lives in one place" rule
-- (docs/ARCHITECTURE.md §7) — confirm this matches the real
-- implementation's data model before merging; if it's per-player instead,
-- that's a deliberate, visible swap, not a silent merge side effect.
--
-- Deliberately dumb: InventorySystem only tracks "does the family have N
-- of item X" — it does not know what any item DOES when used. That's
-- ItemSystem's job (world-item interactions) or whichever System/skill
-- checks InventorySystem.HasItem as a precondition (e.g. a SmartDecoder
-- interaction requiring the family already picked up a battery). Keeping
-- this System single-responsibility is what lets it be swapped
-- independently of every item's actual behavior.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("InventorySystem")

local InventorySystem = { Name = "InventorySystem", Dependencies = { "FamilySystem" } }

local FamilySystem: any
local itemCounts: { [string]: number } = {}

local function broadcast()
    Net.FireClients(FamilySystem.GetFamilyPlayers(), RemoteNames.Inventory_Updated, itemCounts)
end

function InventorySystem.GetFamilyInventory(): { [string]: number }
    return itemCounts
end

function InventorySystem.HasItem(itemId: string, quantity: number?): boolean
    return (itemCounts[itemId] or 0) >= (quantity or 1)
end

function InventorySystem.AddItem(itemId: string, quantity: number?)
    local amount = quantity or 1
    itemCounts[itemId] = (itemCounts[itemId] or 0) + amount
    broadcast()
end

-- Returns false (no-op) if the family doesn't have enough of the item —
-- callers must check the return value rather than assuming success.
function InventorySystem.RemoveItem(itemId: string, quantity: number?): boolean
    local amount = quantity or 1
    if not InventorySystem.HasItem(itemId, amount) then
        return false
    end
    itemCounts[itemId] -= amount
    broadcast()
    return true
end

function InventorySystem.Init(registry: { [string]: any })
    FamilySystem = registry.FamilySystem
end

function InventorySystem.Start()
    Net.OnServerEvent(RemoteNames.Inventory_UseItem, function(_player, itemId)
        if typeof(itemId) ~= "string" then
            return
        end
        -- Generic "consume one" for consumable items (e.g. Lolipop). Items
        -- with non-consuming use behavior are handled by ItemSystem
        -- instead — this handler only covers the "use it up" case.
        InventorySystem.RemoveItem(itemId, 1)
    end)

    log:Info(
        "InventorySystem started (reference implementation — see ADAPTER NOTE at top of file)"
    )
end

return InventorySystem
