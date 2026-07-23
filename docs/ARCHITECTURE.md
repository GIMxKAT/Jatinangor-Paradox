# Jatinangor Paradox — Technical Architecture (v2)

Version 2.0 · Tech Lead reference doc · Target release: 14–17 Aug 2026
Supersedes v1 (single-place, 3-role, ~20-25 player-per-server design).

This document defines the production architecture for a multi-place,
5-role, cross-platform version of the game, sized for a 3-day live event
serving roughly 200-250 family sessions total. **Read this before writing
any System/Controller code.** See the [README](../README.md) for the
day-to-day setup and workflow.

Every diagram in this document has been extracted to
[`docs/diagrams/`](diagrams/) as standalone files, and to a presentation
page for walking the team through it on a screen-share:
<https://claude.ai/code/artifact/096aa660-8bfd-4840-a88a-dd245177f336>

---

## 0. What changed from v1, and why

| v1 | v2 | Why |
|---|---|---|
| One Rojo place, `default.project.json` | Three places (Hub / Lobby / PlayArea), `places/*.project.json` | The prerequisite diagram requires a public matchmaking space (Hub) distinct from the private per-family session (Lobby → PlayArea); one DataModel can't cleanly be both, and splitting keeps each place's content-size budget and ownership boundary independent. |
| 3 roles (Merah/Kuning/Hijau) | 5 roles (Navigator, Detective, Scout, Code-Breaker, Support) + a scalable skill system | Per the updated design brief. |
| Dimension system (Normal/Alter) | Removed entirely | Descoped — not part of the current design. |
| Hand-written `ServiceRegistry` table in `init.server.lua` | `PluginRegistry.DiscoverAndBoot` (auto-discovery over a `Systems/` folder) | Multiple programmers now each own an independent system (Items, Minigames, PlayerStats, Inventory, ...). A shared bootstrap file everyone edits to register their own system is a merge-conflict bottleneck and a hidden coupling point — see §3. |
| Single-server-per-family, admitted implicitly | Explicit, race-safe admission control (`Shared/Session/SessionAdmission.lua`) | The event runs ~200-250 family sessions over 3 days with a hard concurrency ceiling; Hub servers are independent processes with no shared memory, so admission has to be solved as a real distributed-systems problem, not assumed away. See §8. |
| No cross-platform handling | `Shared/Platform/Platform.lua` + UIScale wiring in every place's UI Controller | Explicit production requirement. |

---

## 1. Guiding principles

1. **Server-authoritative, always.** The client never decides who has a
   role, what a mechanism's state is, or whether a skill/item/minigame
   attempt succeeded. It only *requests* and *renders*. Non-negotiable.
2. **Data-driven content, not hardcoded scripts per puzzle/item/minigame.**
   Content is configured via Attributes/tables or a small "content plugin"
   module, not a one-off script wired into a shared file.
3. **Composable, loosely-coupled Systems — not a monolith, and not a
   shared bootstrap file either.** Every System is independent and
   discovered automatically; adding one is "add a folder," never "edit a
   file everyone else also edits." See §3.
4. **Boring and battle-tested over clever.** ProfileService for
   persistence, MemoryStoreService for cross-server counters — proven
   platform primitives, not hand-rolled equivalents.
5. **Cross-platform by construction.** ProximityPrompt-driven interaction
   wherever possible (Roblox already adapts these to touch/gamepad/
   keyboard); `Platform.lua` covers what Roblox doesn't (UI scale, hint
   icons) for the cases that need custom UI (minigames, dialog).

---

## 2. Place topology

**Diagram: [`docs/diagrams/01-place-topology.md`](diagrams/01-place-topology.md)**
— Hub (public) → Lobby (reserved) → PlayArea (reserved), and the
`familyId`/reservation handoff at each hop.

**Why three places, not one with logical zones:** a `TeleportService`
reserved-server access code is scoped to the specific `placeId` it was
reserved against — you cannot reuse a Lobby reservation to enter PlayArea.
`familyId` (an app-level identifier we mint, not a Roblox one) is what
actually threads a family's identity across all three legs; each
place-to-place hop mints its own fresh reservation. This is a real Roblox
platform constraint, not a design preference — see §6.1-6.3 for the exact
`TeleportData` shape carried at each hop.

**One-time setup (Studio / Creator Dashboard, not something this repo can
do for you):** create a multi-place Universe, add Hub/Lobby/PlayArea as
three Places under it, and fill in the `LOBBY_PLACE_ID` /
`PLAYAREA_PLACE_ID` constants in `Hub/Server/Systems/MatchmakingSystem` and
`Lobby/Server/Systems/ReadyCheckSystem` (both currently `0` as a
loud-failure placeholder — see the `TODO(ops)` comments in those files).

---

## 3. Loose coupling: PluginRegistry and ContentRegistry

Every programmer owns an independent slice of the game (Items, Minigames,
PlayerStats, Inventory, a specific Skill, ...). The v1 pattern — a
hand-written table in `init.server.lua` that lists every Service — meant
everyone edited the same file to register their own work, which is exactly
the kind of shared file that turns into a merge-conflict bottleneck and a
place where it's easy to accidentally read a teammate's system while "just
registering" your own.

v2 replaces it with two generic, reusable primitives in `Shared/Registry/`.

**Diagram: [`docs/diagrams/02-loose-coupling.md`](diagrams/02-loose-coupling.md)**
— the boot-flow flowchart (discover → validate → topo-sort → two-phase pcall'd boot).

**`PluginRegistry.DiscoverAndBoot(container, label)`** — for long-lived
*Systems* (Role, Inventory, Item, Minigame, ...). Scans `container`'s
direct children, requires each `ModuleScript` (or `Folder/init.lua`),
validates it returns a table with a string `.Name`, orders every
discovered system by its declared `.Dependencies` (Kahn's-algorithm
topological sort — missing deps and cycles are **warned, never fatal**),
then boots everything in the same two-phase Init/Start pattern as v1
(§3.3 below), with each system's Init/Start individually `pcall`'d so one
system's bug can't take the whole server down mid-event.

**`ContentRegistry.Load(container, label)`** — for *content plugins*
(one specific item, skill, minigame, AI entity, dialog tree). These have
no lifecycle of their own — just a unique `.Id`, looked up on demand by
whichever System owns that category. Every leaf content type in the
prerequisite diagram (UV light, smart decoder, PIN code, Ular Jatinangor,
...) is one file under the relevant System's own subfolder — see §5.

**The result:** adding a new item is one new file under
`ItemSystem/Items/<Name>/init.lua` returning `{ Id = "...", OnInteract = ... }`.
Nobody edits `ItemSystem/init.lua`, `PlayArea/Server/init.server.lua`, or
any other programmer's files. This is what "each programmer owns their own
code" means concretely in this codebase.

### 3.1 The GameSystem contract

```lua
export type GameSystem = {
    Name: string,
    Dependencies: { string }?,
    Init: ((registry: { [string]: any }) -> ())?,
    Start: (() -> ())?,
    [string]: any, -- systems expose their own public API/Signals beyond this
}
```

### 3.2 The content-plugin contract

```lua
export type ContentDefinition = { Id: string, [string]: any }
```

Everything else in a content module's table is owned by whoever wrote it
and by the System that consumes it — `ContentRegistry` only ever checks
for a unique `.Id`. The specific shapes each category follows
(`SkillDefinition`, `ItemDefinition`, `MinigameDefinition`,
`EntityDefinition`, `DialogTreeDefinition`) live in `Shared/Types/Types.lua`
as documented conventions, not hard runtime checks.

### 3.3 Two-phase boot (unchanged rationale from v1)

Phase 1 (`Init`) — every system receives the registry and stores
references; no cross-system calls yet. Phase 2 (`Start`) — every system
connects events and starts logic. This guarantees every system exists
before any of them call into each other, and it's identical across all
three places, so switching between Hub/Lobby/PlayArea code requires no
relearning.

### 3.4 Adapting already-in-progress work

Two systems in this codebase — `PlayerStatsSystem` and `InventorySystem` —
are reference implementations standing in for work already started
independently by other programmers (a health/stats system, a semi-working
inventory). They're written to the exact same `GameSystem` contract as
everything else, with a small, stable public API (`Damage`/`Restore`,
`AddItem`/`RemoveItem`/`HasItem`). When the real implementations are ready,
swap the file body and keep the function names/signatures — nothing else
in the codebase needs to change, because every cross-system call goes
through the injected `registry`, never a direct `require` of another
system's file. Each file has an `ADAPTER NOTE` at the top spelling this out,
including one open design question worth confirming with the actual
owner (family-shared vs. per-player state — see the note in each file).

---

## 4. Component structure

**Diagrams: [`docs/diagrams/03-component-structure.md`](diagrams/03-component-structure.md)**
— one flowchart per place (Hub, Lobby, PlayArea), Systems/Controllers and
their dependency wiring.

### 4.1 Hub place

`SessionAdmissionSystem` (wraps `Shared/Session/SessionAdmission`) is
injected into `MatchmakingSystem` via the registry. Client:
`HubUIController` (Create/Join/Start buttons).

### 4.2 Lobby place

`FamilyRosterSystem` → `RoleBalancingSystem` → `ReadyCheckSystem`, in that
dependency order. Client: `LobbyController` (role buttons, ready button,
countdown).

### 4.3 PlayArea place

`DataSystem` + `FamilySystem` feed `RoleSystem`, which every content
System (`SkillSystem`, `ItemSystem`, `DoorLockSystem`, ...) depends on for
authorization. `GameSystem` sits downstream of `DoorLockSystem` for the
win condition. Client mirrors this 1:1 via `PlayArea/Client/Controllers/`:
`RoleController`, `SkillController`, `PlayerStatsController`,
`InventoryController`, `InteractionController` (mechanisms + items, one
Controller since both are "ProximityPrompt → request → server-pushed
update"), `MinigameController`, `DialogController`, `JournalController`,
`UIController` (wires everything to actual UI + applies
`Platform.GetRecommendedUIScale()`).

---

### 4.4 Traceability to the prerequisite diagram (FigJam)

Every node from the original prerequisite diagram maps to a concrete file
or folder below — nothing in that diagram was dropped silently. Anything
in v2 that does **not** trace back to it is called out explicitly at the
bottom, with the reason it exists.

| FigJam node | Lives in v2 as | Status |
|---|---|---|
| Hub System | `Hub/Server/Systems/MatchmakingSystem` | Implemented |
| Server distribution | `Hub/Server/Systems/SessionAdmissionSystem` (§8) | Implemented |
| TITLE / Create Server / Join Server | `Hub/Client/Controllers/HubUIController` | Implemented |
| Spawn ke Lobby (invite-code gated) | `MatchmakingSystem` invite-code grouping + `TeleportToPrivateServer` | Implemented |
| lobby system | Lobby place (all 3 Lobby Systems) | Implemented |
| Player stats → Player role → Auto balancing | `Lobby/Server/Systems/RoleBalancingSystem` | Implemented — see naming note below |
| Amphiteater | PlayArea spawn/staging area | Level content (Studio-authored, not a System — same as v1's approach to level geometry) |
| Asset gedung dan ruangan | Building/room geometry | Level content, not code |
| Door and locks mechanics | `PlayArea/Server/Systems/DoorLockSystem` | Implemented |
| Outside game — Hall Of Mirror, Parkour biasa | PlayArea level content | Not yet a dedicated System — no distinct mechanic beyond level geometry was specified; add as a `Systems/OutsideGameSystem` when that design lands |
| Anter Game | PlayArea level content | Same as above |
| Inventory System | `PlayArea/Server/Systems/InventorySystem` | Implemented (adapter — see §3.4) |
| search item | `PlayArea/Server/Systems/ItemSystem` (`Item_Interact`) | Implemented |
| item system — Altar System, Journal System, Lolipop, Tablet ajaib, UV light, Objective Item, Nipis Lebah, smart decoder | `ItemSystem/Items/*` | UV Light and Smart Decoder implemented as reference items; Altar/Lolipop/Tablet Ajaib/Objective Item/Nipis Lebah are one-file-each additions following the same pattern (§5) |
| Journal System | `PlayArea/Server/Systems/JournalSystem` | Implemented — kept as its own System rather than folded into `ItemSystem`, since it's collaborative fragment-tracking state, not a placeable/interactable item |
| Dialog System | `PlayArea/Server/Systems/DialogSystem` + `Dialogs/*` | Implemented, 1 reference tree (`CaretakerGreeting`) |
| Entity AI System — NPC, Ular Jatinangor, Laba-laba Jatinangor | `PlayArea/Server/Systems/EntityAISystem` + `Entities/*` | `UlarJatinangor` implemented as reference; NPC and Laba-laba Jatinangor are one-file-each additions |
| Minigame — Trivia, Deliver Item, PIN CODE, Pattern Minigame, cryptarithmetic, Sliding Puzzle, Tower of Hanoi | `PlayArea/Server/Systems/MinigameSystem` + `Minigames/*` | `PinCode` implemented as reference; the other six are one-file-each additions |

**Not from the FigJam — added per explicit requirements stated directly in
scoping conversation, not scope creep:**

| Addition | Why it's here |
|---|---|
| 5-role skill system (Navigator/Detective/Scout/Code-Breaker/Support + `SkillSystem`) | Explicit requirement — replaces v1's 3-role Merah/Kuning/Hijau design |
| `Shared/Session/SessionAdmission.lua` + concurrency admission control (§8) | Explicit capacity requirement (~200-250 sessions over 3 days, race-safe) — the FigJam has no capacity/ops layer at all, it's a content-flow diagram |
| `Shared/Platform/Platform.lua` (cross-platform input/UI) | Explicit cross-platform requirement |

**Naming collision worth resolving, not yet renamed:** the FigJam's
"Player stats" feeds role balancing *before* the game starts (a Lobby-side
input — preference/profile data). `PlayArea/Server/Systems/PlayerStatsSystem`
is a different thing: a runtime health system *during* the game (an
adapter standing in for a teammate's in-progress health/stats work, per
§3.4). Same words, two unrelated concepts. Left as-is pending a decision —
rename `PlayerStatsSystem` to something like `HealthSystem` if the
collision is confusing in practice, since a rename touches the remote
names (`Stats_Updated`/`Stats_Damaged`), the client Controller, and the
`Support_TeamAssist` skill that calls into it.

---

## 5. Adding content — the concrete "drop a folder" recipe

| To add... | Do this | Touches |
|---|---|---|
| A new **System** (Hub/Lobby/PlayArea) | New folder under that place's `Server/Systems/` (or `Client/Controllers/`) returning a `GameSystem` table | 1 new file/folder |
| A new **item type** (e.g. "Tablet Ajaib") | New folder under `ItemSystem/Items/<Name>/init.lua` returning `{ Id, DisplayName, OnInteract }` | 1 new file |
| A new **item instance** in the world | Tag it `WorldItem` in Studio + Attributes `WorldItemId`, `ItemType`, optional `RequiredRole` | 0 code files |
| A new **skill** | New folder under `SkillSystem/Skills/<Name>/init.lua` returning a `SkillDefinition`; add its Id to the owning role's `SkillIds` in `Shared/Content/RoleDefinitions.lua` | 1 new file + 1 line |
| A new **minigame** | New folder under `MinigameSystem/Minigames/<Name>/init.lua` returning `{ Id, Start, SubmitAttempt, GetPublicState }` | 1 new file |
| A new **AI entity type** | New folder under `EntityAISystem/Entities/<Name>/init.lua` returning `{ Id, OnSpawn }` | 1 new file |
| A new **dialog tree** | New folder under `DialogSystem/Dialogs/<Name>/init.lua` returning a `DialogTreeDefinition` | 1 new file |
| A new **mechanism/door/lock instance** | Tag it `Mechanism` in Studio + Attributes `MechanismId`, `PuzzleGroupId`, optional `RequiredRole` (unchanged from v1) | 0 code files |

Every one of these is additive — no existing file needs an edit, which is
what makes independent ownership actually work in practice rather than
just in principle.

---

## 6. Data flow walkthroughs

**Diagrams: [`docs/diagrams/04-data-flow.md`](diagrams/04-data-flow.md)**
— four sequence/flow diagrams covering every hop below.

### 6.1 Hub: create/join a family, get admitted, teleport to Lobby

Create/Join gathers the family in the Hub server; the leader's Start
request loops on `SessionAdmission.TryAdmit(familyId)` until a concurrency
slot opens (`Hub_QueueStatus` keeps the UI informed while waiting), then
reserves and teleports the whole family to Lobby. A failed
`ReserveServer`/`Teleport` releases the slot immediately as a compensating
action.

### 6.2 Lobby: role balancing → ready check → teleport to PlayArea

`FamilyRosterSystem` reads `familyId` from `TeleportData` on join;
`RoleBalancingSystem.AutoBalance()` re-runs on every preference change;
once everyone is ready and has an assigned role, a countdown fires a
**fresh** `ReserveServer(PlayAreaPlaceId)` call (not a reuse of the Hub→Lobby
code — see §2) carrying `familyId` and the computed `roleAssignments`.

### 6.3 PlayArea: role seeding, a skill activation, and win

`RoleSystem` assigns from the Lobby's `roleAssignments` first, falling
back to a persisted profile role, then round-robin. Every skill activation
re-checks role ownership and cooldown server-side. On win,
`GameSystem.HandleWin` releases the family's admission slot.

### 6.4 Item / mechanism / minigame / dialog interaction (shared shape)

All four follow the same server-authoritative shape: client requests via
`Net.FireServer`, server re-validates (role, distance, ownership/state),
mutates state, and pushes the update back — the client never renders a
state change it computed itself.

---

## 7. API design (Remote catalogue)

All Remotes are declared once in `Shared/Constants/RemoteNames.lua` and
only ever touched through `Shared/Net/Net.lua` (unchanged mechanism from
v1: known-remote assertion, per-player-per-remote rate limiting, one place
to add logging). Naming convention: `Domain_Action`.

| Remote | Direction | Payload | Owning System |
|---|---|---|---|
| `Hub_CreateFamily` | C→S | — | MatchmakingSystem |
| `Hub_JoinFamily` | C→S | `code: string` | MatchmakingSystem |
| `Hub_StartFamily` | C→S | — (leader only) | MatchmakingSystem |
| `Hub_FamilyUpdated` | S→C | `{accessCode, leaderUserId, memberNames}` | MatchmakingSystem |
| `Hub_QueueStatus` | S→C | `{state: "WaitingForSlot"\|"InvalidCode"\|"TeleportFailed"}` | MatchmakingSystem |
| `Lobby_RequestRole` | C→S | `role: string` (advisory) | RoleBalancingSystem |
| `Lobby_RoleAssignmentsUpdated` | S→C | `{[userId]: role}` | RoleBalancingSystem |
| `Lobby_SetReady` | C→S | `ready: boolean` | ReadyCheckSystem |
| `Lobby_ReadyStateUpdated` | S→C | `{[userId]: boolean}` | ReadyCheckSystem |
| `Lobby_Countdown` | S→C | `secondsLeft: number?` | ReadyCheckSystem |
| `Role_Assigned` | S→C | `role: string` | RoleSystem |
| `Skill_Activate` | C→S | `skillId: string` | SkillSystem |
| `Skill_Activated` | S→C (family) | `userId, skillId` | SkillSystem |
| `Skill_CooldownUpdated` | S→C (self) | `skillId, cooldownSeconds` | SkillSystem |
| `Stats_Updated` | S→C (family) | `userId, health` | PlayerStatsSystem |
| `Inventory_Updated` | S→C (family) | `{[itemId]: count}` | InventorySystem |
| `Inventory_UseItem` | C→S | `itemId: string` | InventorySystem |
| `Item_Interact` | C→S | `worldItemId: string` | ItemSystem |
| `Item_WorldStateUpdated` | S→C (family) | `worldItemId: string` | ItemSystem |
| `Mechanism_Interact` | C→S | `mechanismId: string` | DoorLockSystem |
| `Mechanism_Updated` | S→C (family) | `mechanismId, activated` | DoorLockSystem |
| `Dialog_Start` | C→S | `treeId: string` | DialogSystem |
| `Dialog_Advance` | C→S | `optionIndex: number` | DialogSystem |
| `Dialog_NodeUpdated` | S→C (self) | `DialogNode` | DialogSystem |
| `Dialog_End` | S→C (self) | — | DialogSystem |
| `Minigame_Start` | C→S | `minigameId: string` | MinigameSystem |
| `Minigame_SubmitAttempt` | C→S | `attempt: any` | MinigameSystem |
| `Minigame_StateUpdated` | S→C (self) | `minigameId, publicState` (never secrets) | MinigameSystem |
| `Minigame_End` | S→C | `minigameId, solvedByUserId` | MinigameSystem |
| `Journal_Collect` | C→S | `fragmentId: string` | JournalSystem |
| `Journal_FragmentUpdated` | S→C (family) | `fragmentId, collected` | JournalSystem |
| `Game_StateChanged` | S→C (family) | `status: "Lobby"\|"InProgress"\|"Won"` | GameSystem |

### 7.1 Server-internal API (registry-injected, not Remotes)

Every System's public functions (e.g. `RoleSystem.CanAccess`,
`InventorySystem.HasItem`, `PlayerStatsSystem.Restore`) are the *real* API
surface between Systems — reached via the `registry` table
`PluginRegistry` injects into `Init`, never via cross-file `require`. This
is what makes a System's internal implementation swappable (§3.4) without
a ripple effect through the codebase.

---

## 8. Session admission: capacity math and the race condition

### 8.1 Capacity target, not a live concurrency figure

The event is expected to seat **~200-250 distinct family sessions in
total across 3 days**, arriving as a rolling trickle (families are not all
available all day) rather than one simultaneous peak. This is a
capacity-planning target, not something enforced in code — Roblox
allocates reserved servers elastically per `ReserveServer` call; there is
no platform mechanism to pre-provision or hold idle spare server capacity.

### 8.2 The concurrency ceiling

What *is* enforced is a live concurrency ceiling: at most
`SessionConstants.MAX_CONCURRENT_SESSIONS` (default 50) families "in
flight" (Lobby + PlayArea combined) at once, +10% buffer
(`RESERVE_BUFFER_PERCENT`) before a family is asked to keep waiting. This
protects support-staff capacity and DataStore/analytics throughput from a
burst of simultaneous admissions, independent of how the ~200-250 total
sessions are distributed across the 3 days.

### 8.3 The race condition, and why the fix is correct

Hub servers are independent Lua VMs with no shared memory. A naive
"read the current count, compare to the cap, write count+1" — whether in
local Lua state or via a plain `DataStore:GetAsync`/`SetAsync` pair — is a
classic check-then-act race: two Hub servers can both read `count = 49`
and both admit a family, blowing past the cap.

`Shared/Session/SessionAdmission.lua` solves this with
`MemoryStoreSortedMap:UpdateAsync(key, transform, expiration)`, whose
transform function is atomic on Roblox's side (always runs against the
latest committed value, retried on write conflict) — a real
compare-and-swap primitive. `DataStoreService` has the same atomicity
guarantee but far lower throughput and no TTL; `MessagingService` is
pub/sub only with no atomicity guarantee for a shared counter at all.
MemoryStore is the correct tool.

**Critically, the cap check and the increment happen on ONE shared counter
key**, inside a single `UpdateAsync` call — not by scanning per-family
entries. An earlier draft of this design computed the current total by
scanning all live per-family claim entries inside each family's own
per-key transform; that is **not** race-free, because MemoryStore's
atomicity guarantee is per-key, and two concurrent admits for two
*different* families (keys A and B) can each read a stale total via a
separate snapshot read before either commits. Collapsing the check and the
write onto a single key removes that window entirely.

**Diagram: [`docs/diagrams/05-session-admission.md`](diagrams/05-session-admission.md)**
— the concurrent-admit sequence diagram showing why the single-key
atomic transform closes the race.

### 8.4 Release and the known gap

A per-family claim record (separate key, no contention with the counter or
with other families) exists purely for idempotency and ops visibility, with
a TTL as a safety net — **the counter's correctness never depends on that
TTL**, since MemoryStore TTL expiry is silent (no callback) and can't
decrement a separate counter for you. Instead, the slot is explicitly
released: by the Hub on a failed `ReserveServer`/`Teleport` (compensating
action), by `GameSystem.HandleWin` on a genuine win, and best-effort in
`game:BindToClose` for every other shutdown path.

**Documented gap (v1.1 hardening item, intentionally out of scope for this
baseline):** if a PlayArea server hard-crashes before `BindToClose`
completes, that family's counter slot leaks until a periodic
reconciliation job corrects the drift. That job is not implemented here —
flagging it explicitly is safer than pretending a fully self-healing
distributed counter fits a three-week build window.

---

## 9. The 5-role skill system

Roles: **Navigator, Detective, Scout, Code-Breaker, Support** — display
metadata and role→skill mapping live as data in
`Shared/Content/RoleDefinitions.lua`, not code, so retuning which skills a
role has is a one-line data edit.

- **Assignment** happens in the Lobby (`RoleBalancingSystem`): greedy,
  preference-aware, balanced to `ceil(memberCount / 5)` per role — see the
  algorithm doc-comment in that file for the exact rule.
- **Authorization** is re-checked in PlayArea on every skill activation
  (`RoleSystem.CanAccess` + an explicit `roleOwnsSkill` check in
  `SkillSystem`) — the Lobby's assignment and any client-sent role claim
  are never trusted directly for a gameplay decision.
- **Scalability**: a skill is a content plugin (`SkillDefinition`: Id,
  DisplayName, Description, CooldownSeconds, Execute) discovered via
  `ContentRegistry` — adding one is one new file, and a validation pass at
  boot (`validateRoleSkillMappings`) warns (never crashes) if
  `RoleDefinitions` references a skill Id with no implementation yet, so a
  role can be data-configured ahead of the skill being coded.

---

## 10. Cross-platform

- Prefer `ProximityPrompt` for any world interaction — Roblox natively
  renders the correct touch/gamepad/keyboard prompt, so most of the
  "item/mechanism/dialog/minigame trigger" surface needs zero custom
  cross-platform input code.
- `Shared/Platform/Platform.lua` covers what Roblox doesn't:
  `GetCurrentScheme()` (Touch/Gamepad/MouseKeyboard, live-updating via
  `UserInputService.LastInputTypeChanged`) and
  `GetRecommendedUIScale()` (console/phone/desktop-appropriate `UIScale`
  factor). Every place's `UIController` applies this to every `ScreenGui`
  under `PlayerGui` on start.
- Custom-input UI (minigames like PIN code / sliding puzzle, dialog choice
  lists) must be built with standard `GuiObject`s (buttons, not raw
  keyboard key listeners) so Roblox's own focus/selection navigation
  handles gamepad/touch for you — this is a review-time check, not
  something enforced in code.

---

## 11. Data model (illustrative)

```lua
-- Shared/Types/Types.lua
export type PlayerProfileData = {
    role: Role?,
    familyId: string,
    joinedAt: number,
}

export type FamilyRoster = {
    familyId: string,
    accessCode: string, -- current leg's reserved-server access code (not durable across places — see §2)
    members: { [number]: FamilyMember },
}

export type FamilySessionState = {
    familyId: string,
    journalFragmentsCollected: { [string]: boolean },
    mechanismStates: { [string]: MechanismState },
    puzzleGroupsCompleted: { [string]: boolean },
    sessionStatus: "Lobby" | "InProgress" | "Won",
    startedAt: number,
}
```

`familyId` (not `accessCode`) is the durable cross-place identifier — see
§2. Family-level state lives in one place per System, keyed by whatever
that System needs (not duplicated per player), for the same reason as v1:
duplicating shared state per-player is the classic "player A sees fragment
collected, player B doesn't" bug class.

---

## 12. Scalability

- **Concurrency admission control (§8)** is the actual scaling lever for
  this event, not per-server player count — Roblox already scales Hub's
  public servers elastically per player demand.
- **Event-driven, not polling.** Signals (`DataSystem.ProfileLoaded`,
  `DoorLockSystem.AllGeneratorsActivated`, `PlayerStatsSystem.HealthChanged`,
  ...) — nothing runs on `Heartbeat` unless it's genuinely continuous
  (e.g. `UlarJatinangor`'s patrol `MoveTo` loop).
- **Scope broadcasts to the family** (`FamilySystem.GetFamilyPlayers()`),
  never `FireAllClients` — each PlayArea/Lobby server instance only ever
  has one family anyway, but it's still the correct default habit.
- **Content is additive** (§5) — the bottleneck during the remaining build
  window is level-design content, not code, if the plugin pattern is used
  as intended.

## 13. Maintainability

- **Luau strict typing** (`--!strict`) on every module — unchanged from
  v1, matters more now with more programmers touching more files
  concurrently.
- **Linting/formatting in CI** (`selene` + `stylua`), now run against
  three build targets (`places/{hub,lobby,playarea}.project.json`) instead
  of one.
- **Naming**: `PascalCase` Systems/Controllers, `camelCase`
  locals/functions, `SCREAMING_SNAKE` true constants, `Domain_Action`
  Remotes — unchanged from v1.
- **One PR = one system change.** A System living in its own folder makes
  this easy to actually enforce in review, not just request.

## 14. Production-grade concerns

- **Security:** every gameplay decision is re-validated server-side (§1,
  §6.4). Every Remote payload is attacker-controlled until proven
  otherwise.
- **Error handling:** every System's `Init`/`Start` is individually
  `pcall`'d by `PluginRegistry` (§3) — one system's bug degrades, it
  doesn't take the server down. DataStore/ProfileService calls remain
  wrapped in `pcall` with kick-on-failure rather than silent desync.
- **Centralized logging:** `Log.new(moduleName)` unchanged from v1 —
  every System/Controller in this doc uses it.
- **Graceful shutdown:** `PlayArea/Server/init.server.lua`'s
  `game:BindToClose` saves all profiles AND releases the family's
  admission slot (§8.4) — the second part is new in v2 and closes most of
  the "family session never ends" failure mode from the admission design.
- **Analytics hooks:** `GameSystem.HandleWin` has a `TODO` for persisting
  completion analytics via `DataSystem` — same as v1, not yet implemented,
  intentionally left as a small, clearly-marked follow-up rather than
  speculatively built out.
- **Feature flags:** `SessionConstants.lua` and `RoleDefinitions.lua`
  remain the pattern for ops-tunable knobs without a code change — extend
  this same pattern for any puzzle group not ready by ship date, as v1
  recommended.
