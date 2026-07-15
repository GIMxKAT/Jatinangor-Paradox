--!strict
-- Net.lua
--
-- The ONLY module allowed to create/touch RemoteEvents directly.
-- Services/Controllers call Net.FireServer / Net.OnServerEvent / etc.
-- and never reach into ReplicatedStorage for a RemoteEvent themselves.
--
-- Why this exists:
--   1. Consistent naming (see Constants/RemoteNames.lua)
--   2. Server-side rate limiting lives in exactly one place
--   3. Easy to add logging/metrics later without touching every Service

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteNames = require(script.Parent.Parent.Constants.RemoteNames)

local REMOTES_FOLDER_NAME = "NetRemotes"
local DEFAULT_MAX_CALLS_PER_SECOND = 10

local Net = {}

local remotesFolder: Folder

local function getRemotesFolder(): Folder
    if remotesFolder then
        return remotesFolder
    end

    if game:GetService("RunService"):IsServer() then
        local folder = Instance.new("Folder")
        folder.Name = REMOTES_FOLDER_NAME
        folder.Parent = ReplicatedStorage
        remotesFolder = folder
    else
        remotesFolder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME) :: Folder
    end

    return remotesFolder
end

local function getOrCreateRemote(remoteName: string): RemoteEvent
    local folder = getRemotesFolder()

    if game:GetService("RunService"):IsServer() then
        -- Server: create the remote if it doesn't exist yet.
        local existing = folder:FindFirstChild(remoteName)
        if existing then
            return existing :: RemoteEvent
        end
        local remote = Instance.new("RemoteEvent")
        remote.Name = remoteName
        remote.Parent = folder
        return remote
    else
        -- Client: wait for the server to have created it.
        -- Net.InitRemotes() in init.server.lua pre-creates all remotes before
        -- any LocalScript runs, so this should resolve almost instantly.
        local remote = folder:WaitForChild(remoteName, 10)
        assert(
            remote,
            ("Remote '%s' not found after 10s — did init.server.lua call Net.InitRemotes()?"):format(
                remoteName
            )
        )
        return remote :: RemoteEvent
    end
end

-- Validate that every name used is one we actually declared, so a typo
-- fails loudly at call time instead of silently creating a new remote.
local function assertKnownRemote(remoteName: string)
    local isKnown = false
    for _, name in RemoteNames do
        if name == remoteName then
            isKnown = true
            break
        end
    end
    assert(isKnown, ("'%s' is not declared in Constants/RemoteNames.lua"):format(remoteName))
end

--- Rate limiting: per-player, per-remote call counters ---
local callCounts: { [Player]: { [string]: { count: number, windowStart: number } } } = {}

local function isRateLimited(player: Player, remoteName: string, maxPerSecond: number): boolean
    local now = os.clock()
    callCounts[player] = callCounts[player] or {}
    local bucket = callCounts[player][remoteName]

    if not bucket or now - bucket.windowStart >= 1 then
        callCounts[player][remoteName] = { count = 1, windowStart = now }
        return false
    end

    bucket.count += 1
    return bucket.count > maxPerSecond
end

Players.PlayerRemoving:Connect(function(player)
    callCounts[player] = nil
end)

--- Public API ---

-- Server only: call this at the very top of init.server.lua, before any
-- service Init/Start, to eagerly create every declared RemoteEvent.
-- This guarantees all remotes exist before any LocalScript runs, so
-- client-side Net.OnClientEvent / Net.FireServer never race against a
-- missing remote.
function Net.InitRemotes()
    assert(
        game:GetService("RunService"):IsServer(),
        "Net.InitRemotes() must be called from the server"
    )
    local folder = getRemotesFolder()
    for _, name in RemoteNames do
        if not folder:FindFirstChild(name) then
            local remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = folder
        end
    end
end

function Net.FireServer(remoteName: string, ...: any)
    assertKnownRemote(remoteName)
    local remote = getOrCreateRemote(remoteName)
    remote:FireServer(...)
end

-- Server: listen for a client-fired event. Automatically rate-limited.
function Net.OnServerEvent(
    remoteName: string,
    callback: (player: Player, ...any) -> (),
    maxCallsPerSecond: number?
)
    assertKnownRemote(remoteName)
    local remote = getOrCreateRemote(remoteName)
    local limit = maxCallsPerSecond or DEFAULT_MAX_CALLS_PER_SECOND

    remote.OnServerEvent:Connect(function(player, ...)
        if isRateLimited(player, remoteName, limit) then
            return
        end
        callback(player, ...)
    end)
end

-- Server -> single Client
function Net.FireClient(player: Player, remoteName: string, ...: any)
    assertKnownRemote(remoteName)
    local remote = getOrCreateRemote(remoteName)
    remote:FireClient(player, ...)
end

-- Server -> a list of Clients (e.g. one family's players)
function Net.FireClients(players: { Player }, remoteName: string, ...: any)
    assertKnownRemote(remoteName)
    local remote = getOrCreateRemote(remoteName)
    for _, player in players do
        remote:FireClient(player, ...)
    end
end

-- Client: listen for a server-fired event.
function Net.OnClientEvent(remoteName: string, callback: (...any) -> ())
    assertKnownRemote(remoteName)
    local remote = getOrCreateRemote(remoteName)
    remote.OnClientEvent:Connect(callback)
end

return Net
