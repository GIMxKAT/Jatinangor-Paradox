--!strict
-- Scout_SpeedBoost — reference skill implementation.
--
-- Copy this file's shape for any new skill: return a table matching
-- Shared.Types.SkillDefinition. SkillSystem never needs to change to pick
-- this up — it was discovered purely by living under Skills/.

local BOOST_MULTIPLIER = 1.6
local BOOST_DURATION_SECONDS = 5

local ScoutSpeedBoost = {
    Id = "Scout_SpeedBoost",
    DisplayName = "Sprint",
    Description = "Temporary movement speed boost for reaching mobility-gated areas.",
    CooldownSeconds = 20,
}

function ScoutSpeedBoost.Execute(player: Player, _context: { [string]: any }): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        return false
    end

    local baseSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = baseSpeed * BOOST_MULTIPLIER

    task.delay(BOOST_DURATION_SECONDS, function()
        if humanoid.Parent then
            humanoid.WalkSpeed = baseSpeed
        end
    end)

    return true
end

return ScoutSpeedBoost
