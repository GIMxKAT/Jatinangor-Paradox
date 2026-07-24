--!strict
-- PluginRegistry
--
-- Turns "add a new System" into "add a folder" instead of "edit a shared
-- bootstrap file that every programmer has to touch." This replaces the
-- old pattern (a hand-written ServiceRegistry table listed out in
-- init.server.lua) now that multiple programmers each own an independent
-- system (PlayerStats, Inventory, Items, Minigames, ...) — a shared
-- bootstrap file that everyone edits to register their own system is
-- exactly the kind of file that turns into a merge-conflict bottleneck and
-- a hidden coupling point (it's very easy to accidentally read a
-- teammate's system while "just registering" your own).
--
-- A GameSystem is any ModuleScript — or Folder containing an `init`
-- ModuleScript — placed directly under a Systems/ container, returning a
-- table matching the GameSystem type below. PluginRegistry.DiscoverAndBoot
-- requires every one of them, validates the contract, orders them by their
-- declared Dependencies (topological sort), and boots them in the same
-- two-phase Init/Start pattern documented in docs/ARCHITECTURE.md §3.3.
--
-- Failure isolation: each system's Init/Start call is individually
-- pcall'd. One system's bug must not prevent every other system from
-- booting — during a live 3-day event, "the Inventory system has a bug" is
-- a very different severity than "the entire PlayArea server refuses to
-- start because the Inventory system has a bug."

local Log = require(script.Parent.Parent.Util.Log)
local log = Log.new("PluginRegistry")

export type GameSystem = {
    Name: string,
    Dependencies: { string }?,
    Init: ((registry: { [string]: any }) -> ())?,
    Start: (() -> ())?,
    [string]: any, -- systems may expose their own public API methods/signals
}

local PluginRegistry = {}

local function resolveModule(child: Instance): ModuleScript?
    if child:IsA("ModuleScript") then
        return child
    elseif child:IsA("Folder") then
        local init = child:FindFirstChild("init")
        if init and init:IsA("ModuleScript") then
            return init
        end
    end
    return nil
end

local function loadSystems(container: Instance): { GameSystem }
    local systems: { GameSystem } = {}

    -- GetChildren() order isn't part of the Instance API's contract, so
    -- relying on it directly would make "systems with no relationship boot
    -- in declaration order (stable)" (see topoSort below) a false promise.
    -- Sorting by Name gives loadSystems() itself a deterministic, repeatable
    -- discovery order to hand to topoSort.
    local children = container:GetChildren()
    table.sort(children, function(a, b)
        return a.Name < b.Name
    end)

    for _, child in children do
        local moduleScript = resolveModule(child)
        if moduleScript then
            local ok, result = pcall(require, moduleScript)
            if not ok then
                log:Error(
                    ("Failed to require %s: %s"):format(
                        moduleScript:GetFullName(),
                        tostring(result)
                    )
                )
            elseif typeof(result) ~= "table" or typeof((result :: any).Name) ~= "string" then
                log:Error(
                    ("%s does not return a valid GameSystem (missing string .Name) — skipping"):format(
                        moduleScript:GetFullName()
                    )
                )
            else
                table.insert(systems, result :: GameSystem)
            end
        end
    end

    return systems
end

-- Kahn-style topological sort over declared Dependencies. Systems with no
-- relationship boot in declaration order (stable). A missing dependency or
-- a cycle is WARNED, never a hard failure — a live event cannot go down
-- because one system's Dependencies list had a typo.
local function topoSort(systems: { GameSystem }): { GameSystem }
    local byName: { [string]: GameSystem } = {}
    for _, s in systems do
        if byName[s.Name] then
            log:Error(
                ("Duplicate system name '%s' — the later registration is ignored"):format(s.Name)
            )
        else
            byName[s.Name] = s
        end
    end

    local visited: { [string]: boolean } = {}
    local visiting: { [string]: boolean } = {}
    local ordered: { GameSystem } = {}

    local function visit(system: GameSystem)
        if visited[system.Name] or not byName[system.Name] then
            return
        end
        if visiting[system.Name] then
            log:Error(
                ("Dependency cycle detected at '%s' — ignoring the cyclic edge"):format(
                    system.Name
                )
            )
            return
        end
        visiting[system.Name] = true

        for _, depName in system.Dependencies or {} do
            local dep = byName[depName]
            if not dep then
                log:Warn(
                    ("System '%s' declares dependency '%s' which was not found under this container — boot order may be wrong"):format(
                        system.Name,
                        depName
                    )
                )
            else
                visit(dep)
            end
        end

        visiting[system.Name] = false
        visited[system.Name] = true
        table.insert(ordered, system)
    end

    for _, s in systems do
        visit(s)
    end

    return ordered
end

-- Discovers every system directly under `container`, boots them in two
-- phases (Init then Start), and returns the resulting Name -> system
-- registry for anything that needs direct lookup after boot.
function PluginRegistry.DiscoverAndBoot(
    container: Instance,
    label: string
): { [string]: GameSystem }
    local systems = topoSort(loadSystems(container))

    local registry: { [string]: GameSystem } = {}
    for _, s in systems do
        registry[s.Name] = s
    end

    for _, s in systems do
        if s.Init then
            local ok, err = pcall(s.Init, registry)
            if not ok then
                log:Error(("[%s] %s.Init failed: %s"):format(label, s.Name, tostring(err)))
            end
        end
    end

    for _, s in systems do
        if s.Start then
            local ok, err = pcall(s.Start)
            if not ok then
                log:Error(("[%s] %s.Start failed: %s"):format(label, s.Name, tostring(err)))
            else
                log:Info(("[%s] %s started"):format(label, s.Name))
            end
        end
    end

    return registry
end

return PluginRegistry
