--!strict
-- HubUIController
--
-- Wires the title screen (Create Server / Join Server, per the prerequisite
-- diagram) to MatchmakingSystem on the server. Expects a ScreenGui named
-- "HubUI" built in Studio (StarterGui is not Rojo-synced — see
-- docs/ARCHITECTURE.md §3) with descendants named CreateButton, JoinButton,
-- JoinCodeInput, StartButton, StatusLabel, RosterLabel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Platform = require(ReplicatedStorage.Shared.Platform.Platform)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("HubUIController")

local HubUIController = { Name = "HubUIController", Dependencies = {} }

local function bindUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local hubUI = playerGui:WaitForChild("HubUI", 10)
    if not hubUI then
        log:Warn(
            "HubUI ScreenGui not found in PlayerGui after 10s — title screen will not function"
        )
        return
    end

    local uiScale = hubUI:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
    uiScale.Parent = hubUI
    uiScale.Scale = Platform.GetRecommendedUIScale()

    local createButton = hubUI:FindFirstChild("CreateButton", true)
    local joinButton = hubUI:FindFirstChild("JoinButton", true)
    local joinCodeInput = hubUI:FindFirstChild("JoinCodeInput", true)
    local startButton = hubUI:FindFirstChild("StartButton", true)
    local statusLabel = hubUI:FindFirstChild("StatusLabel", true)
    local rosterLabel = hubUI:FindFirstChild("RosterLabel", true)

    if createButton and createButton:IsA("GuiButton") then
        createButton.Activated:Connect(function()
            Net.FireServer(RemoteNames.Hub_CreateFamily)
        end)
    end

    if joinButton and joinButton:IsA("GuiButton") then
        joinButton.Activated:Connect(function()
            local code = joinCodeInput and joinCodeInput:IsA("TextBox") and joinCodeInput.Text or ""
            Net.FireServer(RemoteNames.Hub_JoinFamily, code)
        end)
    end

    if startButton and startButton:IsA("GuiButton") then
        startButton.Activated:Connect(function()
            Net.FireServer(RemoteNames.Hub_StartFamily)
        end)
    end

    Net.OnClientEvent(RemoteNames.Hub_FamilyUpdated, function(data)
        if rosterLabel and rosterLabel:IsA("TextLabel") and typeof(data) == "table" then
            local names = (data :: any).memberNames or {}
            rosterLabel.Text = ("Invite code: %s\n%s"):format(
                (data :: any).accessCode or "",
                table.concat(names, ", ")
            )
        end
    end)

    Net.OnClientEvent(RemoteNames.Hub_QueueStatus, function(data)
        if statusLabel and statusLabel:IsA("TextLabel") and typeof(data) == "table" then
            local state = (data :: any).state
            if state == "WaitingForSlot" then
                statusLabel.Text = "Waiting for a session slot to open..."
            elseif state == "InvalidCode" then
                statusLabel.Text = "That invite code wasn't found."
            elseif state == "TeleportFailed" then
                statusLabel.Text = "Couldn't start — please try again."
            else
                statusLabel.Text = ""
            end
        end
    end)
end

function HubUIController.Start()
    bindUI()
end

return HubUIController
