--!strict
-- PlayerStatsController — mirrors PlayerStatsSystem's ADAPTER NOTE: this is
-- a thin relay (Net event -> Signal), so it should need no changes at all
-- when the real health/stats implementation replaces the server-side
-- reference version, as long as the Stats_Updated payload shape is kept.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local PlayerStatsController = { Name = "PlayerStatsController", Dependencies = {} }

PlayerStatsController.StatsUpdated = Signal.new() -- (userId, health)

function PlayerStatsController.Start()
    Net.OnClientEvent(RemoteNames.Stats_Updated, function(userId: number, health: number)
        PlayerStatsController.StatsUpdated:Fire(userId, health)
    end)
end

return PlayerStatsController
