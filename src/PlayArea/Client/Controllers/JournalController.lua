--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local JournalController = { Name = "JournalController", Dependencies = {} }

JournalController.FragmentUpdated = Signal.new()

function JournalController.Start()
    Net.OnClientEvent(
        RemoteNames.Journal_FragmentUpdated,
        function(fragmentId: string, collected: boolean)
            JournalController.FragmentUpdated:Fire(fragmentId, collected)
        end
    )
end

-- Call from a ProximityPrompt on a tagged "JournalFragment" instance.
function JournalController.Collect(fragmentId: string)
    Net.FireServer(RemoteNames.Journal_Collect, fragmentId)
end

return JournalController
