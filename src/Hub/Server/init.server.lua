--!strict
-- Hub place bootstrap.
--
-- Pre-creates every declared RemoteEvent, then hands off to PluginRegistry
-- to discover and boot every System under Systems/ — see
-- Shared/Registry/PluginRegistry.lua for why this replaced a hand-written
-- registry table (loose coupling: adding a Hub system is "add a folder",
-- not "edit this file").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local PluginRegistry = require(ReplicatedStorage.Shared.Registry.PluginRegistry)

local log = Log.new("Hub.Bootstrap")

Net.InitRemotes()
log:Info("All RemoteEvents initialized")

PluginRegistry.DiscoverAndBoot(script.Systems, "Hub")

log:Info("Hub booted.")
