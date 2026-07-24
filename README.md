# Jatinangor Paradox

> **Roblox collaborative puzzle-escape game** — built for KAT ITB OSKM 2026.
> A family of ~20–25 players cooperates across a five-role team (Navigator,
> Detective, Scout, Code-Breaker, Support) to escape. Cross-platform
> (PC/mobile/console). Target release: **14–17 Aug 2026**.
>
> **v2 architecture** — the game is now three Roblox places (Hub → Lobby →
> PlayArea) instead of one. **Read
> [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before writing any
> System/Controller code** — this README is quick-start only.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Project Resources](#2-project-resources)
3. [Prerequisites](#3-prerequisites)
4. [First-Time Setup](#4-first-time-setup)
5. [Day-to-Day Workflow](#5-day-to-day-workflow)
6. [Repository Layout](#6-repository-layout)
7. [Architecture in Plain English](#7-architecture-in-plain-english)
8. [Adding Content (No-Code / One-File Paths)](#8-adding-content-no-code--one-file-paths)
9. [Coding Standards](#9-coding-standards)
10. [CI Pipeline](#10-ci-pipeline)
11. [Team & Responsibilities](#11-team--responsibilities)
12. [FAQ for Programmers](#12-faq-for-programmers)

---

## 1. Project Overview

| Property | Value |
|---|---|
| Engine | Roblox (Luau / `--!strict`) |
| Places | **Hub** (public matchmaking) → **Lobby** (reserved, role balancing) → **PlayArea** (reserved, the actual game) |
| Toolchain manager | [Rokit](https://github.com/rojo-rbx/rokit) |
| Studio sync | [Rojo 7](https://rojo.space) |
| Package manager | [Wally](https://wally.run) |
| Key dependencies | ProfileService (DataStore wrapper), MemoryStoreService (session admission), custom Signal/Maid/Log utilities |
| Linter / formatter | Selene + StyLua (enforced in CI) |
| Roles | Navigator, Detective, Scout, Code-Breaker, Support — data-driven, scalable skill system |
| Capacity | ~200-250 family sessions total over the 3-day event, ~50 (+10%) concurrent, race-safe admission control |

The full technical design — place topology, the loose-coupling plugin
architecture, data-flow diagrams, session-admission race-condition
analysis, API catalogue — lives in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). **Read that document before
writing any Service or Controller code.** This README is the quick-start
and day-to-day reference.

---

## 2. Project Resources

> **Update these links as soon as the Notion workspace and Google Sheets are created.**
> Every team member should be able to find everything from this table — no asking in the chat.

| Resource | What it's for | Link |
|---|---|---|
| 📋 **Notion Workspace** | Milestone tracker, sprint kanban, decision log, meeting notes | [Open Notion →](https://app.notion.com/p/Jatinangor-Paradox-Project-Hub-39eae794b663805a9c1fd8466ecec462?source=copy_link) |
| 🧩 **Puzzle Content Tracker** | Mechanism/item/minigame IDs, roles, Studio tagging status | [Open Sheets →](https://docs.google.com/spreadsheets/d/1qF3Y-30h0lpJIHFaevTiGcktnLVUEKFXPCJc8-GwRe8/edit?gid=0#gid=0) |
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

**One-time, ops-only setup (not a repo/CLI step):** the game needs a
multi-place Roblox Universe with three Places (Hub, Lobby, PlayArea)
created in Studio or the Creator Dashboard. Once created, set the real
PlaceIds in `Hub/Server/Systems/MatchmakingSystem/init.lua`
(`LOBBY_PLACE_ID`) and `Lobby/Server/Systems/ReadyCheckSystem/init.lua`
(`PLAYAREA_PLACE_ID`) — both are `0` by default, which fails loudly rather
than silently teleporting players somewhere wrong.

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
rokit install --no-trust-check

# 4. Install Wally packages (ProfileService → Packages/ folder)
wally install

# 5. Verify each place builds cleanly
rojo build places/hub.project.json      --output build-hub.rbxlx
rojo build places/lobby.project.json    --output build-lobby.rbxlx
rojo build places/playarea.project.json --output build-playarea.rbxlx
#    You should see no errors. The .rbxlx files are git-ignored; delete them.
```

**Connecting to Roblox Studio:** open the Place file for whichever leg
you're working on (Hub / Lobby / PlayArea) in Studio, then:

```bash
# 6. Start the Rojo dev server against that place's project file
rojo serve places/playarea.project.json   # or hub / lobby

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
stylua src/                 # CI will reject unformatted code
selene src/                 # CI will reject lint errors
```

### Branch naming convention

```
feature/<short-description>   # new system or mechanic
fix/<short-description>       # bug fix
content/<short-description>   # data/config-only change (no logic)
```

### Pull Request rules

- **One PR = one system change.** Since v2's plugin architecture puts each
  system in its own folder, this is now easy to actually enforce.
- Server-authoritative logic is a **hard blocker** in review, not a
  nitpick. If a PR lets the client decide any gameplay outcome, it will be
  rejected. (See §7.1.)
- Tag your PR with `needs-review` and post in the team chat.

---

## 6. Repository Layout

```
jatinangor-paradox/
├── .github/workflows/ci.yml    # lint + format + build (all 3 places) on every PR
├── docs/
│   └── ARCHITECTURE.md         # full technical design — read this first!
├── places/
│   ├── hub.project.json        # Rojo mapping for the Hub place
│   ├── lobby.project.json      # Rojo mapping for the Lobby place
│   └── playarea.project.json   # Rojo mapping for the PlayArea place
├── rokit.toml / wally.toml / wally.lock / selene.toml / stylua.toml
├── Packages/                   # auto-generated by `wally install`; git-ignored
└── src/
    ├── Shared/                 # ReplicatedStorage in every place — required by both sides
    │   ├── Constants/          # RoleConstants, RemoteNames, SessionConstants
    │   ├── Content/            # RoleDefinitions.lua (role display + skill mapping, DATA)
    │   ├── Types/               # shared Luau type defs, incl. content-plugin contracts
    │   ├── Net/                 # the ONLY module allowed to touch RemoteEvents
    │   ├── Platform/            # cross-platform input/UI-scale detection
    │   ├── Registry/            # PluginRegistry (Systems) + ContentRegistry (content plugins)
    │   ├── Session/             # SessionAdmission — race-safe MemoryStore admission control
    │   └── Util/                # Log, Maid, Signal
    │
    ├── Hub/
    │   ├── Server/Systems/       # MatchmakingSystem, SessionAdmissionSystem
    │   └── Client/Controllers/   # HubUIController (Create/Join/Start)
    │
    ├── Lobby/
    │   ├── Server/Systems/       # FamilyRosterSystem, RoleBalancingSystem, ReadyCheckSystem
    │   └── Client/Controllers/   # LobbyController (role/ready UI)
    │
    └── PlayArea/
        ├── Server/
        │   ├── Systems/           # DataSystem, FamilySystem, RoleSystem, SkillSystem,
        │   │                      # PlayerStatsSystem, InventorySystem, ItemSystem,
        │   │                      # DoorLockSystem, DialogSystem, EntityAISystem,
        │   │                      # MinigameSystem, JournalSystem, GameSystem
        │   │                      # (each Systems/<Name>/ may contain its own content
        │   │                      #  plugin subfolder, e.g. ItemSystem/Items/*)
        │   └── Content/           # MechanismDefinitions.lua (data-driven puzzle groups)
        └── Client/Controllers/    # one Controller per System, same names
```

See [`docs/ARCHITECTURE.md` §4](docs/ARCHITECTURE.md#4-component-structure)
for the full component diagrams per place.

---

## 7. Architecture in Plain English

### 7.1 The Golden Rule: Server-Authoritative

> **The client never decides who has a role, whether a mechanism/item/
> skill/minigame attempt succeeded, or when the session ends. It only
> *requests* and *renders*.**

Treat every value the client sends as potentially forged. Every
gameplay-affecting decision is **re-validated on the server** — see
[`docs/ARCHITECTURE.md` §6.4](docs/ARCHITECTURE.md#64-item--mechanism--minigame--dialog-interaction-shared-shape)
for the exact shape every interaction follows.

### 7.2 Loose coupling: "add a folder," not "edit a shared file"

v1 had a hand-written registry table in `init.server.lua` that every
programmer edited to register their own system — a merge-conflict
bottleneck. v2 replaces it with **`PluginRegistry.DiscoverAndBoot`**:
every place's bootstrap scans a `Systems/` (or `Controllers/`) folder,
`require`s every module found there, and boots each one through the same
two-phase `Init`/`Start` pattern as before — automatically, in dependency
order. Adding a system is dropping a folder in; nobody edits a shared
bootstrap file. Content (a specific item/skill/minigame/AI entity/dialog
tree) works the same way one level down via **`ContentRegistry.Load`**.
Full rationale and the exact contracts: **[`docs/ARCHITECTURE.md`
§3](docs/ARCHITECTURE.md#3-loose-coupling-pluginregistry-and-contentregistry)**.

### 7.3 Three places, one family, one `familyId`

A player's journey is Hub (public, pick/create a family via invite code) →
Lobby (reserved server, role-balance + ready check) → PlayArea (a fresh
reserved server, the actual game). Each place-to-place hop mints its own
`TeleportService:ReserveServer` reservation — access codes are scoped to
one specific place, they don't carry over — but `familyId` (an app-level
id, carried in `TeleportData`) threads the whole journey together. Full
sequence diagrams: **[`docs/ARCHITECTURE.md`
§6](docs/ARCHITECTURE.md#6-data-flow-walkthroughs)**.

### 7.4 The Net Module

`Shared/Net/Net.lua` is the **only** module allowed to create or touch
`RemoteEvent` instances — unchanged from v1. Gives every remote
known-remote assertion, per-player rate limiting, and one place to add
logging. Remote names are declared once in `Constants/RemoteNames.lua`;
never hardcode one elsewhere. Full catalogue of every remote in this game:
**[`docs/ARCHITECTURE.md` §7](docs/ARCHITECTURE.md#7-api-design-remote-catalogue)**.

---

## 8. Adding Content (No-Code / One-File Paths)

See **[`docs/ARCHITECTURE.md` §5](docs/ARCHITECTURE.md#5-adding-content--the-concrete-drop-a-folder-recipe)**
for the full table. Quick version:

| Want to add... | Do this |
|---|---|
| A **mechanism/door/lock instance** | Tag `Mechanism` in Studio + Attributes `MechanismId`, `PuzzleGroupId`, optional `RequiredRole`. No code. |
| A **world item instance** | Tag `WorldItem` in Studio + Attributes `WorldItemId`, `ItemType`, optional `RequiredRole`. No code. |
| A new **item type** | One file: `PlayArea/Server/Systems/ItemSystem/Items/<Name>/init.lua`. |
| A new **skill** | One file under `SkillSystem/Skills/<Name>/init.lua` + one line in `Shared/Content/RoleDefinitions.lua`. |
| A new **minigame** | One file under `MinigameSystem/Minigames/<Name>/init.lua`. |
| A new **AI entity** | One file under `EntityAISystem/Entities/<Name>/init.lua`. |
| A new **dialog tree** | One file under `DialogSystem/Dialogs/<Name>/init.lua`. |

If required Attributes are missing, the relevant System logs a `[WARN]`
and skips the instance instead of erroring — check Output if content
doesn't respond.

---

## 9. Coding Standards

### Luau strict typing

Every module **must** start with `--!strict`. Non-negotiable with several
people touching the same files.

### Naming conventions

| Thing | Convention | Example |
|---|---|---|
| ModuleScript / System / Controller | PascalCase | `RoleSystem`, `UIController` |
| Local variable / function | camelCase | `playerRoles`, `assignRole` |
| True constant | SCREAMING_SNAKE_CASE | `MAX_INTERACT_DISTANCE`, `PROFILE_STORE_NAME` |
| Remote name | `Domain_Action` | `Skill_Activate`, `Mechanism_Interact` |
| **Intentionally unused variable** | `_` prefix | `_role`, `_player` |

### GameSystem module template

```lua
--!strict
-- MyNewSystem
--
-- One-line summary of what this System owns.
-- Cross-reference docs/ARCHITECTURE.md §X if relevant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("MyNewSystem")

local MyNewSystem = { Name = "MyNewSystem", Dependencies = {} } -- list other Systems' .Name here if you need them in Init

function MyNewSystem.Init(registry: { [string]: any })
    -- store references from `registry`, no cross-system calls yet
end

function MyNewSystem.Start()
    -- connect events, register Net listeners
end

return MyNewSystem
```

Drop this in `Systems/MyNewSystem/init.lua` under any place's `Server/` —
`PluginRegistry.DiscoverAndBoot` picks it up automatically, no other file
touched.

### Content-plugin module template

```lua
--!strict
-- MyNewItem — one-line summary.

local MyNewItem = {
    Id = "MyNewItem",
    DisplayName = "My New Item",
}

function MyNewItem.OnInteract(player: Player, instance: Instance, context: { [string]: any }): boolean
    -- return true if the interaction was accepted
    return true
end

return MyNewItem
```

### Logging

```lua
local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("SystemName")

log:Info("Something happened")
log:Warn("Something suspicious")
log:Error("Something broke")
```

### Error handling for DataStore/MemoryStore calls

Wrap **all** `DataSystem`/`ProfileService`/`SessionAdmission` calls in
`pcall`. A DataStore or MemoryStore error must never crash a System — a
family losing progress mid-event is a reputational risk for a large
orientation program.

---

## 10. CI Pipeline

Every pull request and push to `main` triggers `.github/workflows/ci.yml`.
All checks must pass before merging.

| Step | Command | What fails it |
|---|---|---|
| Formatting | `stylua --check src/` | Any file not formatted to `stylua.toml` rules |
| Linting | `selene src/ --allow-warnings` | Lint errors in `selene.toml` |
| Build (Hub) | `rojo build places/hub.project.json` | Rojo cannot compile the Hub place |
| Build (Lobby) | `rojo build places/lobby.project.json` | Rojo cannot compile the Lobby place |
| Build (PlayArea) | `rojo build places/playarea.project.json` | Rojo cannot compile the PlayArea place |

> **Don't wait for CI** — run `stylua src/` and `selene src/` locally
> before pushing.

---

## 11. Team & Responsibilities

| Role | Responsibility |
|---|---|
| **Tech Lead** | Architecture ownership, code review, Net/Registry/Session layers, unblocking scripters |
| **System owners** | One `Systems/<Name>/` folder each (server), matching `Controllers/<Name>` (client) |
| **Content contributors** | One content-plugin folder each (`Items/`, `Skills/`, `Minigames/`, `Entities/`, `Dialogs/`) — no need to touch the owning System's file |
| **Builders / level designers** | Studio tagging (mechanisms, items, journal fragments, AI entities) per §8 — no Lua required |

### Review rule (non-negotiable)

> Server-authoritative logic (§7.1) is a **hard blocker** in review.
> If a PR allows the client to decide any gameplay outcome, it is
> rejected, not merged with a comment.

---

## 12. FAQ for Programmers

**Q: Where do I write my code?**
A: In VS Code, under `src/`. Never edit scripts directly in Roblox
Studio — Rojo overwrites Studio edits on the next sync.

**Q: How do I call another System from my System?**
A: Through the `registry` table injected in your `Init` function — same
pattern as v1, now populated automatically by `PluginRegistry`:

```lua
function MySystem.Init(registry: { [string]: any })
    local RoleSystem = registry.RoleSystem
end
```

Never `require` another System's file directly.

**Q: I wrote a new item/skill/minigame — do I need to register it anywhere?**
A: No. Drop the file in the right `Items/` / `Skills/` / `Minigames/` /
`Entities/` / `Dialogs/` folder and it's picked up on next boot. If it
doesn't show up, check Output for a `ContentRegistry` warning (usually a
missing/duplicate `.Id`).

**Q: How do I add a new RemoteEvent?**
1. Add the name to `Shared/Constants/RemoteNames.lua`.
2. Use `Net.FireServer`/`Net.OnServerEvent`/`Net.FireClient`/
   `Net.OnClientEvent` — `Net` creates the actual `RemoteEvent` instance
   automatically.

**Q: Which place am I working in?**
A: If it's title-screen/matchmaking, Hub. If it's role selection/ready-up,
Lobby. Everything else (items, minigames, dialog, mechanisms, the actual
map) is PlayArea.

**Q: My mechanism/item doesn't respond. What do I check?**
1. Is it tagged correctly (`Mechanism` or `WorldItem`) in CollectionService?
2. Does it have the required Attributes (§8)?
3. Check Output for a `[WARN] ... missing required Attributes` line.
4. Is the player's role correct, if `RequiredRole` is set?

**Q: Can I use `FireAllClients`?**
A: No. Always scope broadcasts to `FamilySystem.GetFamilyPlayers()` and
use `Net.FireClients(familyPlayers, ...)`.

**Q: What's a Maid? Do I need it?**
A: Collects `RBXScriptConnection`s and cleans them all up in one call. Use
it in any System that connects to `PlayerAdded`/`PlayerRemoving`/Signals
outside a per-player scope, to avoid leaks.

---

*For the full data-flow diagrams, session-admission race-condition
analysis, and the complete Remote catalogue, see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).*
