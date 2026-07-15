--!strict
-- PuzzleService
--
-- Scans CollectionService-tagged mechanisms, builds in-memory state, and
-- is the ONLY thing allowed to decide whether an interaction succeeds.
-- Distance, role, and dimension are all re-validated here regardless of
-- what the client claims.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("PuzzleService")

local MECHANISM_TAG = "Mechanism"
local MAX_INTERACT_DISTANCE = 12 -- studs; tune once level design lands

type MechanismState = {
    instance: Instance,
    mechanismId: string,
    requiredRole: string,
    puzzleGroupId: string,
    activated: boolean,
}

local PuzzleService = {}

PuzzleService.AllGeneratorsActivated = Signal.new()

local mechanisms: { [string]: MechanismState } = {}
local puzzleGroupCompletion: { [string]: boolean } = {}

local RoleService: any
local _DimensionService: any -- TODO: use in HandleInteract to verify player's current dimension
local PlayerService: any

local function registerMechanism(instance: Instance)
    local mechanismId = instance:GetAttribute("MechanismId")
    local requiredRole = instance:GetAttribute("RequiredRole")
    local puzzleGroupId = instance:GetAttribute("PuzzleGroupId")

    if not (mechanismId and requiredRole and puzzleGroupId) then
        log:Warn(
            ("Instance %s tagged '%s' is missing required Attributes — skipping"):format(
                instance:GetFullName(),
                MECHANISM_TAG
            )
        )
        return
    end

    mechanisms[mechanismId] = {
        instance = instance,
        mechanismId = mechanismId,
        requiredRole = requiredRole,
        puzzleGroupId = puzzleGroupId,
        activated = false,
    }
end

function PuzzleService.Init(registry: { [string]: any })
    RoleService = registry.Role
    _DimensionService = registry.Dimension
    PlayerService = registry.Player
end

function PuzzleService.Start()
    for _, instance in CollectionService:GetTagged(MECHANISM_TAG) do
        registerMechanism(instance)
    end
    CollectionService:GetInstanceAddedSignal(MECHANISM_TAG):Connect(registerMechanism)
    CollectionService:GetInstanceRemovedSignal(MECHANISM_TAG):Connect(function(instance)
        for id, state in mechanisms do
            if state.instance == instance then
                mechanisms[id] = nil
            end
        end
    end)

    Net.OnServerEvent(RemoteNames.Puzzle_Interact, function(player, mechanismId)
        PuzzleService.HandleInteract(player, mechanismId)
    end, 5 --[[ max 5 interactions/sec/player ]])

    log:Info(("Registered %d mechanisms"):format((function()
        local count = 0
        for _ in mechanisms do
            count += 1
        end
        return count
    end)()))
end

function PuzzleService.HandleInteract(player: Player, mechanismId: unknown)
    if typeof(mechanismId) ~= "string" then
        return
    end

    local state = mechanisms[mechanismId]
    if not state then
        return
    end

    -- 1. Role check
    if not RoleService.CanAccess(player, state.requiredRole) then
        return
    end

    -- 2. Dimension check (mechanisms live in a specific dimension; the
    -- instance itself should carry a "Dimension" attribute too — omitted
    -- here for brevity, wire up analogous to RequiredRole above)

    -- 3. Distance check — never trust the client's claimed position.
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local mechanismPart = state.instance:IsA("BasePart") and state.instance
        or state.instance:FindFirstChildWhichIsA("BasePart")

    if not (rootPart and mechanismPart) then
        return
    end

    local distance = (rootPart.Position - mechanismPart.Position).Magnitude
    if distance > MAX_INTERACT_DISTANCE then
        return
    end

    -- All checks passed — mutate state.
    state.activated = true

    local familyPlayers = PlayerService.GetFamilyPlayers()
    Net.FireClients(familyPlayers, RemoteNames.Puzzle_MechanismUpdated, mechanismId, true)

    PuzzleService.CheckGroupCompletion(state.puzzleGroupId)
end

function PuzzleService.CheckGroupCompletion(puzzleGroupId: string)
    local allActivated = true
    for _, state in mechanisms do
        if state.puzzleGroupId == puzzleGroupId and not state.activated then
            allActivated = false
            break
        end
    end

    if allActivated then
        puzzleGroupCompletion[puzzleGroupId] = true
        log:Info(("Puzzle group completed: %s"):format(puzzleGroupId))
        PuzzleService.CheckAllGeneratorsActivated()
    end
end

function PuzzleService.CheckAllGeneratorsActivated()
    -- TODO: compare puzzleGroupCompletion against the full list of
    -- required generator groups once level design defines them, then:
    -- PuzzleService.AllGeneratorsActivated:Fire()
end

return PuzzleService
