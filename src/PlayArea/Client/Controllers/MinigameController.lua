--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local MinigameController = { Name = "MinigameController", Dependencies = {} }

MinigameController.StateUpdated = Signal.new() -- (minigameId, publicState) — GetPublicState output only, never secrets
MinigameController.Ended = Signal.new() -- (minigameId, solvedByOrUserId)

function MinigameController.Start()
    Net.OnClientEvent(
        RemoteNames.Minigame_StateUpdated,
        function(minigameId: string, publicState: { [string]: any })
            MinigameController.StateUpdated:Fire(minigameId, publicState)
        end
    )

    Net.OnClientEvent(RemoteNames.Minigame_End, function(minigameId: string, solvedByOrUserId: any)
        MinigameController.Ended:Fire(minigameId, solvedByOrUserId)
    end)
end

-- Call from a ProximityPrompt on whatever world instance starts this
-- minigame (e.g. a keypad Model tagged for the "PinCode" minigame).
function MinigameController.StartMinigame(minigameId: string)
    Net.FireServer(RemoteNames.Minigame_Start, minigameId)
end

function MinigameController.SubmitAttempt(attempt: any)
    Net.FireServer(RemoteNames.Minigame_SubmitAttempt, attempt)
end

return MinigameController
