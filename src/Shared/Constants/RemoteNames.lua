--!strict
-- Single source of truth for every RemoteEvent name, across all three
-- places (Hub, Lobby, PlayArea). Never hardcode a remote name string
-- anywhere else in the codebase.
--
-- A given place's Net.InitRemotes() creates every name in this list even
-- though it only ever fires a subset — that's a deliberate simplification
-- (one shared file instead of three near-duplicates) since the cost is a
-- handful of unused RemoteEvent instances per server, not a coupling
-- problem: no System reaches into another place's remotes directly, they
-- only ever go through Net.

return {
    -- Hub: matchmaking / session admission
    Hub_CreateFamily = "Hub_CreateFamily",
    Hub_JoinFamily = "Hub_JoinFamily",
    Hub_StartFamily = "Hub_StartFamily", -- leader-only: request admission + teleport to Lobby
    Hub_FamilyUpdated = "Hub_FamilyUpdated", -- server -> client: pending roster while still in the Hub
    Hub_QueueStatus = "Hub_QueueStatus", -- server -> client: position/state while waiting on admission

    -- Lobby: roster + role balancing + ready check
    Lobby_RosterUpdated = "Lobby_RosterUpdated",
    Lobby_RequestRole = "Lobby_RequestRole", -- client -> server: player's preferred role (advisory, server balances)
    Lobby_RoleAssignmentsUpdated = "Lobby_RoleAssignmentsUpdated",
    Lobby_SetReady = "Lobby_SetReady",
    Lobby_ReadyStateUpdated = "Lobby_ReadyStateUpdated",
    Lobby_Countdown = "Lobby_Countdown",

    -- PlayArea: Role
    Role_Assigned = "Role_Assigned",

    -- PlayArea: Skill
    Skill_Activate = "Skill_Activate",
    Skill_Activated = "Skill_Activated",
    Skill_CooldownUpdated = "Skill_CooldownUpdated",

    -- PlayArea: PlayerStats
    Stats_Updated = "Stats_Updated",
    Stats_Damaged = "Stats_Damaged",

    -- PlayArea: Inventory
    Inventory_Updated = "Inventory_Updated",
    Inventory_UseItem = "Inventory_UseItem",
    Inventory_DropItem = "Inventory_DropItem",

    -- PlayArea: Item interactions (search/pickup/use world items)
    Item_Interact = "Item_Interact",
    Item_WorldStateUpdated = "Item_WorldStateUpdated",

    -- PlayArea: Door / lock mechanisms
    Mechanism_Interact = "Mechanism_Interact",
    Mechanism_Updated = "Mechanism_Updated",

    -- PlayArea: Dialog
    Dialog_Start = "Dialog_Start",
    Dialog_Advance = "Dialog_Advance",
    Dialog_NodeUpdated = "Dialog_NodeUpdated",
    Dialog_End = "Dialog_End",

    -- PlayArea: Minigame
    Minigame_Start = "Minigame_Start",
    Minigame_SubmitAttempt = "Minigame_SubmitAttempt",
    Minigame_StateUpdated = "Minigame_StateUpdated",
    Minigame_End = "Minigame_End",

    -- PlayArea: Journal
    Journal_Collect = "Journal_Collect",
    Journal_FragmentUpdated = "Journal_FragmentUpdated",

    -- PlayArea: Game / session lifecycle
    Game_StateChanged = "Game_StateChanged",
}
