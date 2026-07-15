--!strict
-- PuzzleDefinitions
--
-- This is a fallback/example config. In practice, mechanisms are tagged in
-- Studio via CollectionService (tag: "Mechanism") with Attributes:
--   MechanismId (string), RequiredRole (string), PuzzleGroupId (string)
-- PuzzleService reads those Attributes directly at runtime. This file
-- exists for mechanisms that need config beyond what fits cleanly as
-- Attributes, or for early testing before level design content lands.

export type PuzzleGroupDefinition = {
    puzzleGroupId: string,
    mechanismIds: { string },
    requiresSequential: boolean, -- must mechanisms activate in listed order?
}

local PuzzleDefinitions: { PuzzleGroupDefinition } = {
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

return PuzzleDefinitions
