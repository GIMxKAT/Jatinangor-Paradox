--!strict
-- PlayerService
--
-- Since each server instance = one reserved "family" session (see
-- ARCHITECTURE.md §8 on scalability), this service's job is mostly about
-- exposing "who's in this family" to other Services cleanly, plus reading
-- the family/access-code data that TeleportService passed in.

local Players = game:GetService("Players")

local PlayerService = {}

local familyId: string = "unknown-family"

function PlayerService.Init(_registry: { [string]: any })
    -- In production: read familyId from the TeleportData passed via
    -- TeleportService:ReserveServer, e.g.:
    -- local joinData = player:GetJoinData()
    -- familyId = joinData.TeleportData and joinData.TeleportData.familyId
end

function PlayerService.Start() end

function PlayerService.GetFamilyId(): string
    return familyId
end

function PlayerService.GetFamilyPlayers(): { Player }
    -- All current servers are single-family in this design, so this is
    -- simply every connected player. Kept as its own function so the rest
    -- of the codebase never assumes "all players in this server" directly
    -- — if that assumption ever changes, only this function needs to.
    return Players:GetPlayers()
end

return PlayerService
