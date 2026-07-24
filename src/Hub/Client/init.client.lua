--!strict
-- Hub place client bootstrap. Same DiscoverAndBoot pattern as the server —
-- adding a Hub Controller is "add a folder under Controllers/", not "edit
-- this file."

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local PluginRegistry = require(ReplicatedStorage.Shared.Registry.PluginRegistry)

local log = Log.new("Hub.ClientBootstrap")

PluginRegistry.DiscoverAndBoot(script.Controllers, "Hub.Client")

log:Info("Hub client booted.")
