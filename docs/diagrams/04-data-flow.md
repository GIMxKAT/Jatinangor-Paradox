# Diagram — Data Flow Walkthroughs

Referenced from [`ARCHITECTURE.md` §6](../ARCHITECTURE.md#6-data-flow-walkthroughs).

## Hub: create/join a family, get admitted, teleport to Lobby

```mermaid
sequenceDiagram
    participant P as Player(s)
    participant Hub as Hub server (MatchmakingSystem)
    participant Adm as SessionAdmission (MemoryStore, universe-wide)
    participant TS as TeleportService

    P->>Hub: Hub_CreateFamily
    Hub-->>P: Hub_FamilyUpdated (invite code)
    P->>Hub: Hub_JoinFamily(code)  [other members]
    Hub-->>P: Hub_FamilyUpdated (roster)
    P->>Hub: Hub_StartFamily  [leader only]
    loop until admitted
        Hub->>Adm: TryAdmit(familyId)
        alt cap full
            Adm-->>Hub: false
            Hub-->>P: Hub_QueueStatus WaitingForSlot
            Note over Hub: task.wait(5s), retry
        else slot available
            Adm-->>Hub: true (atomic increment)
        end
    end
    Hub->>TS: ReserveServer(LobbyPlaceId)
    TS-->>Hub: accessCode
    Hub->>TS: TeleportToPrivateServer(Lobby, accessCode, members, TeleportData)
    Note over Hub: on ReserveServer/Teleport failure: Adm.Release(familyId) — compensating action
```

## Lobby: role balancing → ready check → teleport to PlayArea

```mermaid
sequenceDiagram
    participant P as Family members
    participant L as Lobby server
    participant TS as TeleportService

    Note over L: FamilyRosterSystem reads familyId from TeleportData on PlayerAdded
    P->>L: Lobby_RequestRole(role)  [advisory]
    L->>L: RoleBalancingSystem.AutoBalance()  [greedy, ceiling = ceil(members/5)]
    L-->>P: Lobby_RoleAssignmentsUpdated
    P->>L: Lobby_SetReady(true)
    L-->>P: Lobby_ReadyStateUpdated
    alt everyone ready and has assignedRole
        L-->>P: Lobby_Countdown 5..1
        L->>TS: ReserveServer(PlayAreaPlaceId)  [FRESH reservation]
        TS-->>L: accessCode
        L->>TS: TeleportToPrivateServer(PlayArea, accessCode, members, TeleportData)
    end
```

## PlayArea: role seeding, a skill activation, and win

```mermaid
sequenceDiagram
    participant P as Player
    participant FS as FamilySystem
    participant DS as DataSystem
    participant RS as RoleSystem
    participant SS as SkillSystem
    participant Adm as SessionAdmission

    Note over FS: Init() reads familyId + roleAssignments from TeleportData
    DS->>DS: LoadProfile(player)
    DS-->>RS: ProfileLoaded fires
    RS->>FS: GetRoleFromLobby(player)
    Note over RS: priority: Lobby assignment > persisted profile role > round-robin fallback
    RS-->>P: Role_Assigned

    P->>SS: Skill_Activate(skillId)
    SS->>RS: CanAccess(player, requiredRole)?
    SS->>SS: cooldown check
    SS->>SS: skill.Execute(player, context)
    SS-->>P: Skill_Activated (family), Skill_CooldownUpdated (self)

    Note over P: family completes all puzzle groups
    Note over SS: DoorLockSystem.AllGeneratorsActivated fires
    Note over SS: GameSystem.HandleWin()
    SS->>Adm: Release(familyId)
    SS-->>P: Game_StateChanged Won
```

## Item / mechanism / minigame / dialog interaction (shared shape)

All four follow the same server-authoritative shape: client requests via
`Net.FireServer`, server re-validates (role, distance, ownership/state),
mutates state, and pushes the update back — the client never renders a
state change it computed itself.

```mermaid
flowchart LR
    A["ProximityPrompt.Triggered (client)"] --> B["Net.FireServer(...)"]
    B --> C{"Server re-validates:\nrole? distance? state?"}
    C -->|reject| D["no-op\n(client sees nothing — this is\nthe anti-exploit posture)"]
    C -->|accept| E["mutate server state"]
    E --> F["Net.FireClients(family, ...Updated, ...)"]
```
