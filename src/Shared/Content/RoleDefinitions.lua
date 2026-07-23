--!strict
-- RoleDefinitions
--
-- Data-driven role metadata: display info for the Lobby's role-balancing
-- UI, and which SkillIds each role grants access to in the PlayArea. This
-- is intentionally DATA, not code, so adding/renaming a skill for a role is
-- a one-line change here rather than a RoleSystem/SkillSystem edit — the
-- same "content is data" philosophy the original PuzzleDefinitions.lua
-- established.
--
-- SkillIds listed here are validated against the actual registered skills
-- at PlayArea boot time (SkillSystem warns, does not crash, on a mismatch
-- — see PlayArea/Server/Systems/SkillSystem/init.lua) so a typo here never
-- takes a server down mid-event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RoleConstants = require(ReplicatedStorage.Shared.Constants.RoleConstants)

type Role = RoleConstants.Role

export type RoleDefinition = {
    DisplayName: string,
    Color: Color3,
    Description: string,
    SkillIds: { string },
}

local RoleDefinitions: { [Role]: RoleDefinition } = {
    Navigator = {
        DisplayName = "Navigator",
        Color = Color3.fromRGB(86, 160, 255),
        Description = "Reads the family's shared map/objective state and reveals paths others can't see.",
        SkillIds = { "Navigator_RevealPath" },
    },
    Detective = {
        DisplayName = "Detective",
        Color = Color3.fromRGB(255, 196, 61),
        Description = "Spots hidden clues and interactable details other roles walk past.",
        SkillIds = { "Detective_ClueScan" },
    },
    Scout = {
        DisplayName = "Scout",
        Color = Color3.fromRGB(94, 222, 137),
        Description = "Moves fast and reaches areas gated behind mobility checks.",
        SkillIds = { "Scout_SpeedBoost" },
    },
    CodeBreaker = {
        DisplayName = "Code-Breaker",
        Color = Color3.fromRGB(198, 120, 255),
        Description = "Assists with cipher/pattern minigames — extra hints, extra attempts.",
        SkillIds = { "CodeBreaker_ExtraHint" },
    },
    Support = {
        DisplayName = "Support",
        Color = Color3.fromRGB(255, 129, 129),
        Description = "Keeps the family's shared stats/state healthy so nobody blocks progress.",
        SkillIds = { "Support_TeamAssist" },
    },
}

return RoleDefinitions
