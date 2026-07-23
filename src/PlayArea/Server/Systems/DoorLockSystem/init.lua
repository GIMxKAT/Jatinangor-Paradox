--!strict
-- DoorLockSystem (PlayArea)
--
-- Scans CollectionService-tagged mechanisms (doors, locks, levers,
-- pressure plates, PIN panels — the diagram's "Door and locks mechanics")
-- and is the ONLY thing allowed to decide whether an interaction succeeds.
-- Role and distance are re-validated here regardless of what the client
-- claims. Builders tag an instance "Mechanism" plus Attributes
-- MechanismId/RequiredRole/PuzzleGroupId — no scripter involvement needed
-- to add a new mechanism instance.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("DoorLockSystem")

local MECHANISM_TAG = "Mechanism"
local MAX_INTERACT_DISTANCE = 12 -- studs; tune once level design lands

type MechanismState = {
    instance: Instance,
    mechanismId: string,
    requiredRole: string?,
    puzzleGroupId: string,
    activated: boolean,
}

local DoorLockSystem = { Name = "DoorLockSystem", Dependencies = { "RoleSystem", "FamilySystem" } }

DoorLockSystem.AllGeneratorsActivated = Signal.new()

local mechanisms: { [string]: MechanismState } = {}
local puzzleGroupCompletion: { [string]: boolean } = {}

local RoleSystem: any
local FamilySystem: any

local function registerMechanism(instance: Instance)
    local mechanismId = instance:GetAttribute("MechanismId")
    local puzzleGroupId = instance:GetAttribute("PuzzleGroupId")

    if not (typeof(mechanismId) == "string" and typeof(puzzleGroupId) == "string") then
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
        requiredRole = instance:GetAttribute("RequiredRole") :: string?,
        puzzleGroupId = puzzleGroupId,
        activated = false,
    }
end

function DoorLockSystem.HandleInteract(player: Player, mechanismId: unknown)
    if typeof(mechanismId) ~= "string" then
        return
    end

    local state = mechanisms[mechanismId]
    if not state then
        return
    end

    if not RoleSystem.CanAccess(player, state.requiredRole) then
        return
    end

    -- Never trust distance from the client.
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

    state.activated = true

    local familyPlayers = FamilySystem.GetFamilyPlayers()
    Net.FireClients(familyPlayers, RemoteNames.Mechanism_Updated, mechanismId, true)

    DoorLockSystem.CheckGroupCompletion(state.puzzleGroupId)
end

function DoorLockSystem.CheckGroupCompletion(puzzleGroupId: string)
    local allActivated = true
    for _, state in mechanisms do
        if state.puzzleGroupId == puzzleGroupId and not state.activated then
            allActivated = false
            break
        end
    end

    if allActivated and not puzzleGroupCompletion[puzzleGroupId] then
        puzzleGroupCompletion[puzzleGroupId] = true
        log:Info(("Puzzle group completed: %s"):format(puzzleGroupId))
        DoorLockSystem.CheckAllGeneratorsActivated()
    end
end

function DoorLockSystem.CheckAllGeneratorsActivated()
    -- TODO: compare puzzleGroupCompletion against the full list of
    -- required generator groups once level design defines them, then:
    -- DoorLockSystem.AllGeneratorsActivated:Fire()
end

function DoorLockSystem.Init(registry: { [string]: any })
    RoleSystem = registry.RoleSystem
    FamilySystem = registry.FamilySystem
end

function DoorLockSystem.Start()
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

    Net.OnServerEvent(RemoteNames.Mechanism_Interact, function(player, mechanismId)
        DoorLockSystem.HandleInteract(player, mechanismId)
    end, 5 --[[ max 5 interactions/sec/player ]])
end

return DoorLockSystem
