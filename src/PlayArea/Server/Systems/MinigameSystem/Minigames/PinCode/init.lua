--!strict
-- PinCode — reference minigame implementation.
--
-- Copy this file's shape (Id, Start, SubmitAttempt, GetPublicState) for
-- any new minigame; MinigameSystem never needs to change to pick it up.
-- The secret code lives only in the FULL state MinigameSystem keeps
-- server-side — GetPublicState never includes it.

local DIGIT_COUNT = 4
local MAX_ATTEMPTS = 6

local PinCode = {
    Id = "PinCode",
    DisplayName = "PIN Code",
}

function PinCode.Start(_player: Player, _context: { [string]: any }): { [string]: any }
    local digits = {}
    for _ = 1, DIGIT_COUNT do
        table.insert(digits, tostring(math.random(0, 9)))
    end

    return {
        secretCode = table.concat(digits),
        attemptsRemaining = MAX_ATTEMPTS,
    }
end

function PinCode.SubmitAttempt(
    _player: Player,
    state: { [string]: any },
    attempt: any
): (boolean, { [string]: any })
    if typeof(attempt) ~= "string" then
        return false, state
    end

    local newState = table.clone(state)
    newState.attemptsRemaining = math.max((state.attemptsRemaining :: number) - 1, 0)

    local solved = attempt == state.secretCode
    return solved, newState
end

function PinCode.GetPublicState(state: { [string]: any }): { [string]: any }
    return {
        digitCount = DIGIT_COUNT,
        attemptsRemaining = state.attemptsRemaining,
    }
end

return PinCode
