--!strict
-- GameSystem (PlayArea)
--
-- The single place that decides "the game is over." Subscribes to
-- DoorLockSystem's completion signal rather than polling, and is
-- responsible for locking further interaction once the game is won.
--
-- On win, releases this family's Hub admission slot (see
-- Shared/Session/SessionAdmission.lua) — Hub -> Lobby -> PlayArea capacity
-- was held for this family's entire journey, and PlayArea's GameSystem is
-- the natural place to give it back since it's the only System that knows
-- when a session has genuinely ended. Also released best-effort in
-- game:BindToClose (see PlayArea/Server/init.server.lua) in case the
-- session ends by server shutdown rather than a win.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local SessionAdmission = require(ReplicatedStorage.Shared.Session.SessionAdmission)

local log = Log.new("GameSystem")

export type SessionStatus = "Lobby" | "InProgress" | "Won"

local GameSystem =
    { Name = "GameSystem", Dependencies = { "DoorLockSystem", "FamilySystem", "DataSystem" } }

local sessionStatus: SessionStatus = "Lobby"
local startedAt: number = 0

local DoorLockSystem: any
local FamilySystem: any
local _DataSystem: any -- TODO: use for persisting completion analytics (time-to-complete, puzzle groups stalled) — see docs/ARCHITECTURE.md §10

function GameSystem.Init(registry: { [string]: any })
    DoorLockSystem = registry.DoorLockSystem
    FamilySystem = registry.FamilySystem
    _DataSystem = registry.DataSystem
end

function GameSystem.Start()
    DoorLockSystem.AllGeneratorsActivated:Connect(function()
        GameSystem.HandleWin()
    end)

    sessionStatus = "InProgress"
    startedAt = os.clock()
    GameSystem.BroadcastState()
end

function GameSystem.GetStatus(): SessionStatus
    return sessionStatus
end

function GameSystem.HandleWin()
    if sessionStatus == "Won" then
        return -- already won, ignore duplicate signal fires
    end

    sessionStatus = "Won"
    local completionSeconds = os.clock() - startedAt

    log:Info(("Session won in %.1fs"):format(completionSeconds))

    -- TODO: persist completion analytics via DataSystem here.

    SessionAdmission.Release(FamilySystem.GetFamilyId())
    GameSystem.BroadcastState()
end

function GameSystem.BroadcastState()
    local familyPlayers = FamilySystem.GetFamilyPlayers()
    Net.FireClients(familyPlayers, RemoteNames.Game_StateChanged, sessionStatus)
end

return GameSystem
