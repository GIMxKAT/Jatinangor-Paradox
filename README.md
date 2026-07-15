# Jatinangor Paradox

> **Roblox collaborative puzzle-escape game** — built for KAT ITB OSKM 2026.  
> A family of ~20–25 players must cooperate across two overlapping dimensions
> (Normal & Alter) to stabilise a portal and escape. Target release: **14–17 Aug 2026**.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Project Resources](#2-project-resources)
3. [Prerequisites](#3-prerequisites)
4. [First-Time Setup](#4-first-time-setup)
5. [Day-to-Day Workflow](#5-day-to-day-workflow)
6. [Repository Layout](#6-repository-layout)
7. [Architecture in Plain English](#7-architecture-in-plain-english)
   - [The Golden Rule: Server-Authoritative](#71-the-golden-rule-server-authoritative)
   - [Service / Controller Pattern](#72-service--controller-pattern)
   - [Bootstrap Order](#73-bootstrap-order)
   - [The Net Module](#74-the-net-module)
   - [How a Puzzle Interaction Flows](#75-how-a-puzzle-interaction-flows)
8. [Adding Content (No-Code Paths)](#8-adding-content-no-code-paths)
9. [Coding Standards](#9-coding-standards)
10. [CI Pipeline](#10-ci-pipeline)
11. [Known TODOs (Active Work)](#11-known-todos-active-work)
12. [Team & Responsibilities](#12-team--responsibilities)
13. [FAQ for Programmers](#13-faq-for-junior-scripters)

---

## 1. Project Overview

| Property | Value |
|---|---|
| Engine | Roblox (Luau / `--!strict`) |
| Toolchain manager | [Rokit](https://github.com/rojo-rbx/rokit) |
| Studio sync | [Rojo 7](https://rojo.space) |
| Package manager | [Wally](https://wally.run) |
| Key dependencies | ProfileService (DataStore wrapper), custom Signal/Maid/Log utilities |
| Linter / formatter | Selene + StyLua (enforced in CI) |
| Server model | 1 server instance = 1 reserved family session (~20–25 players) |

The full technical design — data models, data-flow diagrams, scalability
rationale — lives in [`ARCHITECTURE.md`](ARCHITECTURE.md). **Read that
document before writing any Service or Controller code.** This README is
the quick-start and day-to-day reference.

---

## 2. Project Resources

> **Update these links as soon as the Notion workspace and Google Sheets are created.**
> Every team member should be able to find everything from this table — no asking in the chat.

| Resource | What it's for | Link |
|---|---|---|
| 📋 **Notion Workspace** | Milestone tracker, sprint kanban, decision log, meeting notes | [Open Notion →](https://app.notion.com/p/Jatinangor-Paradox-Project-Hub-39eae794b663805a9c1fd8466ecec462?source=copy_link) |
| 🧩 **Puzzle Content Tracker** | Mechanism IDs, roles, dimensions, studio tagging status | [Open Sheets →](https://docs.google.com/spreadsheets/d/1qF3Y-30h0lpJIHFaevTiGcktnLVUEKFXPCJc8-GwRe8/edit?gid=0#gid=0) |
| 📔 **Journal Fragment Tracker** | Fragment IDs, locations, tagging status | [Open Sheets →](https://docs.google.com/spreadsheets/d/1qF3Y-30h0lpJIHFaevTiGcktnLVUEKFXPCJc8-GwRe8/edit?gid=1338519728#gid=1338519728) |
| 🐛 **Bug Tracker** | Bug reports, severity, assignments, fix status | [Open Sheets →](https://docs.google.com/spreadsheets/d/1qF3Y-30h0lpJIHFaevTiGcktnLVUEKFXPCJc8-GwRe8/edit?gid=1893503894#gid=1893503894) |

---

## 3. Prerequisites

Install these once on your machine:

| Tool | What it does | Install |
|---|---|---|
| **Git** | Version control | https://git-scm.com |
| **VS Code** | Editor | https://code.visualstudio.com |
| **Rojo VS Code extension** | Syncs files → Roblox Studio live | Search "Rojo" in the Extensions panel |
| **Rokit** | Toolchain manager — pins exact versions of Rojo, Wally, Selene, StyLua | See §3 below |

> **macOS / Linux** users: ensure your shell's `$PATH` includes `~/.rokit/bin`
> after installation (the installer prints this instruction).

---

## 4. First-Time Setup

Run these commands **once** when you first clone the repo. They do not need
to be repeated unless you wipe your machine or `rokit.toml` / `wally.toml`
changes.

```bash
# 1. Install Rokit (toolchain manager)
#    macOS / Linux:
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | sh
#    Windows: download the installer from https://github.com/rojo-rbx/rokit/releases

# 2. Clone the repository
git clone <repo-url>
cd jatinangor-paradox

# 3. Install the pinned toolchain (rojo, wally, selene, stylua)
#    --accept-all-tool-trust skips the interactive trust prompt for each tool
rokit install --accept-all-tool-trust

# 4. Install Wally packages (ProfileService → Packages/ folder)
wally install

# 5. Verify the build compiles cleanly
rojo build default.project.json --output build.rbxlx
#    You should see no errors. The .rbxlx file is git-ignored; delete it.
```

**Connecting to Roblox Studio:**

```bash
# 6. Start the Rojo dev server (keep this terminal open)
rojo serve

# 7. In Roblox Studio: open the Rojo plugin → click Connect (default port 34872)
#    → click Sync In.
#    Your src/ files now live in the DataModel and hot-reload on every save.
```

> **Why Rojo instead of editing directly in Studio?**  
> Rojo gives us real files, real Git diffs, and real PR reviews. Without it,
> every change to a Script is a binary blob in a `.rbxl` that nobody can
> review or merge. This is the single highest-leverage tooling choice for a
> multi-person team.

---

## 5. Day-to-Day Workflow

```
Write code in VS Code  →  Rojo hot-syncs to Studio  →  Test in Play mode
                                                             ↓
                                                     git commit + push
                                                             ↓
                                                     open PR  →  CI runs
                                                             ↓
                                                     1 review + CI green → merge
```

### Before you push

```bash
# Format your code (CI will reject unformatted code)
stylua src/

# Lint your code (CI will reject lint errors)
selene src/
```

### Branch naming convention

```
feature/<short-description>   # new system or mechanic
fix/<short-description>       # bug fix
content/<short-description>   # data/config-only change (no logic)
```

### Pull Request rules

- **One PR = one system change.** Keep PRs small and reviewable same-day.
- Server-authoritative logic is a **hard blocker** in review, not a nitpick.
  If a PR lets the client decide any gameplay outcome, it will be rejected.
  (See §6.1 for what this means.)
- Tag your PR with `needs-review` and post in the team chat.

---

## 6. Repository Layout

```
jatinangor-paradox/
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions: format + lint + build on every PR
├── .gitignore                  # Ignores *.rbxl, build artefacts, Packages/
├── ARCHITECTURE.md             # Full technical design — read this first!
├── README.md                   # This file
├── default.project.json        # Rojo mapping: src/ folders → Roblox DataModel
├── rokit.toml                  # Pinned versions of rojo/wally/selene/stylua
├── wally.toml                  # Lua package dependencies (ProfileService, etc.)
├── wally.lock                  # Auto-generated; commit this, don't edit by hand
├── selene.toml                 # Linter rules
├── stylua.toml                 # Formatter rules
├── Packages/                   # Auto-generated by `wally install`; git-ignored
└── src/
    ├── ReplicatedStorage/
    │   └── Shared/             # Required by BOTH server and client
    │       ├── Constants/
    │       │   ├── DimensionConstants.lua   # "Normal" | "Alter" + exported type
    │       │   ├── RemoteNames.lua          # Every RemoteEvent name as a constant
    │       │   └── RoleConstants.lua        # "Merah" | "Kuning" | "Hijau" + type
    │       ├── Net/
    │       │   └── Net.lua                  # The ONLY place that touches RemoteEvents
    │       ├── Types/
    │       │   └── Types.lua                # Shared Luau type definitions
    │       └── Util/
    │           ├── Log.lua                  # Timestamped, tagged logging
    │           ├── Maid.lua                 # Connection/instance cleanup
    │           └── Signal.lua              # Lightweight typed event system
    │
    ├── ServerScriptService/
    │   └── Server/
    │       ├── init.server.lua             # Bootstrap: loads all Services in order
    │       ├── Content/
    │       │   └── PuzzleDefinitions.lua   # Data-driven puzzle group configs
    │       └── Services/                   # Server-side domain singletons
    │           ├── DataService.lua         # Profile load/save via ProfileService
    │           ├── DimensionService.lua    # Normal ↔ Alter dimension state
    │           ├── GameService.lua         # Session state machine (Lobby→InProgress→Won)
    │           ├── JournalService.lua      # Shared journal fragment collection
    │           ├── PlayerService.lua       # Family grouping + player list
    │           ├── PuzzleService.lua       # Mechanism state + interaction validation
    │           └── RoleService.lua         # Role assignment + authorization
    │
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── Client/
                ├── init.client.lua         # Bootstrap: loads all Controllers in order
                └── Controllers/            # Client-side domain singletons
                    ├── DimensionController.lua
                    ├── JournalController.lua
                    ├── PuzzleController.lua
                    ├── RoleController.lua
                    └── UIController.lua    # Wires all UI to Controller signals
```

---

## 7. Architecture in Plain English

### 7.1 The Golden Rule: Server-Authoritative

> **The client never decides who has a role, what dimension a player is in,
> or whether a mechanism activates. It only *requests* and *renders*.**

This is the most important rule in the codebase. Treat every value the client
sends as potentially forged by an exploiter. Every gameplay-affecting decision
must be **re-validated on the server** before state changes.

Concrete examples:

| ❌ Client does this (BAD) | ✅ Server does this (GOOD) |
|---|---|
| `mechanism.Activated = true` | Client fires `Net.FireServer("Puzzle_Interact", id)`, server validates and mutates state |
| Reads its own role from an Attribute and gates gameplay | Server re-calls `RoleService.CanAccess(player, role)` on every interaction |
| Checks its own position before sending | Server re-checks `(rootPart.Position - mechanismPart.Position).Magnitude` |

### 7.2 Service / Controller Pattern

Each domain of the game is owned by exactly one **Service** (server) and one
**Controller** (client). They are singletons — `require` returns the same table
every time.

```
Server (ServerScriptService)         Client (StarterPlayerScripts)
────────────────────────────         ──────────────────────────────
DataService       (profiles)         RoleController     (my role)
PlayerService     (family list)      DimensionController (my dimension)
RoleService       (assignments)      PuzzleController    (interact UI)
DimensionService  (dimensions)       JournalController   (fragment UI)
PuzzleService     (mechanisms)       UIController        (wires all UI)
JournalService    (fragments)
GameService       (win condition)
```

Services talk to each other through the **ServiceRegistry** table injected
at `Init` time — never via raw `require` across files. This prevents the
circular dependency trap.

Controllers do the same through the **ControllerRegistry**.

### 7.3 Bootstrap Order

Both `init.server.lua` and `init.client.lua` use the same two-phase pattern:

```
Phase 1 — Init:   every module receives the registry and saves references.
                  No inter-service calls yet.

Phase 2 — Start:  every module connects events, starts listening to Remotes,
                  and fires initial state.
```

**Why two phases?** If `RoleService.Init` called `DataService.GetProfile()`
immediately, it would fail because `DataService` might not have loaded
profiles yet. The split guarantees all modules are constructed before any of
them try to call each other.

```lua
-- init.server.lua (simplified)
local ServiceRegistry = { Data = DataService, Role = RoleService, ... }

for name, service in ServiceRegistry do
    service.Init(ServiceRegistry)   -- Phase 1: store refs, no cross-calls
end

for name, service in ServiceRegistry do
    service.Start()                 -- Phase 2: connect events, start logic
end

game:BindToClose(function()
    DataService.SaveAll()           -- Graceful shutdown: release all profiles
end)
```

### 7.4 The Net Module

`Shared/Net/Net.lua` is the **only** module allowed to create or touch
`RemoteEvent` instances. Services and Controllers never call
`RemoteEvent:FireServer()` directly.

```lua
-- ✅ Correct
Net.FireServer(RemoteNames.Puzzle_Interact, mechanismId)
Net.OnServerEvent(RemoteNames.Puzzle_Interact, function(player, id) ... end)

-- ❌ Wrong
game.ReplicatedStorage.Remotes.Puzzle_Interact:FireServer(mechanismId)
```

**Why?** Net gives us three things for free on every remote:
1. **Known-remote assertion** — a typo in a remote name throws immediately
   instead of silently doing nothing.
2. **Rate limiting** — built-in per-player, per-remote throttle (default 10
   calls/sec). Prevents both exploit spam and accidental UI-loop bugs.
3. **One place to add logging/metrics** — add `print(remoteName)` in Net once
   and every remote is logged. No need to touch 20 Service files.

Remote names are declared once in `Constants/RemoteNames.lua`. **Never use a
magic string remote name anywhere else in the codebase.**

### 7.5 How a Puzzle Interaction Flows

```
1. Player walks near a mechanism and triggers a ProximityPrompt
   (PuzzleController — client only, fires the request)
         ↓
2. Net.FireServer("Puzzle_Interact", mechanismId)
         ↓
3. PuzzleService.HandleInteract(player, mechanismId)   [server]
   ├─ Is mechanismId a string?           → reject if not (exploit guard)
   ├─ Does this mechanism exist?         → reject if not
   ├─ RoleService.CanAccess(player, ...)?→ reject if wrong role
   ├─ (Dimension check — see §4.2 ARCHITECTURE.md)
   └─ Distance check (server re-checks!) → reject if too far
         ↓
4. state.activated = true
         ↓
5. Net.FireClients(familyPlayers, "Puzzle_MechanismUpdated", id, true)
         ↓
6. PuzzleService.CheckGroupCompletion()
   └─ all mechanisms in group done?
         └─ PuzzleService.AllGeneratorsActivated:Fire()
               ↓
7. GameService.HandleWin()
   ├─ sessionStatus = "Won"
   ├─ Net.FireClients(family, "Game_StateChanged", "Won")
   └─ DataService: persist analytics
```

---

## 8. Adding Content (No-Code Paths)

### Adding a new puzzle mechanism

You do **not** need to write any Lua code to add a mechanism. Builders do this
entirely in Studio:

1. Select the mechanism Part/Model in the Workspace.
2. Add the CollectionService tag: **`Mechanism`**
   *(Plugins → Tag Editor, or use the `CollectionService` button in the
   Properties panel)*
3. Add these **Attributes** on the same instance:

   | Attribute | Type | Example | Required? |
   |---|---|---|---|
   | `MechanismId` | string | `"Lever_A3"` | ✅ |
   | `RequiredRole` | string | `"Merah"` | ✅ |
   | `PuzzleGroupId` | string | `"Generator_A"` | ✅ |

4. `PuzzleService` scans for the `Mechanism` tag on `Start()` and again when
   new instances are added at runtime — it picks up your mechanism
   automatically.

> **If any of the three Attributes are missing**, the mechanism is skipped and
> a warning is printed in the Output (`[PuzzleService][WARN] ... missing
> required Attributes`). Check Output if your mechanism doesn't respond.

### Adding a new journal fragment

1. Tag the Part/Model with: **`JournalFragment`**
2. Add Attribute: `FragmentId` (string, e.g. `"Fragment_07"`)

`JournalService` handles the rest.

---

## 9. Coding Standards

### Luau strict typing

Every module **must** start with:

```lua
--!strict
```

This enables Luau's type checker, which catches wrong argument order, nil
access, and type mismatches before runtime. This is non-negotiable because
several people touch the same files.

### Naming conventions

| Thing | Convention | Example |
|---|---|---|
| ModuleScript / Service / Controller | PascalCase | `RoleService`, `UIController` |
| Local variable / function | camelCase | `playerRoles`, `assignRole` |
| True constant | SCREAMING_SNAKE_CASE | `MAX_INTERACT_DISTANCE`, `PROFILE_STORE_NAME` |
| Remote name | `Domain_Action` | `Puzzle_Interact`, `Dimension_RequestSwitch` |
| **Intentionally unused variable** | `_` prefix | `_role`, `_player`, `for _key, value in` |

The `_` prefix tells Selene (and the next developer) *"I know this parameter exists — it's not wired up yet."*
Remove the `_` when you implement the stub. Example:

```lua
-- Stub (linter-safe)
registry.Role.RoleAssigned:Connect(function(_role: string)
    -- TODO: wire to HUD
end)

-- After implementation — drop the underscore
registry.Role.RoleAssigned:Connect(function(role: string)
    playerGui.HUD.RoleLabel.Text = role
end)
```

### Module structure template

```lua
--!strict
-- ModuleName
--
-- One-line summary of what this module owns.
-- Cross-reference ARCHITECTURE.md §X if relevant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("ModuleName")

local MyModule = {}

-- Module-level state (server-side only — never replicated implicitly)
local someState: { [Player]: boolean } = {}

-- Injected service/controller references (set in Init, used in Start+)
local OtherService: any

function MyModule.Init(registry: { [string]: any })
    OtherService = registry.OtherServiceKey
end

function MyModule.Start()
    -- Connect events, register Net listeners here
end

return MyModule
```

### Logging

Use `Log` instead of raw `print` / `warn`:

```lua
local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("ServiceName")  -- one per module, at the top

log:Info("Something happened")          -- [HH:MM:SS][ServiceName][INFO] ...
log:Warn("Something suspicious")        -- [HH:MM:SS][ServiceName][WARN] ...
log:Error("Something broke")           -- [HH:MM:SS][ServiceName][ERROR] ...
```

Consistent tags make logs searchable in the Output during a live event when
you have zero time to dig.

### Error handling for DataStore calls

Wrap **all** `DataService` / `ProfileService` calls in `pcall`. A DataStore
error must never crash a service — a family losing their progress mid-event
is a reputational risk for a 6500-person orientation program.

```lua
local ok, result = pcall(function()
    return DataService.GetProfile(player)
end)
if not ok then
    log:Error(("GetProfile failed: %s"):format(tostring(result)))
    return
end
```

---

## 10. CI Pipeline

Every pull request and push to `main` triggers the GitHub Actions workflow
in `.github/workflows/ci.yml`. All three checks must pass before merging.

| Step | Command | What fails it |
|---|---|---|
| Formatting | `stylua --check src/` | Any file not formatted to `stylua.toml` rules |
| Linting | `selene src/` | Lint errors in `selene.toml` (unused vars, bad patterns) |
| Build | `rojo build default.project.json` | Rojo cannot compile the project (syntax error, bad path, etc.) |

> **Don't wait for CI** — run `stylua src/` and `selene src/` locally before
> pushing. CI failing on a formatting issue is a wasted pipeline run.

---

## 11. Known TODOs (Active Work)

These are incomplete stubs in the codebase. Each one is documented with a
`-- TODO:` comment at the relevant site.

| Location | What's missing | Owner |
|---|---|---|
| `PlayerService.Init` | Read `familyId` from `TeleportData` (reserved server join data) | PlayerService owner |
| `DimensionService.RequestSwitch` | Real proximity/zone check before allowing dimension switch | DimensionService owner |
| `PuzzleService.CheckAllGeneratorsActivated` | Compare `puzzleGroupCompletion` against the full required generator list; fire the win signal | PuzzleService owner |
| `GameService.HandleWin` | Persist completion analytics via DataService | GameService owner |

> Until `CheckAllGeneratorsActivated` is wired up, **the win signal never
> fires** — the game cannot be won in the current build. This is the highest
> priority unblocked item.

---

## 12. Team & Responsibilities

| Role | Responsibility |
|---|---|
| **Tech Lead** | Architecture ownership, code review, Net/Data layer, unblocking scripters |
| **Server scripters** | Services under `src/ServerScriptService/Server/Services/` |
| **Client scripters** | Controllers under `src/StarterPlayer/.../Controllers/` |
| **Builders / level designers** | Studio tagging (mechanisms, fragments) per §7 — no Lua required |

### Review rule (non-negotiable)

> Server-authoritative logic (§6.1) is a **hard blocker** in review.
> If a PR allows the client to decide any gameplay outcome, it is rejected,
> not merged with a comment.

---

## 13. FAQ for Programmers

**Q: Where do I write my code?**  
A: In VS Code, under `src/`. Never edit scripts directly in Roblox Studio —
Rojo will overwrite your Studio edits the next time it syncs.

**Q: How do I call another Service from my Service?**  
A: Through the `registry` table injected in your `Init` function. Example:

```lua
function MyService.Init(registry: { [string]: any })
    local RoleService = registry.Role   -- use the key from init.server.lua
    local role = RoleService.GetRole(player)
end
```

Never `require` another Service's file directly — that creates brittle
relative paths and potential circular dependencies.

**Q: How do I send data from the server to the client?**  
A: Use `Net.FireClient(player, RemoteNames.SomeName, data)` or
`Net.FireClients(playerList, RemoteNames.SomeName, data)`. The remote name
must already exist in `Constants/RemoteNames.lua`.

**Q: How do I add a new RemoteEvent?**  
1. Add the name to `Constants/RemoteNames.lua` (both key and value).
2. Use `Net.FireServer` / `Net.OnServerEvent` / `Net.FireClient` /
   `Net.OnClientEvent` — the Net module creates the actual `RemoteEvent`
   instance automatically.

**Q: My mechanism doesn't respond when I interact. What do I check?**  
1. Is the instance tagged `Mechanism` in CollectionService?
2. Does it have all three Attributes: `MechanismId`, `RequiredRole`,
   `PuzzleGroupId`?
3. Check the Output for `[PuzzleService][WARN] ... missing required Attributes`.
4. Is the player's role correct for `RequiredRole`? Check
   `[RoleService][INFO] Assigned role X to Y` in Output.
5. Is the player close enough? `MAX_INTERACT_DISTANCE = 12` studs (in
   `PuzzleService.lua`).

**Q: The game doesn't end even after all mechanisms are activated.**  
A: `PuzzleService.CheckAllGeneratorsActivated` is a known stub (§10). The
win signal has not been wired up yet — this is a priority TODO.

**Q: Can I use `FireAllClients`?**  
A: No. Always scope broadcasts to `PlayerService.GetFamilyPlayers()` and use
`Net.FireClients(familyPlayers, ...)`. `FireAllClients` is semantically wrong
(other server instances don't share your RemoteEvent anyway) and is a bad
habit.

**Q: What's a Maid? Do I need it?**  
A: A Maid collects RBXScriptConnections and cleans them all up in one call.
Use it in any Service that connects to `PlayerAdded`, `PlayerRemoving`, or
Signals — to avoid memory leaks when the connection target is destroyed.
Example:

```lua
local maid = Maid.new()
maid:Give(Players.PlayerAdded:Connect(function(p) ... end))
-- later, on cleanup:
maid:DoCleaning()
```

---

*For the full data-flow walkthroughs, data models, scalability rationale, and
build order, see [`ARCHITECTURE.md`](ARCHITECTURE.md).*
