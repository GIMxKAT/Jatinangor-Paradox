--!strict
-- DebugAutoJoinController — TEMPORARY, POC-ONLY.
--
-- Fires Hub_CreateFamily then Hub_StartFamily automatically a few seconds
-- after joining, so the full admission -> ReserveServer ->
-- TeleportToPrivateServer chain can be exercised in Studio without
-- StarterGui buttons existing yet (see docs/ARCHITECTURE.md §8 — this is
-- the only way to smoke-test SessionAdmission/MatchmakingSystem against a
-- real published multi-place Universe until the real Hub UI is built).
--
-- DELETE THIS FILE once the real HubUIController buttons are wired up, or
-- gate it behind an explicit opt-in flag before ever shipping — it must
-- never auto-fire in a live event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("DebugAutoJoin")

local CREATE_DELAY_SECONDS = 2
local START_DELAY_SECONDS = 2

local DebugAutoJoinController = { Name = "DebugAutoJoinController", Dependencies = {} }

function DebugAutoJoinController.Start()
    Net.OnClientEvent(RemoteNames.Hub_FamilyUpdated, function(data)
        log:Info(("Hub_FamilyUpdated received: %s"):format(tostring(data and data.accessCode)))
    end)

    Net.OnClientEvent(RemoteNames.Hub_QueueStatus, function(data)
        log:Info(("Hub_QueueStatus received: %s"):format(tostring(data and data.state)))
    end)

    task.delay(CREATE_DELAY_SECONDS, function()
        log:Info("Firing Hub_CreateFamily")
        Net.FireServer(RemoteNames.Hub_CreateFamily)

        task.delay(START_DELAY_SECONDS, function()
            log:Info("Firing Hub_StartFamily")
            Net.FireServer(RemoteNames.Hub_StartFamily)
        end)
    end)
end

return DebugAutoJoinController
