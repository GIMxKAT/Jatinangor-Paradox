--!strict
-- DimensionService
--
-- Owns which dimension (Normal/Alter) each player is in. The actual
-- visual/positional implementation (duplicate map layers vs. teleport vs.
-- CollectionService-tagged folder toggling) depends on how Bab III's level
-- design ships — the interface below should not need to change regardless
-- of which implementation is chosen, which is the point of isolating it
-- in one Service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local DimensionConstants = require(ReplicatedStorage.Shared.Constants.DimensionConstants)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("DimensionService")

type Dimension = DimensionConstants.Dimension

local DimensionService = {}

local playerDimensions: { [Player]: Dimension } = {}
local PlayerService: any

function DimensionService.Init(registry: { [string]: any })
    PlayerService = registry.Player
end

function DimensionService.Start()
    Players.PlayerRemoving:Connect(function(player)
        playerDimensions[player] = nil
    end)

    Net.OnServerEvent(RemoteNames.Dimension_RequestSwitch, function(player)
        DimensionService.RequestSwitch(player)
    end)
end

function DimensionService.SetInitialDimension(player: Player, dimension: Dimension)
    playerDimensions[player] = dimension
end

function DimensionService.GetDimension(player: Player): Dimension?
    return playerDimensions[player]
end

-- Server-side validation lives here: e.g. only allow switching at
-- designated portal points, not mid-puzzle. Replace the `true` below with
-- the actual gate once level design (Bab III) defines where switches are
-- allowed.
function DimensionService.RequestSwitch(player: Player)
    local currentDimension = playerDimensions[player]
    if not currentDimension then
        return
    end

    local isSwitchAllowedHere = true -- TODO: real proximity/zone check
    if not isSwitchAllowedHere then
        return
    end

    local newDimension: Dimension = if currentDimension == "Normal" then "Alter" else "Normal"
    playerDimensions[player] = newDimension

    -- TODO: actual teleport / collision-group / Workspace-layer swap here.

    Net.FireClient(player, RemoteNames.Dimension_Switched, newDimension)

    local familyPlayers = PlayerService.GetFamilyPlayers()
    Net.FireClients(familyPlayers, RemoteNames.Dimension_PlayerMoved, player, newDimension)

    log:Info(("%s switched to dimension %s"):format(player.Name, newDimension))
end

return DimensionService
