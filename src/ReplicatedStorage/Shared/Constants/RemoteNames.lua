--!strict
-- Single source of truth for every RemoteEvent/RemoteFunction name.
-- Never hardcode a remote name string anywhere else in the codebase.

return {
    -- Role
    Role_Assigned = "Role_Assigned",

    -- Dimension
    Dimension_RequestSwitch = "Dimension_RequestSwitch",
    Dimension_Switched = "Dimension_Switched",
    Dimension_PlayerMoved = "Dimension_PlayerMoved",

    -- Puzzle
    Puzzle_Interact = "Puzzle_Interact",
    Puzzle_MechanismUpdated = "Puzzle_MechanismUpdated",

    -- Journal
    Journal_Collect = "Journal_Collect",
    Journal_FragmentUpdated = "Journal_FragmentUpdated",

    -- Game
    Game_StateChanged = "Game_StateChanged",
}
