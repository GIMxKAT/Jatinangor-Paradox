--!strict
-- JournalSystem (PlayArea)
--
-- Journal fragments are shared, family-level state (one family's shared
-- "we found this together" progress) — not per-player. Keep it that way;
-- duplicating this per-player is the classic subtle-bug source described
-- in docs/ARCHITECTURE.md §7.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("JournalSystem")

local JOURNAL_FRAGMENT_TAG = "JournalFragment"
local MAX_COLLECT_DISTANCE = 8

local JournalSystem = { Name = "JournalSystem", Dependencies = { "FamilySystem" } }

local fragmentsCollected: { [string]: boolean } = {}
local FamilySystem: any

function JournalSystem.Init(registry: { [string]: any })
    FamilySystem = registry.FamilySystem
end

function JournalSystem.Start()
    Net.OnServerEvent(RemoteNames.Journal_Collect, function(player, fragmentId)
        JournalSystem.HandleCollect(player, fragmentId)
    end, 5)
end

function JournalSystem.HandleCollect(player: Player, fragmentId: unknown)
    if typeof(fragmentId) ~= "string" then
        return
    end
    if fragmentsCollected[fragmentId] then
        return -- already collected by a teammate
    end

    local instance = nil
    for _, tagged in CollectionService:GetTagged(JOURNAL_FRAGMENT_TAG) do
        if tagged:GetAttribute("FragmentId") == fragmentId then
            instance = tagged
            break
        end
    end
    if not instance then
        return
    end

    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local fragmentPart = instance:IsA("BasePart") and instance
        or instance:FindFirstChildWhichIsA("BasePart")
    if not (rootPart and fragmentPart) then
        return
    end

    local distance = (rootPart.Position - fragmentPart.Position).Magnitude
    if distance > MAX_COLLECT_DISTANCE then
        return
    end

    fragmentsCollected[fragmentId] = true
    instance.Parent = nil -- or play a collect FX before removing

    local familyPlayers = FamilySystem.GetFamilyPlayers()
    Net.FireClients(familyPlayers, RemoteNames.Journal_FragmentUpdated, fragmentId, true)

    log:Info(("Fragment %s collected by %s"):format(fragmentId, player.Name))
end

return JournalSystem
