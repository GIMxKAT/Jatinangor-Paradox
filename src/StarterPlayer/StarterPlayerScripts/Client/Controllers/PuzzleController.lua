--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local PuzzleController = {}

PuzzleController.MechanismUpdated = Signal.new()

function PuzzleController.Init(_registry: { [string]: any }) end

function PuzzleController.Start()
    Net.OnClientEvent(
        RemoteNames.Puzzle_MechanismUpdated,
        function(mechanismId: string, activated: boolean)
            PuzzleController.MechanismUpdated:Fire(mechanismId, activated)
            -- Trigger local VFX/SFX for the mechanism here.
        end
    )
end

-- Call this from a ProximityPrompt on a tagged "Mechanism" instance.
function PuzzleController.Interact(mechanismId: string)
    Net.FireServer(RemoteNames.Puzzle_Interact, mechanismId)
end

return PuzzleController
