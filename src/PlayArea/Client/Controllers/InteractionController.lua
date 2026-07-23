--!strict
-- InteractionController
--
-- Covers both DoorLockSystem (mechanisms) and ItemSystem (world items) —
-- both are the same shape from the client's perspective: a ProximityPrompt
-- on a tagged instance that fires a request and waits for a server-pushed
-- state update. Bind ProximityPrompt.Triggered to InteractOnMechanism /
-- InteractOnItem for the relevant tagged instance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local InteractionController = { Name = "InteractionController", Dependencies = {} }

InteractionController.MechanismUpdated = Signal.new() -- (mechanismId, activated)
InteractionController.ItemStateUpdated = Signal.new() -- (worldItemId)

function InteractionController.Start()
    Net.OnClientEvent(
        RemoteNames.Mechanism_Updated,
        function(mechanismId: string, activated: boolean)
            InteractionController.MechanismUpdated:Fire(mechanismId, activated)
            -- Trigger local VFX/SFX for the mechanism here.
        end
    )

    Net.OnClientEvent(RemoteNames.Item_WorldStateUpdated, function(worldItemId: string)
        InteractionController.ItemStateUpdated:Fire(worldItemId)
    end)
end

-- Call from a ProximityPrompt on a tagged "Mechanism" instance.
function InteractionController.InteractOnMechanism(mechanismId: string)
    Net.FireServer(RemoteNames.Mechanism_Interact, mechanismId)
end

-- Call from a ProximityPrompt on a tagged "WorldItem" instance.
function InteractionController.InteractOnItem(worldItemId: string)
    Net.FireServer(RemoteNames.Item_Interact, worldItemId)
end

return InteractionController
