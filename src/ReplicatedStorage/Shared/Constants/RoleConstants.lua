--!strict

export type Role = "Merah" | "Kuning" | "Hijau"

local RoleConstants = {}

RoleConstants.All = { "Merah", "Kuning", "Hijau" } :: { Role }

return RoleConstants
