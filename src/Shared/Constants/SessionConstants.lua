--!strict
-- Tunable capacity/timing constants for the Hub -> Lobby -> PlayArea
-- session-admission pipeline (see Shared/Session/SessionAdmission.lua and
-- docs/ARCHITECTURE.md §8). Kept as named constants, not magic numbers
-- inline, so the event's ops lead can retune concurrency without an
-- engineer touching logic code — this is a live-event policy dial, not an
-- engineering decision.

return {
    -- How many families may be simultaneously "in flight" (Lobby +
    -- PlayArea combined) at once. This is a concurrency ceiling, not a
    -- pre-provisioned server count — Roblox allocates reserved servers
    -- on demand, it does not let you pre-warm idle capacity.
    MAX_CONCURRENT_SESSIONS = 50,

    -- Extra headroom above MAX_CONCURRENT_SESSIONS before a family is
    -- hard-rejected, absorbing bursts right at the cap boundary.
    RESERVE_BUFFER_PERCENT = 0.10, -- => effective ceiling of 55

    -- How long an admitted family has to actually load into the Lobby
    -- before their slot is assumed abandoned (crash, disconnect, stuck
    -- teleport) and released back to the pool.
    ADMISSION_CLAIM_TTL_SECONDS = 120,

    -- MemoryStoreSortedMap name backing the atomic admission counter +
    -- per-family claim records. Versioned suffix so a schema change during
    -- the event doesn't collide with stale entries from a previous version.
    ADMISSION_MEMORYSTORE_MAP_NAME = "JP_SessionAdmission_v1",
    ADMISSION_COUNTER_KEY = "__ActiveSessionCount",

    -- Capacity-planning target only (not enforced anywhere in code): the
    -- whole 3-day event is expected to seat roughly this many distinct
    -- family sessions in total, arriving as a rolling trickle rather than
    -- one simultaneous peak. See docs/ARCHITECTURE.md §8.1 for the math.
    TARGET_TOTAL_FAMILIES_OVER_EVENT = 225,
    TARGET_FAMILY_SIZE = { MIN = 20, MAX = 25 },
}
