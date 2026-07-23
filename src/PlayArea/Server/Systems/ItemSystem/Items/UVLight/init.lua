--!strict
-- UVLight — reference item implementation.
--
-- Reveals hidden ink: any instance tagged "UVReveal" within the UV light's
-- Model becomes Visible when interacted with. Copy this file's shape
-- (Id + OnInteract) for any new item type; ItemSystem never needs to
-- change to pick it up.

local CollectionService = game:GetService("CollectionService")

local UVLight = {
    Id = "UVLight",
    DisplayName = "UV Light",
}

function UVLight.OnInteract(
    _player: Player,
    instance: Instance,
    _context: { [string]: any }
): boolean
    local revealedAny = false
    for _, descendant in instance:GetDescendants() do
        if CollectionService:HasTag(descendant, "UVReveal") and descendant:IsA("BasePart") then
            descendant.Transparency = 0
            descendant.CanCollide = false
            revealedAny = true
        end
    end
    return revealedAny
end

return UVLight
