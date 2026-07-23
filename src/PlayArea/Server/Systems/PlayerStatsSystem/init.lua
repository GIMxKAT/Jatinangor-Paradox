--!strict
-- PlayerStatsSystem (PlayArea)
--
-- ADAPTER NOTE: this is a reference implementation standing in for the
-- health/stats system already being built independently by another
-- programmer on the team. The point of this file is the SHAPE, not the
-- content — it conforms to the GameSystem contract (Name/Dependencies/
-- Init/Start) and exposes a small, stable public API (GetStats, Damage,
-- Restore, IsDowned). When the real implementation is ready, replace this
-- file's body but keep the same public function names/signatures and
-- nothing else in the codebase needs to change — that's the entire point
-- of routing every cross-system call through the PluginRegistry-injected
-- registry instead of direct requires (see Shared/Registry/PluginRegistry.lua).
-- If the real system's public API differs, update the two call sites that
-- currently depend on it (SupportTeamAssist skill, this file's own remote
-- handlers) rather than reshaping this contract to match — small, visible
-- call-site edits beat a contract that silently drifts.
--
-- Design choice worth confirming with the actual owner: this models stats
-- as FAMILY-shared state (one pool of "family health"), matching the
-- project's existing rule that collaborative state lives in one place, not
-- duplicated per player (docs/ARCHITECTURE.md §7). If the real system is
-- per-player instead, that's a meaningfully different data model — swap
-- deliberately, don't let it happen as an unnoticed side effect of merging.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("PlayerStatsSystem")

local MAX_HEALTH = 100

local PlayerStatsSystem = { Name = "PlayerStatsSystem", Dependencies = { "FamilySystem" } }

-- Fired (player, newHealth) whenever health changes, for anything that
-- needs to react (e.g. GameSystem could subscribe to gate progress on a
-- "family incapacitated" fail state, if the design ever wants one).
PlayerStatsSystem.HealthChanged = Signal.new()

local FamilySystem: any
local health: { [Player]: number } = {}

local function broadcast(player: Player)
    Net.FireClients(
        FamilySystem.GetFamilyPlayers(),
        RemoteNames.Stats_Updated,
        player.UserId,
        health[player]
    )
end

function PlayerStatsSystem.GetHealth(player: Player): number
    return health[player] or MAX_HEALTH
end

function PlayerStatsSystem.IsDowned(player: Player): boolean
    return PlayerStatsSystem.GetHealth(player) <= 0
end

function PlayerStatsSystem.Damage(player: Player, amount: number)
    if amount <= 0 then
        return
    end
    local current = PlayerStatsSystem.GetHealth(player)
    health[player] = math.max(current - amount, 0)
    PlayerStatsSystem.HealthChanged:Fire(player, health[player])
    broadcast(player)
end

function PlayerStatsSystem.Restore(player: Player, amount: number)
    if amount <= 0 then
        return
    end
    local current = PlayerStatsSystem.GetHealth(player)
    health[player] = math.min(current + amount, MAX_HEALTH)
    PlayerStatsSystem.HealthChanged:Fire(player, health[player])
    broadcast(player)
end

function PlayerStatsSystem.Init(registry: { [string]: any })
    FamilySystem = registry.FamilySystem
end

function PlayerStatsSystem.Start()
    Players.PlayerAdded:Connect(function(player)
        health[player] = MAX_HEALTH
        broadcast(player)
    end)
    for _, player in Players:GetPlayers() do
        health[player] = MAX_HEALTH
    end

    Players.PlayerRemoving:Connect(function(player)
        health[player] = nil
    end)

    log:Info(
        "PlayerStatsSystem started (reference implementation — see ADAPTER NOTE at top of file)"
    )
end

return PlayerStatsSystem
