--!strict
-- MechanismDefinitions
--
-- This is a fallback/example config, not currently read by DoorLockSystem
-- automatically. In practice, mechanisms are tagged in Studio via
-- CollectionService (tag: "Mechanism") with Attributes: MechanismId
-- (string), RequiredRole (string, optional), PuzzleGroupId (string) —
-- DoorLockSystem reads those Attributes directly at runtime. This file
-- exists for puzzle-group metadata that doesn't fit cleanly as an
-- Attribute (e.g. sequential-activation ordering), or for early testing
-- before level design content lands.

export type PuzzleGroupDefinition = {
    puzzleGroupId: string,
    mechanismIds: { string },
    requiresSequential: boolean, -- must mechanisms activate in listed order?
}

local MechanismDefinitions: { PuzzleGroupDefinition } = {
    {
        puzzleGroupId = "Generator_A",
        mechanismIds = { "Lever_A1", "PinPanel_A1" },
        requiresSequential = false,
    },
    {
        puzzleGroupId = "Generator_B",
        mechanismIds = { "PressurePlate_B1", "Lever_B1", "Lever_B2" },
        requiresSequential = true,
    },
}

return MechanismDefinitions
