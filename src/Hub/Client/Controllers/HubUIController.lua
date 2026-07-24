--!strict
-- HubUIController
--
-- Wires the "Jatinangor Paradox" family-registration screen (Create Family /
-- Join Family, per the prerequisite diagram) to MatchmakingSystem on the
-- server. Expects a ScreenGui named "HubGui" built in Studio (StarterGui is
-- not Rojo-synced -- see docs/ARCHITECTURE.md §3) with descendants named
-- CreateFamilyButton, JoinFamilyButton, JoinCodeInput, StartFamilyButton,
-- InviteCodeLabel, RosterList, QueueToast, QueueStatusLabel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Platform = require(ReplicatedStorage.Shared.Platform.Platform)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("HubUIController")

local HubUIController = { Name = "HubUIController", Dependencies = {} }

local function setRoster(rosterList: Instance, memberNames: { string })
    for _, child in rosterList:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    for i, memberName in memberNames do
        local label = Instance.new("TextLabel")
        label.Name = "Member" .. i
        label.LayoutOrder = i
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Font = Enum.Font.RobotoMono
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(235, 235, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "- " .. memberName
        label.Parent = rosterList
    end
end

local function bindUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    local hubUI = playerGui:WaitForChild("HubGui", 10)
    if not hubUI then
        log:Warn(
            "HubGui ScreenGui not found in PlayerGui after 10s -- family screen will not function"
        )
        return
    end

    local uiScale = hubUI:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
    uiScale.Parent = hubUI
    uiScale.Scale = Platform.GetRecommendedUIScale()

    local createButton = hubUI:FindFirstChild("CreateFamilyButton", true)
    local joinButton = hubUI:FindFirstChild("JoinFamilyButton", true)
    local joinCodeInput = hubUI:FindFirstChild("JoinCodeInput", true)
    local startButton = hubUI:FindFirstChild("StartFamilyButton", true)
    local inviteCodeLabel = hubUI:FindFirstChild("InviteCodeLabel", true)
    local rosterList = hubUI:FindFirstChild("RosterList", true)
    local queueToast = hubUI:FindFirstChild("QueueToast", true)
    local queueStatusLabel = hubUI:FindFirstChild("QueueStatusLabel", true)

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
        if typeof(data) ~= "table" then
            return
        end
        local payload = data :: any

        if inviteCodeLabel and inviteCodeLabel:IsA("TextLabel") then
            local inviteCode = payload.inviteCode or ""
            inviteCodeLabel.Text = ("CODE: %s"):format(inviteCode)
            inviteCodeLabel.Visible = inviteCode ~= ""
        end

        if rosterList then
            setRoster(rosterList, payload.memberNames or {})
        end

        if startButton and startButton:IsA("GuiButton") then
            local leaderUserId = payload.leaderUserId
            startButton.Visible = leaderUserId ~= nil and leaderUserId == player.UserId
        end
    end)

    Net.OnClientEvent(RemoteNames.Hub_QueueStatus, function(data)
        if typeof(data) ~= "table" then
            return
        end
        local state = (data :: any).state
        local text = ""
        if state == "WaitingForSlot" then
            text = "WAITING FOR SLOT..."
        elseif state == "InvalidCode" then
            text = "INVITE CODE NOT FOUND"
        elseif state == "TeleportFailed" then
            text = "COULDN'T START -- TRY AGAIN"
        end

        if queueStatusLabel and queueStatusLabel:IsA("TextLabel") then
            queueStatusLabel.Text = text
        end
        if queueToast and queueToast:IsA("GuiObject") then
            queueToast.Visible = text ~= ""
        end
    end)
end

function HubUIController.Start()
    bindUI()
end

return HubUIController
