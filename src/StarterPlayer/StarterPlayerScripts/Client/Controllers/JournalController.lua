--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local JournalController = {}

JournalController.FragmentUpdated = Signal.new()

function JournalController.Init(_registry: { [string]: any }) end

function JournalController.Start()
    Net.OnClientEvent(
        RemoteNames.Journal_FragmentUpdated,
        function(fragmentId: string, collected: boolean)
            JournalController.FragmentUpdated:Fire(fragmentId, collected)
            -- Update the shared journal UI panel here.
        end
    )
end

function JournalController.Collect(fragmentId: string)
    Net.FireServer(RemoteNames.Journal_Collect, fragmentId)
end

return JournalController
