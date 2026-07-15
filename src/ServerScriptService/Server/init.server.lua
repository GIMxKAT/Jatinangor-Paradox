--!strict
-- Bootstraps all server Services in a controlled order.
--
-- Order matters: DataService must exist before anything tries to read/write
-- a profile; RoleService/DimensionService before PuzzleService (which
-- depends on both to validate interactions).

local Log = require(game.ReplicatedStorage.Shared.Util.Log)
local Net = require(game.ReplicatedStorage.Shared.Net.Net)
local log = Log.new("Bootstrap")

-- Pre-create every declared RemoteEvent before any service or LocalScript
-- runs. This eliminates the race condition where a client calls
-- Net.OnClientEvent before the server has lazily created the remote.
Net.InitRemotes()
log:Info("All RemoteEvents initialized")

local Services = script.Services

local DataService = require(Services.DataService)
local PlayerService = require(Services.PlayerService)
local RoleService = require(Services.RoleService)
local DimensionService = require(Services.DimensionService)
local PuzzleService = require(Services.PuzzleService)
local JournalService = require(Services.JournalService)
local GameService = require(Services.GameService)

-- Central registry so Services can reference each other without brittle
-- relative `require` paths scattered through the codebase.
local ServiceRegistry = {
    Data = DataService,
    Player = PlayerService,
    Role = RoleService,
    Dimension = DimensionService,
    Puzzle = PuzzleService,
    Journal = JournalService,
    Game = GameService,
}

for name, service in ServiceRegistry do
    if service.Init then
        service.Init(ServiceRegistry)
        log:Info(("%s initialized"):format(name))
    end
end

for name, service in ServiceRegistry do
    if service.Start then
        service.Start()
        log:Info(("%s started"):format(name))
    end
end

game:BindToClose(function()
    log:Info("Server closing — saving all active profiles")
    DataService.SaveAll()
end)

log:Info("All services booted.")
