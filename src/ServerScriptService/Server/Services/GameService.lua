--!strict
-- GameService
--
-- The single place that decides "the game is over." Subscribes to
-- PuzzleService's completion signal rather than polling, and is
-- responsible for locking further interaction once the game is won.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("GameService")

export type SessionStatus = "Lobby" | "InProgress" | "Won"

local GameService = {}

local sessionStatus: SessionStatus = "Lobby"
local startedAt: number = 0

local PuzzleService: any
local PlayerService: any
local _DataService: any -- TODO: use in HandleWin for analytics persistence

function GameService.Init(registry: { [string]: any })
    PuzzleService = registry.Puzzle
    PlayerService = registry.Player
    _DataService = registry.Data
end

function GameService.Start()
    PuzzleService.AllGeneratorsActivated:Connect(function()
        GameService.HandleWin()
    end)

    sessionStatus = "InProgress"
    startedAt = os.clock()
    GameService.BroadcastState()
end

function GameService.GetStatus(): SessionStatus
    return sessionStatus
end

function GameService.HandleWin()
    if sessionStatus == "Won" then
        return -- already won, ignore duplicate signal fires
    end

    sessionStatus = "Won"
    local completionSeconds = os.clock() - startedAt

    log:Info(("Session won in %.1fs"):format(completionSeconds))

    -- TODO: persist completion analytics via DataService here.

    GameService.BroadcastState()
end

function GameService.BroadcastState()
    local familyPlayers = PlayerService.GetFamilyPlayers()
    Net.FireClients(familyPlayers, RemoteNames.Game_StateChanged, sessionStatus)
end

return GameService
