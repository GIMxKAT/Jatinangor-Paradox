--!strict
-- MinigameSystem (PlayArea)
--
-- Runs standalone puzzle minigames (PIN code, sliding puzzle, trivia,
-- cryptarithmetic, Tower of Hanoi, ... — the diagram's "Minigame" branch).
-- Each minigame is a content plugin under Minigames/ (loaded via
-- ContentRegistry) implementing Start/SubmitAttempt/GetPublicState (see
-- Shared/Types/Types.lua MinigameDefinition). MinigameSystem keeps the
-- FULL state (including the secret answer) server-side only, and only
-- ever sends the client GetPublicState's output — the server, never the
-- client, decides whether an attempt solved the puzzle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ContentRegistry = require(ReplicatedStorage.Shared.Registry.ContentRegistry)
local Types = require(ReplicatedStorage.Shared.Types.Types)

local log = Log.new("MinigameSystem")

local MinigameSystem = { Name = "MinigameSystem", Dependencies = { "FamilySystem" } }

local minigames: { [string]: Types.MinigameDefinition } = {}
local activeByPlayer: { [Player]: { minigameId: string, state: { [string]: any } } } = {}

local FamilySystem: any
local systemRegistry: { [string]: any } = {}

local function handleStart(player: Player, minigameId: unknown)
    if typeof(minigameId) ~= "string" then
        return
    end
    local definition = minigames[minigameId]
    if not definition then
        return
    end

    local ok, state = pcall(definition.Start, player, { registry = systemRegistry })
    if not ok then
        log:Error(("Minigame '%s' Start errored: %s"):format(minigameId, tostring(state)))
        return
    end

    activeByPlayer[player] = { minigameId = minigameId, state = state }
    Net.FireClient(
        player,
        RemoteNames.Minigame_StateUpdated,
        minigameId,
        definition.GetPublicState(state)
    )
end

local function handleSubmitAttempt(player: Player, attempt: unknown)
    local active = activeByPlayer[player]
    if not active then
        return
    end
    local definition = minigames[active.minigameId]
    if not definition then
        return
    end

    local ok, solved, newState = pcall(definition.SubmitAttempt, player, active.state, attempt)
    if not ok then
        log:Error(
            ("Minigame '%s' SubmitAttempt errored: %s"):format(active.minigameId, tostring(solved))
        )
        return
    end

    active.state = newState
    Net.FireClient(
        player,
        RemoteNames.Minigame_StateUpdated,
        active.minigameId,
        definition.GetPublicState(newState)
    )

    if solved then
        activeByPlayer[player] = nil
        Net.FireClient(player, RemoteNames.Minigame_End, active.minigameId, true)
        -- The family shares progress on everything else (journal,
        -- mechanisms) — a solved minigame is worth the same "someone made
        -- progress" notification to the rest of the family, even though
        -- the attempt itself was single-player.
        Net.FireClients(
            FamilySystem.GetFamilyPlayers(),
            RemoteNames.Minigame_End,
            active.minigameId,
            player.UserId
        )
        log:Info(("%s solved minigame '%s'"):format(player.Name, active.minigameId))
    end
end

function MinigameSystem.Init(registry: { [string]: any })
    FamilySystem = registry.FamilySystem
    systemRegistry = registry
    minigames = ContentRegistry.Load(script.Minigames, "Minigames") :: any
end

function MinigameSystem.Start()
    Players.PlayerRemoving:Connect(function(player)
        activeByPlayer[player] = nil
    end)

    Net.OnServerEvent(RemoteNames.Minigame_Start, handleStart)
    Net.OnServerEvent(
        RemoteNames.Minigame_SubmitAttempt,
        handleSubmitAttempt,
        5 --[[ max 5 attempts/sec/player ]]
    )
end

return MinigameSystem
