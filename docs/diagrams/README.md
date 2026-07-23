# Diagrams

Standalone diagram set extracted from [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
for presenting to the team without the full technical prose. Each file is
self-contained (a short caption + the diagram); the numbering matches the
order they're referenced in the architecture doc.

0. [Whole-system overview](00-system-overview.md) — Figure 0, the single-glance opener
1. [Place topology](01-place-topology.md) — Hub → Lobby → PlayArea
2. [Loose coupling](02-loose-coupling.md) — PluginRegistry boot flow
3. [Component structure](03-component-structure.md) — Systems/Controllers per place (UML component diagrams — pages 11–13 in the `.drawio` file — are the authoritative version; this page also has an informal quick-reference)
4. [Data flow](04-data-flow.md) — 4 sequence diagrams, join through win
5. [Session admission](05-session-admission.md) — the race condition and its fix

A rendered, presentation-friendly version of all diagrams (this set, laid
out for screen-sharing) is published at:
<https://claude.ai/code/artifact/096aa660-8bfd-4840-a88a-dd245177f336>

## draw.io / diagrams.net export

[`drawio/jatinangor-architecture.drawio`](drawio/jatinangor-architecture.drawio)
is the same 11 diagrams (Figure 0 through Figure 10) as one multi-page
draw.io file — open it at <https://app.diagrams.net> (File → Open From →
Device) or in the draw.io desktop app, and every figure is a separate page
tab you can edit, re-theme, or drop into a slide deck. Plain uncompressed
XML, so it also diffs reasonably in PRs if someone touches it.
