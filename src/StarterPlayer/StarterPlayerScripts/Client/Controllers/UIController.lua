--!strict
-- UIController
--
-- Owns references to the ScreenGuis built in Studio (StarterGui) and wires
-- them to the other Controllers' Signals. Keeping ALL Instance-finding for
-- UI in one Controller means the UI hierarchy can be restructured by a
-- designer without hunting through every gameplay Controller for
-- `WaitForChild` calls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)

local UIController = {}

local registry: { [string]: any }

function UIController.Init(controllerRegistry: { [string]: any })
    registry = controllerRegistry
end

function UIController.Start()
    local _playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    registry.Role.RoleAssigned:Connect(function(_role: string)
        -- e.g. playerGui.HUD.RoleLabel.Text = role
    end)

    registry.Dimension.DimensionChanged:Connect(function(_dimension: string)
        -- e.g. toggle a dimension-tinted screen overlay
    end)

    registry.Journal.FragmentUpdated:Connect(function(_fragmentId: string, _collected: boolean)
        -- e.g. update shared journal UI panel entry for fragmentId
    end)

    Net.OnClientEvent(RemoteNames.Game_StateChanged, function(_status: string)
        -- e.g. show the "Portal Stabilized!" win screen when status == "Won"
    end)
end

return UIController
