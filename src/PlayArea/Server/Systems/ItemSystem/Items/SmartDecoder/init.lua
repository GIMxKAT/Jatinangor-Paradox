--!strict
-- SmartDecoder — reference item implementation.
--
-- Requires a battery from the family's shared inventory to activate (via
-- InventorySystem, reached through context.registry — the same DI path
-- every cross-system call in this codebase uses). Demonstrates an item
-- that gates its own behavior on inventory state rather than InventorySystem
-- needing to know anything about decoders.

local SmartDecoder = {
    Id = "SmartDecoder",
    DisplayName = "Smart Decoder",
}

function SmartDecoder.OnInteract(
    _player: Player,
    instance: Instance,
    context: { [string]: any }
): boolean
    local registry = context.registry :: { [string]: any }?
    local InventorySystem = registry and registry.InventorySystem
    if not InventorySystem then
        return false
    end

    if not InventorySystem.RemoveItem("Battery", 1) then
        return false -- family doesn't have a battery yet — no-op, not an error
    end

    instance:SetAttribute("Activated", true)
    return true
end

return SmartDecoder
