--!strict
local RoleConstants = require(script.Parent.Parent.Constants.RoleConstants)

export type Role = RoleConstants.Role
export type SkillId = string

-- ── Persisted player data (DataSystem / ProfileService) ──────────────────

export type PlayerProfileData = {
    role: Role?,
    familyId: string,
    joinedAt: number,
}

-- ── Lobby: family roster + role balancing ─────────────────────────────────

export type FamilyMember = {
    userId: number,
    displayName: string,
    preferredRole: Role?, -- advisory only; RoleBalancingSystem decides the actual assignment
    assignedRole: Role?,
    ready: boolean,
}

export type FamilyRoster = {
    familyId: string,
    accessCode: string, -- TeleportService reserved-server access code, carried Hub -> Lobby -> PlayArea
    members: { [number]: FamilyMember }, -- keyed by userId
}

-- ── PlayArea: mechanisms (doors/locks/generic puzzle triggers) ───────────

export type MechanismState = {
    mechanismId: string,
    requiredRole: Role?,
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

-- ── Content-plugin contracts (see Shared/Registry) ────────────────────────
-- These describe the shape every drop-in content module (Item/Skill/
-- Minigame/Entity/Dialog) is expected to conform to. ContentRegistry only
-- hard-requires an `Id: string` field at runtime; the rest of each shape
-- below is a convention documented here for editor/type-checking support,
-- not enforced structurally, so a system can extend it with a system
-- specific fields without ContentRegistry needing to know about them.

export type SkillDefinition = {
    Id: SkillId,
    DisplayName: string,
    Description: string,
    CooldownSeconds: number,
    -- Executes the skill server-side. `player` is who activated it;
    -- `context` is whatever SkillSystem injects (family roster, current
    -- mechanism state, etc). Must re-validate role ownership itself —
    -- SkillSystem checks role eligibility before calling this, but a skill
    -- that mutates shared state should still guard against misuse.
    Execute: (player: Player, context: { [string]: any }) -> boolean,
}

export type ItemDefinition = {
    Id: string,
    DisplayName: string,
    -- Called when a player interacts with (searches/picks up/uses) a world
    -- instance tagged with this item's Id. Returns true if the interaction
    -- was accepted (state should replicate to the family).
    OnInteract: (player: Player, instance: Instance, context: { [string]: any }) -> boolean,
}

export type MinigameDefinition = {
    Id: string,
    DisplayName: string,
    -- Starts a fresh attempt for one player; returns the FULL state
    -- (including anything secret, e.g. a PIN's correct digits) which
    -- MinigameSystem keeps server-side only and hands back on subsequent
    -- SubmitAttempt calls. Never sent to the client directly.
    Start: (player: Player, context: { [string]: any }) -> { [string]: any },
    -- Validates a submitted attempt against the full state `Start`
    -- returned. Returns (solved: boolean, newFullState: table).
    SubmitAttempt: (
        player: Player,
        state: { [string]: any },
        attempt: any
    ) -> (boolean, { [string]: any }),
    -- Strips the full state down to whatever's safe to send the client for
    -- rendering (e.g. digit count + attempts remaining, never the secret
    -- code itself). Called after both Start and every SubmitAttempt.
    GetPublicState: (state: { [string]: any }) -> { [string]: any },
}

export type EntityDefinition = {
    Id: string,
    DisplayName: string,
    -- Spawns/starts behavior for one instance of this entity (e.g. an NPC
    -- or creature placed in the world via a CollectionService tag).
    OnSpawn: (instance: Instance, context: { [string]: any }) -> (),
}

export type DialogNode = {
    Id: string,
    Text: string,
    Options: { { Text: string, NextNodeId: string? } }?, -- nil/empty Options = terminal node
}

export type DialogTreeDefinition = {
    Id: string,
    DisplayName: string,
    RootNodeId: string,
    Nodes: { [string]: DialogNode },
}

return {}
