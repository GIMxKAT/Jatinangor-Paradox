--!strict
-- LobbyController
--
-- Wires the role-balancing / ready-check UI. Expects a ScreenGui named
-- "LobbyUI" (built in Studio) with a RoleButtons container holding one
-- GuiButton per role named after RoleConstants.All entries, plus
-- ReadyButton, CountdownLabel, and a RosterList Frame that this controller
-- populates itself with one row per current family member (all Players on
-- this server ARE the family, since Lobby only ever runs as a reserved
-- server for one family — see FamilyRosterSystem).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Platform = require(ReplicatedStorage.Shared.Platform.Platform)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("LobbyController")

local LobbyController = { Name = "LobbyController", Dependencies = {} }

local ROLE_ABBREVIATION: { [string]: string } = {
    Navigator = "NAV",
    Detective = "DET",
    Scout = "SCT",
    CodeBreaker = "CODE",
    Support = "SUP",
}

local ROLE_BUTTON_DEFAULT_COLOR = Color3.fromRGB(40, 43, 54)
local ROLE_BUTTON_SELECTED_COLOR = Color3.fromRGB(214, 158, 46)
local ROLE_BUTTON_DEFAULT_TEXT_COLOR = Color3.fromRGB(220, 220, 225)
local ROLE_BUTTON_SELECTED_TEXT_COLOR = Color3.fromRGB(20, 20, 24)

-- Keyed by tostring(UserId), not UserId itself -- see
-- ReadyCheckSystem.broadcastReadyState (Lobby server) for why numeric
-- dictionary keys don't reliably survive a RemoteEvent round-trip.
local roleAssignments: { [string]: string } = {}
local readyState: { [string]: boolean } = {}
local rosterList: Instance? = nil

local function highlightSelectedRole(roleButtons: Instance, localPlayer: Player)
    local myRole = roleAssignments[tostring(localPlayer.UserId)]
    for _, button in roleButtons:GetChildren() do
        if button:IsA("TextButton") then
            local isSelected = button.Name == myRole
            button.BackgroundColor3 = isSelected and ROLE_BUTTON_SELECTED_COLOR
                or ROLE_BUTTON_DEFAULT_COLOR
            button.TextColor3 = isSelected and ROLE_BUTTON_SELECTED_TEXT_COLOR
                or ROLE_BUTTON_DEFAULT_TEXT_COLOR
        end
    end
end

local function renderRoster()
    if not rosterList then
        return
    end

    local seenRowNames: { [string]: boolean } = {}
    for _, plr in Players:GetPlayers() do
        local rowName = tostring(plr.UserId)
        seenRowNames[rowName] = true

        local row = rosterList:FindFirstChild(rowName)
        if not row then
            local newRow = Instance.new("TextLabel")
            newRow.Name = rowName
            newRow.BackgroundTransparency = 1
            newRow.Size = UDim2.new(1, 0, 0, 20)
            newRow.Font = Enum.Font.RobotoMono
            newRow.TextSize = 13
            newRow.TextXAlignment = Enum.TextXAlignment.Left
            newRow.Parent = rosterList
            row = newRow
        end

        local role = roleAssignments[tostring(plr.UserId)]
        local isReady = readyState[tostring(plr.UserId)] == true
        local roleText = (role and ROLE_ABBREVIATION[role]) or "--"
        local readyMark = isReady and "✓" or "○"

        local label = row :: TextLabel
        label.Text = ("%s  %s  [%s]"):format(readyMark, plr.Name, roleText)
        label.TextColor3 = if isReady
            then Color3.fromRGB(96, 176, 168)
            else Color3.fromRGB(210, 200, 190)
    end

    for _, child in rosterList:GetChildren() do
        if child:IsA("TextLabel") and not seenRowNames[child.Name] then
            child:Destroy()
        end
    end
end

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
    if readyButton and readyButton:IsA("TextButton") then
        readyButton.Activated:Connect(function()
            isReady = not isReady
            Net.FireServer(RemoteNames.Lobby_SetReady, isReady)
            readyButton.Text = isReady and "READY (TAP TO CANCEL)" or "READY UP"
            readyButton.BackgroundColor3 = isReady and Color3.fromRGB(96, 176, 168)
                or Color3.fromRGB(214, 158, 46)
        end)
    end

    local countdownLabel = lobbyUI:FindFirstChild("CountdownLabel", true)

    rosterList = lobbyUI:FindFirstChild("RosterList", true)
    Players.PlayerAdded:Connect(renderRoster)
    Players.PlayerRemoving:Connect(renderRoster)
    renderRoster()

    Net.OnClientEvent(RemoteNames.Lobby_RoleAssignmentsUpdated, function(data)
        if typeof(data) == "table" then
            roleAssignments = data :: any
            renderRoster()
            if roleButtons then
                highlightSelectedRole(roleButtons, player)
            end
        end
    end)

    Net.OnClientEvent(RemoteNames.Lobby_ReadyStateUpdated, function(data)
        if typeof(data) == "table" then
            readyState = data :: any
            renderRoster()
        end
    end)

    Net.OnClientEvent(RemoteNames.Lobby_Countdown, function(secondsLeft)
        if countdownLabel and countdownLabel:IsA("TextLabel") then
            countdownLabel.Text = secondsLeft and ("Starting in " .. tostring(secondsLeft) .. "...")
                or ""
        end
    end)
end

function LobbyController.GetRoleAssignments(): { [string]: string }
    return roleAssignments
end

function LobbyController.GetReadyState(): { [string]: boolean }
    return readyState
end

function LobbyController.Start()
    bindUI()
end

return LobbyController
