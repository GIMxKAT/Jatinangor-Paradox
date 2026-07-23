--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DialogController = { Name = "DialogController", Dependencies = {} }

DialogController.NodeUpdated = Signal.new() -- (node: DialogNode)
DialogController.Ended = Signal.new()

function DialogController.Start()
    Net.OnClientEvent(RemoteNames.Dialog_NodeUpdated, function(node)
        DialogController.NodeUpdated:Fire(node)
    end)
    Net.OnClientEvent(RemoteNames.Dialog_End, function()
        DialogController.Ended:Fire()
    end)
end

-- Call from a ProximityPrompt on a tagged NPC (DialogTreeId Attribute).
function DialogController.StartDialog(treeId: string)
    Net.FireServer(RemoteNames.Dialog_Start, treeId)
end

function DialogController.ChooseOption(optionIndex: number)
    Net.FireServer(RemoteNames.Dialog_Advance, optionIndex)
end

return DialogController
