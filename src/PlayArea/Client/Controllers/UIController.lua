--!strict
-- UIController
--
-- Owns references to the ScreenGuis built in Studio (StarterGui) and wires
-- them to the other Controllers' Signals, plus applies the cross-platform
-- UIScale from Shared/Platform/Platform.lua. Keeping ALL Instance-finding
-- for UI in one Controller means the UI hierarchy can be restructured by a
-- designer without hunting through every gameplay Controller for
-- `WaitForChild` calls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Platform = require(ReplicatedStorage.Shared.Platform.Platform)

local UIController = { Name = "UIController", Dependencies = {} }

local registry: { [string]: any }

function UIController.Init(controllerRegistry: { [string]: any })
    registry = controllerRegistry
end

function UIController.Start()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    for _, screenGui in playerGui:GetChildren() do
        if screenGui:IsA("ScreenGui") then
            local uiScale = screenGui:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
            uiScale.Parent = screenGui
            uiScale.Scale = Platform.GetRecommendedUIScale()
        end
    end
    Platform.ObserveScheme(function(_scheme)
        -- e.g. swap interaction-hint icons between touch/gamepad/keyboard here
    end)

    registry.RoleController.RoleAssigned:Connect(function(_role: string)
        -- e.g. playerGui.HUD.RoleLabel.Text = role
    end)

    registry.PlayerStatsController.StatsUpdated:Connect(function(_userId: number, _health: number)
        -- e.g. update that family member's stats bar
    end)

    registry.InventoryController.InventoryUpdated:Connect(function(_inventory: { [string]: number })
        -- e.g. refresh the shared inventory panel
    end)

    registry.JournalController.FragmentUpdated:Connect(
        function(_fragmentId: string, _collected: boolean)
            -- e.g. update shared journal UI panel entry for fragmentId
        end
    )

    Net.OnClientEvent(RemoteNames.Game_StateChanged, function(_status: string)
        -- e.g. show the "Portal Stabilized!" win screen when status == "Won"
    end)
end

return UIController
