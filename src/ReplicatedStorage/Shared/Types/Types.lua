--!strict
local RoleConstants = require(script.Parent.Parent.Constants.RoleConstants)
local DimensionConstants = require(script.Parent.Parent.Constants.DimensionConstants)

export type Role = RoleConstants.Role
export type Dimension = DimensionConstants.Dimension

export type PlayerProfileData = {
    role: Role?,
    dimension: Dimension,
    familyId: string,
    joinedAt: number,
}

export type MechanismState = {
    mechanismId: string,
    requiredRole: Role,
    puzzleGroupId: string,
    activated: boolean,
}

export type FamilySessionState = {
    familyId: string,
    journalFragmentsCollected: { [string]: boolean },
    mechanismStates: { [string]: MechanismState },
    puzzleGroupsCompleted: { [string]: boolean },
    sessionStatus: "Lobby" | "InProgress" | "Won",
    startedAt: number,
}

return {}
