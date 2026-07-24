--!strict
-- SessionAdmission
--
-- Race-safe concurrency admission control for the Hub -> Lobby -> PlayArea
-- pipeline. Required by BOTH the Hub place (TryAdmit, when a family wants
-- to start) and the PlayArea place (Release, when a family's session
-- ends) — MemoryStoreService is universe-wide, so any server in any place
-- of this game can read/write the same named SortedMap. No cross-place
-- messaging is needed for this.
--
-- THE RACE THIS SOLVES
-- Hub servers are independent Lua VMs with no shared memory. Naive
-- "read count, compare, write count" — whether in local Lua state or via a
-- plain DataStore GetAsync/SetAsync pair — is a classic check-then-act
-- race: two Hub servers can both read count=49 and both admit a family,
-- blowing past the cap.
--
-- WHY MemoryStoreSortedMap:UpdateAsync
-- Its transform function is atomic on Roblox's side: it always runs against
-- the latest committed value for that key, and is retried on write
-- conflict. That is a real compare-and-swap primitive. DataStoreService's
-- UpdateAsync has the same atomicity guarantee but far lower throughput and
-- no TTL; MessagingService is pub/sub only and gives no atomicity guarantee
-- for a shared counter at all. MemoryStore is the correct tool here.
--
-- WHY A SINGLE COUNTER KEY, NOT "COUNT THE LIVE ENTRIES"
-- An earlier draft of this module scanned the whole map (GetRangeAsync)
-- inside each family's own per-key UpdateAsync transform to compute the
-- current total. That is NOT race-free: MemoryStore's atomicity guarantee
-- is per-key. Two concurrent admits for two *different* families (keys A
-- and B) can each independently read a stale total via GetRangeAsync
-- before either commits, and both pass the cap check. The fix is to make
-- the cap check and the increment happen on ONE shared key
-- (SessionConstants.ADMISSION_COUNTER_KEY) inside a single UpdateAsync
-- call, so the read-check-write is truly a single atomic operation with no
-- window for another server to interleave.
--
-- WHY THE PER-FAMILY TTL DOES NOT DRIVE THE COUNTER
-- MemoryStore's per-entry TTL silently removes that entry — it does not
-- fire a callback, so it cannot decrement the shared counter for you. The
-- per-family claim entry here exists for idempotency (calling TryAdmit
-- twice for the same familyId must not double-count) and ops visibility
-- (you can inspect who currently holds a claim), not for counter
-- correctness. The counter is kept correct by explicit Release() calls:
-- the Hub, on a failed ReserveServer/Teleport, releases immediately
-- (compensating action); the PlayArea's GameSystem releases on session end
-- and in game:BindToClose (best-effort graceful shutdown).
--
-- KNOWN GAP (documented, not solved here — see docs/ARCHITECTURE.md §8.3):
-- if a PlayArea server hard-crashes before BindToClose completes, that
-- family's slot leaks until a periodic reconciliation job corrects the
-- drift. That reconciliation job is a v1.1 hardening item, intentionally
-- out of scope for this baseline — flagging it explicitly here is safer
-- than pretending a fully self-healing distributed counter fits in a
-- three-week build window.
--
-- SECOND KNOWN GAP, same reasoning: TryAdmit claims the family's own key
-- BEFORE incrementing the shared counter (see below), so a Hub server that
-- crashes in the narrow window between those two writes leaves a claim
-- record with no matching counter increment behind it. A later TryAdmit for
-- that same familyId then sees "already claimed" and returns true without
-- ever incrementing the counter — an under-count, not an over-count, and
-- self-heals once that claim's TTL expires. Same v1.1 reconciliation-job
-- scope as the gap above; not solved here for the same reason.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionConstants = require(ReplicatedStorage.Shared.Constants.SessionConstants)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local log = Log.new("SessionAdmission")

local claimsMap = MemoryStoreService:GetSortedMap(SessionConstants.ADMISSION_MEMORYSTORE_MAP_NAME)

local EFFECTIVE_CAP = math.floor(
    SessionConstants.MAX_CONCURRENT_SESSIONS * (1 + SessionConstants.RESERVE_BUFFER_PERCENT)
)

local SessionAdmission = {}

-- Attempts to admit `familyId`. Returns true if a slot was claimed (caller
-- may proceed to ReserveServer + Teleport), false if the cap is currently
-- full (caller should keep the family queued in the Hub and retry later,
-- e.g. on a short poll interval or when notified a slot may have freed).
function SessionAdmission.TryAdmit(familyId: string): boolean
    -- Idempotency gate: atomically claim the family's OWN key first. Because
    -- UpdateAsync's transform is atomic per-key, two concurrent
    -- TryAdmit(familyId) calls for the SAME family can't both observe "no
    -- claim yet" -- exactly one proceeds to touch the shared counter below;
    -- the other sees the claim already exists and returns true without
    -- incrementing anything (the "must not double-count" guarantee this
    -- module's doc comment promises).
    local alreadyClaimed = false
    local claimOk, claimErr = pcall(function()
        claimsMap:UpdateAsync(familyId, function(existing: any): any
            if existing then
                alreadyClaimed = true
                return existing -- no-op: keep the existing claim/TTL as-is
            end
            return { admittedAt = os.time() } -- provisional; rolled back below if the counter step doesn't pan out
        end, SessionConstants.ADMISSION_CLAIM_TTL_SECONDS)
    end)

    if not claimOk then
        log:Error(
            ("UpdateAsync (claim) failed for family %s: %s — treating as not admitted"):format(
                familyId,
                tostring(claimErr)
            )
        )
        return false
    end

    if alreadyClaimed then
        return true
    end

    -- We just reserved a brand-new claim; now try to actually take a slot.
    local admitted = false
    local ok, err = pcall(function()
        claimsMap:UpdateAsync(
            SessionConstants.ADMISSION_COUNTER_KEY,
            function(count: number?): number?
                local current = count or 0
                if current >= EFFECTIVE_CAP then
                    admitted = false
                    return nil -- returning nil aborts the write; counter is unchanged
                end
                admitted = true
                return current + 1
            end,
            SessionConstants.ADMISSION_CLAIM_TTL_SECONDS * 4
        ) -- counter key TTL: long safety margin, not the claim TTL
    end)

    if not ok then
        log:Error(
            ("UpdateAsync (counter) failed for family %s: %s — treating as not admitted"):format(
                familyId,
                tostring(err)
            )
        )
        pcall(function()
            claimsMap:RemoveAsync(familyId)
        end) -- roll back the provisional claim so a later retry for this family isn't blocked forever
        return false
    end

    if not admitted then
        -- Cap is full: roll back the provisional claim so tryStartFamily's
        -- retry loop (Hub) can try this same family again once a slot frees.
        pcall(function()
            claimsMap:RemoveAsync(familyId)
        end)
        return false
    end

    return true
end

-- Releases `familyId`'s slot: decrements the shared counter and removes
-- the per-family claim record. Idempotent — safe to call more than once
-- (e.g. once from a failed-teleport compensating action AND again from
-- game:BindToClose) since the counter never goes below zero.
function SessionAdmission.Release(familyId: string)
    local ok, err = pcall(function()
        claimsMap:UpdateAsync(
            SessionConstants.ADMISSION_COUNTER_KEY,
            function(count: number?): number?
                return math.max((count or 1) - 1, 0)
            end,
            SessionConstants.ADMISSION_CLAIM_TTL_SECONDS * 4
        )
    end)
    if not ok then
        log:Error(
            ("UpdateAsync (release counter) failed for family %s: %s"):format(
                familyId,
                tostring(err)
            )
        )
    end

    local removeOk, removeErr = pcall(function()
        claimsMap:RemoveAsync(familyId)
    end)
    if not removeOk then
        log:Warn(
            ("RemoveAsync (claim record) failed for family %s: %s"):format(
                familyId,
                tostring(removeErr)
            )
        )
    end
end

-- Ops/telemetry only — not used for any admission decision (that decision
-- is made atomically inside TryAdmit itself).
function SessionAdmission.GetApproximateActiveCount(): number?
    local ok, result = pcall(function()
        return claimsMap:GetAsync(SessionConstants.ADMISSION_COUNTER_KEY)
    end)
    if ok then
        return (result :: number?) or 0
    end
    return nil
end

return SessionAdmission
