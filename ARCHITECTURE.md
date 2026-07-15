# Jatinangor Paradox — Technical Architecture

Version 0.1 · Tech Lead reference doc · Target release: 14–17 Aug 2026

This document defines the production architecture for the game. It assumes a
team of scripters/builders of mixed experience, a ~3-week build window, and
servers of 20–25 concurrent players (one "family" per server instance).

---

## 1. Guiding principles

1. **Server-authoritative, always.** The client never decides who has a role,
   what dimension a player is in, or whether a mechanism activates. It only
   *requests* and *renders*. This is non-negotiable for an exploit-resistant
   Roblox game.
2. **Data-driven content, not hardcoded scripts per puzzle.** Puzzles are
   configured via Attributes/tables, not one-off scripts per object, so
   builders can add content without a scripter touching code every time.
3. **Composable services, not a monolith.** Each system (Role, Dimension,
   Puzzle, Journal, Data) is an independent module with a narrow interface.
4. **Boring and battle-tested over clever.** Given the timeline, we use
   proven community libraries (ProfileService, Signal) instead of writing
   our own persistence/event layers from scratch.

---

## 2. Architectural pattern: Service/Controller

We use a lightweight **Service (server) / Controller (client)** pattern,
similar in spirit to the community `Knit` framework, but hand-rolled and
minimal so the team isn't learning a heavy framework under time pressure.

- **Service** = a server-side singleton module owning one domain (e.g.
  `RoleService`, `DimensionService`). Services can call each other directly
  through a central `Services` registry — no circular `require` chains.
- **Controller** = the client-side equivalent, owning one UI/interaction
  domain (e.g. `RoleController`, `DimensionController`).
- **Net layer** = the only thing allowed to touch `RemoteEvent`/
  `RemoteFunction` directly. Services/Controllers never create Remotes ad hoc.

```
                        ┌─────────────────────────────┐
                        │        ReplicatedStorage     │
                        │  Shared/  (types, constants,  │
                        │  Net wrapper, Signal, Packages)│
                        └──────────────┬───────────────┘
                                       │ required by both sides
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
┌───────▼────────┐            ┌────────▼────────┐            ┌────────▼────────┐
│ ServerScriptSvc │            │   StarterPlayer  │            │    StarterGui    │
│  Services/      │◄──Remotes─►│  Controllers/    │            │  (pure UI, no    │
│  - RoleService  │            │  - RoleController│            │   game logic)    │
│  - DimensionSvc │            │  - DimensionCtrl │            │                  │
│  - PuzzleSvc    │            │  - PuzzleCtrl    │            └──────────────────┘
│  - JournalSvc   │            │  - JournalCtrl   │
│  - DataService  │            │  - UIController  │
│  - GameService   │            └─────────────────┘
└─────────────────┘
```

---

## 3. Repository / place folder structure (Rojo-mapped)

```
jatinangor-paradox/
├── default.project.json      # Rojo project file — maps folders to the DataModel
├── wally.toml                 # dependency manifest (ProfileService, Signal, etc.)
├── selene.toml                 # linter config
├── stylua.toml                 # formatter config
├── .github/workflows/ci.yml    # lint + format + build check on every PR
├── .gitignore
├── README.md
├── docs/
│   └── ARCHITECTURE.md         # this file
└── src/
    ├── ReplicatedStorage/
    │   └── Shared/
    │       ├── Constants/
    │       │   ├── RoleConstants.lua
    │       │   ├── DimensionConstants.lua
    │       │   └── RemoteNames.lua
    │       ├── Types/
    │       │   └── Types.lua           -- shared Luau type defs
    │       ├── Net/
    │       │   └── Net.lua             -- thin wrapper over Remotes
    │       ├── Util/
    │       │   ├── Signal.lua
    │       │   └── Maid.lua
    │       └── Packages/               -- Wally-installed (ProfileService etc.)
    │
    ├── ServerScriptService/
    │   └── Server/
    │       ├── init.server.lua         -- bootstraps all services in order
    │       ├── Services/
    │       │   ├── DataService.lua      -- profile load/save (ProfileService)
    │       │   ├── PlayerService.lua     -- join/leave lifecycle, family grouping
    │       │   ├── RoleService.lua       -- assigns + validates roles
    │       │   ├── DimensionService.lua  -- normal/alter state per player
    │       │   ├── PuzzleService.lua     -- mechanism validation + state
    │       │   ├── JournalService.lua    -- journal fragment collection
    │       │   └── GameService.lua       -- win condition, session lifecycle
    │       └── Content/
    │           └── PuzzleDefinitions.lua -- data-driven puzzle configs
    │
    ├── StarterPlayer/
    │   └── StarterPlayerScripts/
    │       └── Client/
    │           ├── init.client.lua      -- bootstraps all controllers
    │           └── Controllers/
    │               ├── RoleController.lua
    │               ├── DimensionController.lua
    │               ├── PuzzleController.lua
    │               ├── JournalController.lua
    │               └── UIController.lua
    │
    └── StarterGui/
        └── ScreenGui placeholders (built in Studio, referenced by name)
```

**Why Rojo:** it lets the team work in real files/VS Code with Git history,
instead of everything living only inside a `.rbxl` binary that can't be
diffed or merged. This is the single highest-leverage tooling decision for a
multi-person team on a deadline.

---

## 4. Core systems

### 4.1 RoleService (server) / RoleController (client)

- **Owns:** which of Merah/Kuning/Hijau each player has, and validates any
  action gated by role.
- **On player join:** assigns a role (round-robin or profile-persisted, see
  §4.6), stores it as a server-side value in a `Players[userId].role` table
  — **never** as a client-settable Attribute for anything security-relevant.
  A read-only Attribute is fine for *display* (e.g. tinting the player's
  name tag), but any gameplay check re-validates server-side.
- **Exposes:** `RoleService:GetRole(player): Role`,
  `RoleService:CanAccess(player, mechanismId): boolean`.
- **Client only receives:** its own role + role-specific clue visibility
  flags. It never receives other players' full role data unless the design
  calls for it.

### 4.2 DimensionService / DimensionController

- **Owns:** which dimension (Normal/Alter) each player currently occupies.
- Dimension switch is a **server-invoked teleport + collision-group swap**
  (or place-local: two overlapping/duplicate map layers with
  `Workspace` folder toggling + `SetCollisionGroup`, whichever v1.2's level
  design implies once Bab III lands). Client never toggles its own
  visibility of the other world; server assigns which folder is visible via
  `StreamingEnabled`/`CollectionService` tags.
- **Exposes:** `DimensionService:GetDimension(player)`,
  `DimensionService:SwitchDimension(player, targetDimension)`.

### 4.3 PuzzleService / PuzzleController

- **Owns:** mechanism state (levers, PIN panels, pressure plates) as
  **data**, not as scattered scripts.
- Each interactable in Studio gets a `CollectionService` tag (e.g.
  `"Mechanism"`) plus Attributes: `MechanismId`, `RequiredRole`,
  `PuzzleGroupId`. `PuzzleService` scans for tagged instances on startup and
  builds an in-memory state table — **builders add new puzzles without a
  scripter writing new code**, as long as they tag correctly.
- **Interaction flow:** client fires `Net:FireServer("Interact", mechanismId)`
  → `PuzzleService` checks role + dimension + puzzle-group prerequisites →
  mutates state → fires `Net:FireClients(familyPlayers, "MechanismUpdated", state)`.
- **Never trust distance/proximity from the client** — server re-checks
  `(HumanoidRootPart.Position - mechanismPosition).Magnitude` before
  accepting an interaction.

### 4.4 JournalService / JournalController

- **Owns:** which journal fragments a family has collected (shared state
  per family, not per player — this is a collaborative game).
- Fragment pickup: server validates proximity + ownership-not-already-
  collected → writes to `DataService` (session state, not necessarily
  persisted long-term unless replay/analytics wants it) → broadcasts to all
  family members so the shared journal UI updates for everyone.

### 4.5 GameService

- **Owns:** overall session state machine: `Lobby → InProgress → Won`.
- Polls/subscribes to `PuzzleService` + `DimensionService` state to
  evaluate the win condition (portal stabilized = all required generators
  activated). Fires the win sequence, locks further interaction, and is the
  single place that decides "the game is over."

### 4.6 DataService

- Wraps **ProfileService** (industry-standard session-locked DataStore
  library — do not hand-roll DataStore code; race conditions and data loss
  from custom implementations are the #1 cause of Roblox production bugs).
- Given this is a ~30-minute one-shot session per family rather than a
  persistent-progression game, `DataService` may only need to persist:
  minimal analytics (completion time, which puzzles were solved) and
  optionally a role-assignment seed so re-joins after a disconnect restore
  the same role instead of reassigning.
- **`game:BindToClose()`** must call the profile-release/save path so a
  server shutdown mid-event doesn't lose data — this matters a lot given
  6500+ players across many concurrent sessions during a live event.

---

## 5. Networking layer (the `Net` module)

All Remotes go through one wrapper so you get consistent naming, logging,
and rate-limiting in one place instead of scattered `RemoteEvent:FireServer`
calls everywhere.

```lua
-- Shared/Net/Net.lua (abbreviated)
local Net = {}

function Net.FireServer(remoteName: string, ...: any)
    -- looks up the RemoteEvent by name, fires it
end

function Net.OnServerEvent(remoteName: string, callback: (player: Player, ...any) -> ())
    -- wraps with a per-player rate limiter before calling callback
end

return Net
```

**Rate limiting is mandatory** on every server-received remote (e.g. max 10
interactions/second/player) — this is the cheapest possible defense against
both accidental UI-spam bugs and deliberate exploit spam, and it's a two-line
addition if it's centralized here from day one.

**Naming convention:** `Domain_Action`, e.g. `Puzzle_Interact`,
`Dimension_RequestSwitch`, `Journal_Collect`. Defined once in
`RemoteNames.lua` as constants — never magic strings scattered across files.

---

## 6. Data flow walkthroughs

### 6.1 Player join

```
PlayerAdded
  → PlayerService: register player, assign to a "family group" table
  → DataService: load profile (ProfileService, session-locked)
  → RoleService: assign role (from profile if rejoining, else round-robin
                 balanced across the 3 roles for that family)
  → DimensionService: assign starting dimension
  → Net: push initial state to that client only
      (own role, own dimension, current shared journal/puzzle state)
```

### 6.2 Puzzle interaction

```
Client: proximity prompt triggered → Net.FireServer("Puzzle_Interact", mechanismId)
Server (rate-limited):
  → PuzzleService: look up mechanism by id
  → RoleService:CanAccess(player, mechanismId)?   -- reject if false
  → DimensionService: is player in the required dimension?  -- reject if false
  → distance check (anti-exploit)
  → mutate mechanism state, check puzzle-group completion
  → Net.FireClients(familyMembers, "Puzzle_MechanismUpdated", newState)
  → GameService: re-evaluate win condition
```

### 6.3 Dimension switch

```
Client: interacts with a dimension-switch trigger
  → Net.FireServer("Dimension_RequestSwitch")
Server:
  → DimensionService validates the request is currently allowed
    (e.g. only at designated portal points, not mid-puzzle)
  → moves player's visible Workspace layer / collision group / position
  → Net.FireClient(player, "Dimension_Switched", newDimension)
  → Net.FireClients(familyMembers, "Dimension_PlayerMoved", player, newDimension)
    -- so teammates' shared-state UI (e.g. "who's where") stays in sync
```

### 6.4 Win condition

```
GameService subscribes to PuzzleService "AllGeneratorsActivated" signal
  → triggers portal-stabilization sequence (cutscene/FX via a Net broadcast)
  → GameService: session state → "Won"
  → DataService: persist completion analytics
  → lock further Puzzle_Interact requests (server-side guard)
```

---

## 7. Data model (illustrative)

```lua
type PlayerProfile = {
    role: "Merah" | "Kuning" | "Hijau"?,
    dimension: "Normal" | "Alter",
    familyId: string,
    joinedAt: number,
}

type FamilySessionState = {
    familyId: string,
    journalFragmentsCollected: {[string]: boolean},
    mechanismStates: {[string]: any},
    puzzleGroupsCompleted: {[string]: boolean},
    sessionStatus: "Lobby" | "InProgress" | "Won",
    startedAt: number,
}
```

Family-level state (`FamilySessionState`) lives in one place
(`GameService`/`DataService`), keyed by `familyId` — **not** duplicated per
player — since journals and mechanisms are shared, collaborative state, and
duplicating it per-player is exactly the kind of subtle bug ("player A sees
fragment collected, player B doesn't") that's expensive to debug during a
live event.

---

## 8. Scalability

- **One server instance = one family (~20-25 players).** Use
  `TeleportService:ReserveServer` + access codes so families land in
  private, dedicated servers rather than public matchmaking — this is
  standard for an event with 6500+ projected players across many time
  slots.
- **Avoid per-frame polling.** Use `Signal`/event-driven updates
  (mechanism state changes fire a signal; nothing runs on `Heartbeat`
  unless it's genuinely continuous, like a moving platform).
- **Scope broadcasts to the family, never `FireAllClients`.** With many
  concurrent server instances this doesn't matter for bandwidth (each
  instance only has its own family anyway), but it's still the correct
  default habit.
- **Data-driven puzzles (§4.3)** scale content creation independent of
  scripting capacity — your bottleneck during the remaining ~3 weeks is
  level design content, not code, if this is set up correctly.

## 9. Maintainability

- **Luau strict typing**: `--!strict` at the top of Service/Controller
  modules. Catches a large class of bugs (wrong argument order, nil access)
  before runtime, which matters when several people touch the same files.
- **Linting/formatting in CI**: `selene` (lint) + `stylua` (format) run on
  every PR via GitHub Actions (`ci.yml` included in the skeleton). Nobody
  argues about style; the bot enforces it.
- **Naming conventions**: `PascalCase` for ModuleScripts/Services/
  Controllers, `camelCase` for local variables/functions, `SCREAMING_SNAKE`
  for true constants.
- **One PR = one system change.** Given the compressed timeline, small
  frequent PRs reviewed same-day beat large infrequent ones.
- **`docs/ARCHITECTURE.md` (this file) stays in the repo** and gets updated
  when the architecture changes — not left to go stale.

## 10. Production-grade concerns

- **Security:** every gameplay-affecting decision is re-validated
  server-side, full stop (see §4.1–4.3). Treat every RemoteEvent payload as
  attacker-controlled.
- **Error handling:** wrap all DataStore/ProfileService calls in `pcall`
  with retry/backoff; never let an unhandled DataStore error crash a
  service — a family losing progress mid-event is a real reputational risk
  for a 6500-person orientation program.
- **Centralized logging:** a small `Log` module (`Log.info`, `Log.warn`,
  `Log.error`) that tags output with service name + timestamp, so
  `output`/`DataStore`-based error logs are actually searchable during a
  live event when you have zero time to dig.
- **Analytics hooks:** even minimal — time-to-complete, which puzzle groups
  stalled longest — are valuable both for live troubleshooting during the
  event window and for the KAT organizers' post-event report.
- **Graceful shutdown:** `game:BindToClose()` saves/releases all active
  profiles before the server closes (Roblox gives ~30s during deploys).
- **Feature flags for content not ready by ship date:** if a puzzle group
  isn't finished in time, a simple `Constants.lua` toggle should be able to
  disable it without deleting code, so under-time-pressure scope cuts don't
  turn into merge conflicts.

---
