--!strict
-- DataService
--
-- Wraps ProfileService (via Wally) instead of hand-rolled DataStore code.
-- Session-locking prevents duplication/rollback bugs if a player somehow
-- ends up in two servers at once. Do NOT replace this with raw
-- DataStoreService calls "for simplicity" — that's how production data
-- loss bugs happen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("DataService")

-- Installed via Wally: `ProfileService = "alreadypro/profileservice@1.0.4"`
-- Synced in by Rojo from the Packages/ folder wally install creates —
-- see default.project.json's ReplicatedStorage.Packages mapping.
local ProfileService = require(ReplicatedStorage.Packages.ProfileService)

local PROFILE_STORE_NAME = "PlayerData_v1"

type ProfileTemplate = {
    role: string?,
    dimension: string,
    familyId: string,
    joinedAt: number,
}

local PROFILE_TEMPLATE: ProfileTemplate = {
    role = nil,
    dimension = "Normal",
    familyId = "",
    joinedAt = 0,
}

local ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, PROFILE_TEMPLATE)

local DataService = {}

local activeProfiles: { [Player]: any } = {}

function DataService.Init(_registry: { [string]: any })
    Players.PlayerRemoving:Connect(function(player)
        local profile = activeProfiles[player]
        if profile then
            profile:Release()
        end
    end)
end

function DataService.Start()
    Players.PlayerAdded:Connect(function(player)
        DataService.LoadProfile(player)
    end)

    -- Handle players who joined before this Service started (rare, but
    -- possible depending on script execution order).
    for _, player in Players:GetPlayers() do
        task.spawn(DataService.LoadProfile, player)
    end
end

function DataService.LoadProfile(player: Player)
    local profile = ProfileStore:LoadProfileAsync(("Player_%d"):format(player.UserId))

    if not profile then
        -- Could not load (e.g. another server has the session locked and
        -- didn't release it in time). Kick rather than let the player play
        -- with unsaved / desynced state.
        log:Error(("Failed to load profile for %s — kicking"):format(player.Name))
        player:Kick("Could not load your data. Please rejoin.")
        return
    end

    profile:AddUserId(player.UserId)
    profile:Reconcile() -- fills in any new template fields for existing profiles
    profile:ListenToRelease(function()
        activeProfiles[player] = nil
        player:Kick("Your session was released. Please rejoin.")
    end)

    if not player:IsDescendantOf(Players) then
        -- Player left before load finished.
        profile:Release()
        return
    end

    activeProfiles[player] = profile
    log:Info(("Profile loaded for %s"):format(player.Name))
end

function DataService.GetProfile(player: Player)
    return activeProfiles[player]
end

function DataService.SaveAll()
    for _player, profile in activeProfiles do
        profile:Release()
    end
end

return DataService
