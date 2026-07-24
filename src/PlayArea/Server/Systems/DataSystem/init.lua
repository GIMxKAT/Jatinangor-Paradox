--!strict
-- DataSystem (PlayArea)
--
-- Wraps ProfileService (via Wally) instead of hand-rolled DataStore code.
-- Session-locking prevents duplication/rollback bugs if a player somehow
-- ends up in two servers at once. Do NOT replace this with raw
-- DataStoreService calls "for simplicity" — that's how production data
-- loss bugs happen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local log = Log.new("DataSystem")

-- Installed via Wally, synced in by Rojo from the Packages/ folder — see
-- places/playarea.project.json's ReplicatedStorage.Packages mapping.
local ProfileService = require(ReplicatedStorage.Packages.ProfileService)

local PROFILE_STORE_NAME = "PlayerData_v2" -- v2: bumped alongside the 5-role migration (see docs/ARCHITECTURE.md changelog)

type ProfileTemplate = {
    role: string?,
    familyId: string,
    joinedAt: number,
}

local PROFILE_TEMPLATE: ProfileTemplate = {
    role = nil,
    familyId = "",
    joinedAt = 0,
}

local ProfileStore = ProfileService.GetProfileStore(PROFILE_STORE_NAME, PROFILE_TEMPLATE)

local DataSystem = { Name = "DataSystem", Dependencies = {} }

-- Fired (player) once a profile has finished loading and is safe to read.
-- Any system that needs profile data on join (RoleSystem's fallback
-- assignment, analytics, etc.) subscribes to this instead of DataSystem
-- calling into them directly — keeps DataSystem from having to know who
-- consumes profile data, which is the whole point of the loose-coupling
-- rework (see docs/ARCHITECTURE.md §3).
DataSystem.ProfileLoaded = Signal.new()

local activeProfiles: { [Player]: any } = {}

function DataSystem.Init(_registry: { [string]: any })
    Players.PlayerRemoving:Connect(function(player)
        local profile = activeProfiles[player]
        if profile then
            profile:Release()
        end
    end)
end

function DataSystem.Start()
    Players.PlayerAdded:Connect(function(player)
        DataSystem.LoadProfile(player)
    end)

    -- Handle players who joined before this System started (rare, but
    -- possible depending on script execution order).
    for _, player in Players:GetPlayers() do
        task.spawn(DataSystem.LoadProfile, player)
    end
end

function DataSystem.LoadProfile(player: Player)
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
    DataSystem.ProfileLoaded:Fire(player)
end

function DataSystem.GetProfile(player: Player)
    return activeProfiles[player]
end

function DataSystem.SaveAll()
    for _player, profile in activeProfiles do
        profile:Release()
    end
end

return DataSystem
