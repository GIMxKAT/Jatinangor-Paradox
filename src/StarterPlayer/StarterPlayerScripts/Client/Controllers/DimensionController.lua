--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DimensionController = {}

DimensionController.DimensionChanged = Signal.new()

local myDimension: string? = nil

function DimensionController.Init(_registry: { [string]: any }) end

function DimensionController.Start()
    Net.OnClientEvent(RemoteNames.Dimension_Switched, function(dimension: string)
        myDimension = dimension
        DimensionController.DimensionChanged:Fire(dimension)
    end)

    Net.OnClientEvent(
        RemoteNames.Dimension_PlayerMoved,
        function(_player: Player, _dimension: string)
            -- Update any "where is my teammate" UI here.
        end
    )
end

-- Call this from a ProximityPrompt / trigger volume Triggered event.
function DimensionController.RequestSwitch()
    Net.FireServer(RemoteNames.Dimension_RequestSwitch)
end

function DimensionController.GetMyDimension(): string?
    return myDimension
end

return DimensionController
