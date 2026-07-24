--!strict
-- Five roles balanced per family in the Lobby before a session starts (see
-- Lobby/Server/Systems/RoleBalancingSystem). Role -> skill mapping and
-- display metadata live in Shared/Content/RoleDefinitions.lua as data, not
-- here — this file only defines which role identifiers exist.

export type Role = "Navigator" | "Detective" | "Scout" | "CodeBreaker" | "Support"

local RoleConstants = {}

RoleConstants.All = { "Navigator", "Detective", "Scout", "CodeBreaker", "Support" } :: { Role }

return RoleConstants
