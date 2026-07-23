--!strict
-- SessionAdmissionSystem (Hub)
--
-- Thin GameSystem wrapper around Shared/Session/SessionAdmission so other
-- Hub systems (MatchmakingSystem) reach it through the injected registry —
-- like every other cross-system call in this codebase — instead of
-- reaching into Shared internals directly. See Shared/Session/
-- SessionAdmission.lua for the actual atomic-counter implementation and
-- the race-condition analysis.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SessionAdmission = require(ReplicatedStorage.Shared.Session.SessionAdmission)

local SessionAdmissionSystem = { Name = "SessionAdmissionSystem", Dependencies = {} }

function SessionAdmissionSystem.TryAdmit(familyId: string): boolean
    return SessionAdmission.TryAdmit(familyId)
end

function SessionAdmissionSystem.Release(familyId: string)
    SessionAdmission.Release(familyId)
end

function SessionAdmissionSystem.GetApproximateActiveCount(): number?
    return SessionAdmission.GetApproximateActiveCount()
end

return SessionAdmissionSystem
