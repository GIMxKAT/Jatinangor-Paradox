--!strict
-- PlayArea place bootstrap. Same DiscoverAndBoot pattern as Hub/Lobby —
-- adding a new PlayArea System (a new item type's parent System, a new
-- minigame engine, whatever a programmer owns) is "add a folder under
-- Systems/", never an edit to this file. See Shared/Registry/
-- PluginRegistry.lua for the full rationale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local PluginRegistry = require(ReplicatedStorage.Shared.Registry.PluginRegistry)
local SessionAdmission = require(ReplicatedStorage.Shared.Session.SessionAdmission)

local log = Log.new("PlayArea.Bootstrap")

Net.InitRemotes()
log:Info("All RemoteEvents initialized")

local registry = PluginRegistry.DiscoverAndBoot(script.Systems, "PlayArea")

game:BindToClose(function()
    log:Info("Server closing — saving all active profiles")
    if registry.DataSystem then
        registry.DataSystem.SaveAll()
    end

    -- Best-effort release of this family's Hub admission slot on an
    -- ordinary shutdown (deploy, low player count, etc). GameSystem
    -- already releases it on a win; this covers every OTHER shutdown path.
    -- A hard crash that skips BindToClose entirely is the one gap this
    -- doesn't cover — see the "KNOWN GAP" note in Shared/Session/
    -- SessionAdmission.lua for why that's a documented v1.1 item rather
    -- than solved here.
    if registry.FamilySystem then
        SessionAdmission.Release(registry.FamilySystem.GetFamilyId())
    end
end)

log:Info("PlayArea booted.")
