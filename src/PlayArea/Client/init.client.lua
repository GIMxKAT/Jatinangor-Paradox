--!strict
-- PlayArea place client bootstrap. Same DiscoverAndBoot pattern as every
-- other place's client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local PluginRegistry = require(ReplicatedStorage.Shared.Registry.PluginRegistry)

local log = Log.new("PlayArea.ClientBootstrap")

PluginRegistry.DiscoverAndBoot(script.Controllers, "PlayArea.Client")

log:Info("PlayArea client booted.")
