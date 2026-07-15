--!strict

export type Dimension = "Normal" | "Alter"

local DimensionConstants = {}

DimensionConstants.All = { "Normal", "Alter" } :: { Dimension }

return DimensionConstants
