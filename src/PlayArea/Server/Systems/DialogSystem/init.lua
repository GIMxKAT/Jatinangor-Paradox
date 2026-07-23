--!strict
-- DialogSystem (PlayArea)
--
-- Runs dialog trees (NPC conversations). Each tree is a content plugin
-- under Dialogs/ (loaded via ContentRegistry) matching
-- Shared.Types.DialogTreeDefinition: a RootNodeId and a Nodes map of
-- Id -> {Text, Options}. World NPCs reference a tree by Id via a
-- DialogTreeId Attribute — see EntityAISystem for how NPCs are placed.
--
-- One active conversation per player at a time; the server holds the
-- authoritative current node so a client can't skip to an arbitrary node
-- by forging Dialog_Advance payloads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ContentRegistry = require(ReplicatedStorage.Shared.Registry.ContentRegistry)
local Types = require(ReplicatedStorage.Shared.Types.Types)

local log = Log.new("DialogSystem")

local DialogSystem = { Name = "DialogSystem", Dependencies = {} }

local trees: { [string]: Types.DialogTreeDefinition } = {}
local activeNodeByPlayer: { [Player]: { treeId: string, nodeId: string } } = {}

local function sendNode(player: Player, tree: Types.DialogTreeDefinition, nodeId: string)
    local node = tree.Nodes[nodeId]
    if not node then
        log:Error(("Dialog tree '%s' has no node '%s'"):format(tree.Id, nodeId))
        return
    end
    activeNodeByPlayer[player] = { treeId = tree.Id, nodeId = nodeId }
    Net.FireClient(player, RemoteNames.Dialog_NodeUpdated, node)
end

local function handleStart(player: Player, treeId: unknown)
    if typeof(treeId) ~= "string" then
        return
    end
    local tree = trees[treeId]
    if not tree then
        return
    end
    sendNode(player, tree, tree.RootNodeId)
end

local function handleAdvance(player: Player, optionIndex: unknown)
    local active = activeNodeByPlayer[player]
    if not active or typeof(optionIndex) ~= "number" then
        return
    end

    local tree = trees[active.treeId]
    local node = tree and tree.Nodes[active.nodeId]
    local option = node and node.Options and node.Options[optionIndex]
    if not (tree and node and option) then
        return
    end

    if option.NextNodeId then
        sendNode(player, tree, option.NextNodeId)
    else
        activeNodeByPlayer[player] = nil
        Net.FireClient(player, RemoteNames.Dialog_End)
    end
end

function DialogSystem.Init(_registry: { [string]: any })
    trees = ContentRegistry.Load(script.Dialogs, "Dialogs") :: any
end

function DialogSystem.Start()
    local Players = game:GetService("Players")
    Players.PlayerRemoving:Connect(function(player)
        activeNodeByPlayer[player] = nil
    end)

    Net.OnServerEvent(RemoteNames.Dialog_Start, handleStart)
    Net.OnServerEvent(RemoteNames.Dialog_Advance, handleAdvance)
end

return DialogSystem
