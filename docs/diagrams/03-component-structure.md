# Diagram — Component Structure (UML)

Referenced from [`ARCHITECTURE.md` §4](../ARCHITECTURE.md#4-component-structure).

The authoritative version of these diagrams is **UML** (pages 11–13 of
[`drawio/jatinangor-architecture.drawio`](drawio/jatinangor-architecture.drawio)):
each System is a `«component»`, grouped into UML packages (folder shapes),
with `«use»` dependency arrows drawn from the declared `.Dependencies` list
in the actual code — nothing here is aspirational, it's read directly off
`Systems/*/init.lua`. Open the `.drawio` file at
<https://app.diagrams.net> (File → Open From → Device) to view/edit pages
11, 12, 13.

The quick-reference flowchart versions below (same information, informal
notation) are kept for a fast read without opening draw.io.

## Hub place

```mermaid
flowchart TB
    subgraph Server["Hub/Server"]
        SAS["SessionAdmissionSystem\n(wraps Shared/Session/SessionAdmission)"]
        MMS["MatchmakingSystem\n(Dependencies: SessionAdmissionSystem)"]
        SAS -.injected via registry.-> MMS
    end
    subgraph Client["Hub/Client"]
        HUI["HubUIController\n(Create/Join/Start buttons)"]
    end
    Client <-- "Hub_CreateFamily / Hub_JoinFamily /\nHub_StartFamily / Hub_FamilyUpdated /\nHub_QueueStatus" --> Server
```

## Lobby place

```mermaid
flowchart TB
    subgraph Server["Lobby/Server"]
        FRS["FamilyRosterSystem"]
        RBS["RoleBalancingSystem\n(Dependencies: FamilyRosterSystem)"]
        RCS["ReadyCheckSystem\n(Dependencies: FamilyRosterSystem,\nRoleBalancingSystem)"]
        FRS --> RBS --> RCS
    end
    subgraph Client["Lobby/Client"]
        LC["LobbyController\n(role buttons, ready button, countdown)"]
    end
    Client <-- "Lobby_RequestRole / Lobby_SetReady /\nLobby_RoleAssignmentsUpdated /\nLobby_ReadyStateUpdated / Lobby_Countdown" --> Server
```

## PlayArea place

```mermaid
flowchart TB
    subgraph Core["Core (boot-ordering backbone)"]
        DS["DataSystem\n(ProfileService)"]
        FS["FamilySystem\n(reads familyId + roleAssignments)"]
        RS["RoleSystem\n(Dependencies: DataSystem, FamilySystem)"]
    end
    subgraph Content["Content Systems (each independently ownable)"]
        SkillS["SkillSystem\n+ Skills/*"]
        StatsS["PlayerStatsSystem\n(ADAPTER)"]
        InvS["InventorySystem\n(ADAPTER)"]
        ItemS["ItemSystem\n+ Items/*"]
        DoorS["DoorLockSystem\n(mechanisms)"]
        DialogS["DialogSystem\n+ Dialogs/*"]
        AIS["EntityAISystem\n+ Entities/*"]
        MiniS["MinigameSystem\n+ Minigames/*"]
        JournalS["JournalSystem"]
    end
    GameS["GameSystem\n(win condition + session-slot release)"]

    DS --> RS
    FS --> RS
    RS --> SkillS
    FS --> SkillS
    FS --> StatsS
    FS --> InvS
    RS --> ItemS
    FS --> ItemS
    RS --> DoorS
    FS --> DoorS
    FS --> JournalS
    DoorS --> GameS
    FS --> GameS
    DS --> GameS
```

Client mirrors this 1:1 via `PlayArea/Client/Controllers/`:
`RoleController`, `SkillController`, `PlayerStatsController`,
`InventoryController`, `InteractionController` (mechanisms + items, one
Controller since both are "ProximityPrompt → request → server-pushed
update"), `MinigameController`, `DialogController`, `JournalController`,
`UIController` (wires everything to actual UI + applies
`Platform.GetRecommendedUIScale()`).
