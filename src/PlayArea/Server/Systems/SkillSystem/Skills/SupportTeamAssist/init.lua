--!strict
-- Support_TeamAssist — reference skill implementation.
--
-- Restores a flat amount of every nearby family member's stats.
-- Demonstrates a skill reaching another System's *public* API
-- (PlayerStatsSystem.Restore) through the registry SkillSystem forwards
-- into `context.registry` — the same dependency-injection path every
-- System uses to reach another System, so a skill is never tempted to
-- `require` PlayerStatsSystem's file directly.

local ASSIST_RADIUS_STUDS = 20
local RESTORE_AMOUNT = 25

local SupportTeamAssist = {
    Id = "Support_TeamAssist",
    DisplayName = "Team Assist",
    Description = "Restores stats for nearby family members.",
    CooldownSeconds = 30,
}

function SupportTeamAssist.Execute(player: Player, context: { [string]: any }): boolean
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return false
    end

    local registry = context.registry :: { [string]: any }?
    local PlayerStatsSystem = registry and registry.PlayerStatsSystem
    if not PlayerStatsSystem then
        return false
    end

    local familyPlayers = (context.familyPlayers :: { Player }?) or {}
    local assisted = false

    for _, member in familyPlayers do
        local memberCharacter = member.Character
        local memberRoot = memberCharacter and memberCharacter:FindFirstChild("HumanoidRootPart")
        if
            memberRoot
            and (memberRoot.Position - (rootPart :: BasePart).Position).Magnitude
                <= ASSIST_RADIUS_STUDS
        then
            PlayerStatsSystem.Restore(member, RESTORE_AMOUNT)
            assisted = true
        end
    end

    return assisted
end

return SupportTeamAssist
