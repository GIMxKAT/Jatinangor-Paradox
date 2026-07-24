--!strict
-- Lobby place bootstrap. See Hub/Server/init.server.lua for the pattern —
-- identical shape across all three places by design, so switching between
-- them requires zero relearning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local PluginRegistry = require(ReplicatedStorage.Shared.Registry.PluginRegistry)

local log = Log.new("Lobby.Bootstrap")

Net.InitRemotes()
log:Info("All RemoteEvents initialized")

PluginRegistry.DiscoverAndBoot(script.Systems, "Lobby")

log:Info("Lobby booted.")
