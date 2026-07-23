--!strict
-- SkillController — wires the (up to 5, one per role, growing later)
-- ability hotbar. Call Activate from whatever input binds to it
-- (ContextActionService, so it's cross-platform by default — see
-- Shared/Platform/Platform.lua for the UI-layer cross-platform pieces this
-- doesn't already cover).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Constants.RemoteNames)
local Net = require(ReplicatedStorage.Shared.Net.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local SkillController = { Name = "SkillController", Dependencies = {} }

SkillController.SkillActivated = Signal.new() -- (userId, skillId) — any family member
SkillController.CooldownUpdated = Signal.new() -- (skillId, cooldownSeconds) — mine only

function SkillController.Start()
    Net.OnClientEvent(RemoteNames.Skill_Activated, function(userId: number, skillId: string)
        SkillController.SkillActivated:Fire(userId, skillId)
        -- Trigger local VFX/SFX for the activation here.
    end)

    Net.OnClientEvent(
        RemoteNames.Skill_CooldownUpdated,
        function(skillId: string, cooldownSeconds: number)
            SkillController.CooldownUpdated:Fire(skillId, cooldownSeconds)
        end
    )
end

function SkillController.Activate(skillId: string)
    Net.FireServer(RemoteNames.Skill_Activate, skillId)
end

return SkillController
