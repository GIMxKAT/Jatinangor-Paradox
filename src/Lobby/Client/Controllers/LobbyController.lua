--!strict
-- LobbyController
--
-- Wires the role-balancing / ready-check UI. Expects a ScreenGui named
-- "LobbyUI" (built in Studio) with a RoleButtons folder containing one
-- GuiButton per role named after RoleConstants.All entries, plus
-- ReadyButton, CountdownLabel, and a RosterList Frame with per-player rows
-- (row instance name = tostring(userId)) showing assigned role + ready
-- state — the exact row-rendering is level/UI-design work, not scripted
-- here; this controller only pushes the data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Platform = require(ReplicatedStorage.Shared.Platform.Platform)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("LobbyController")

local LobbyController = { Name = "LobbyController", Dependencies = {} }

local roleAssignments: { [number]: string } = {}
local readyState: { [number]: boolean } = {}

local function bindUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local lobbyUI = playerGui:WaitForChild("LobbyUI", 10)
    if not lobbyUI then
        log:Warn("LobbyUI ScreenGui not found in PlayerGui after 10s")
        return
    end

    local uiScale = lobbyUI:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
    uiScale.Parent = lobbyUI
    uiScale.Scale = Platform.GetRecommendedUIScale()

    local roleButtons = lobbyUI:FindFirstChild("RoleButtons", true)
    if roleButtons then
        for _, button in roleButtons:GetChildren() do
            if button:IsA("GuiButton") then
                button.Activated:Connect(function()
                    Net.FireServer(RemoteNames.Lobby_RequestRole, button.Name)
                end)
            end
        end
    end

    local readyButton = lobbyUI:FindFirstChild("ReadyButton", true)
    local isReady = false
    if readyButton and readyButton:IsA("GuiButton") then
        readyButton.Activated:Connect(function()
            isReady = not isReady
            Net.FireServer(RemoteNames.Lobby_SetReady, isReady)
        end)
    end

    local countdownLabel = lobbyUI:FindFirstChild("CountdownLabel", true)

    Net.OnClientEvent(RemoteNames.Lobby_RoleAssignmentsUpdated, function(data)
        if typeof(data) == "table" then
            roleAssignments = data :: any
        end
    end)

    Net.OnClientEvent(RemoteNames.Lobby_ReadyStateUpdated, function(data)
        if typeof(data) == "table" then
            readyState = data :: any
        end
    end)

    Net.OnClientEvent(RemoteNames.Lobby_Countdown, function(secondsLeft)
        if countdownLabel and countdownLabel:IsA("TextLabel") then
            countdownLabel.Text = secondsLeft and ("Starting in " .. tostring(secondsLeft) .. "...")
                or ""
        end
    end)
end

function LobbyController.GetRoleAssignments(): { [number]: string }
    return roleAssignments
end

function LobbyController.GetReadyState(): { [number]: boolean }
    return readyState
end

function LobbyController.Start()
    bindUI()
end

return LobbyController
