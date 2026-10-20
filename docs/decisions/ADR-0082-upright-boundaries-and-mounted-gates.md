# ADR-0082: Upright boundary views and wall-mounted gates

Accepted 2026-10-20. Supersedes ADR-0081's rotated artwork, proximity-opened gates and deferred diagonals.
Its cardinal edge coordinates, independent segments, Build shelves and camera behavior remain the foundation.

## Context

Rotating a horizontal wall picture also rotated its apparent height. Posts and masonry stopped looking upright.
Gate frames moved with their leaves, unrelated nearby walkers triggered opening, and unattached gates looked like
free-standing objects. The player requested a new foundation branch, complete directional sprites, wall attachment,
and explicitly included diagonal placement and collision.

## Decision

- Bake horizontal, vertical, both diagonal views and standalone posts from upright geometry with shared imagegen
  material surfaces. Ship the PNGs and registered origins. Draw native sprites without 90-degree screen rotations.
- Give each gate fixed posts and a separate hinged leaf. Bake both hinges and both swing arcs in every direction,
  for one- and two-unit openings. Flip chooses the opposite hinge. Material comes from the host wall; masonry frames
  carry timber leaves. The material source, exact prompt and baker are retained in `pipeline/world/boundary-foundation/`.
- Keep one pure `BoundaryRules` contract for keys, endpoints, bounds, crossed cells and mounting. A diagonal run
  stores a square size and advances corner to corner. Diagonal walls reserve only the cells they bisect, because
  walkers stand at cell centers. This deliberately trades half-cell navigation for predictable grid movement.
- Install a gate into a complete plain wall run, splitting its remainder, or between two anchored boundary fixtures.
  Protect named/programmed hosts and mixed-material spans. Persist the replaced host art and finish. Removal restores
  inserted wall units. Installation/removal each use one history command; a mounted gate is relocated by reinstalling.
- Query gate admission without opening it, validate the entire step, then request the actual crossing. Idle neighbors
  and parallel steps leave gates closed. Fixed jambs never move. Each jamb and the moving leaf sort independently with walkers; the leaf uses its
  current ground midpoint, while a Sprite2D offset preserves its registered image location. An active crossing holds the opening; programmed
  locks do not receive automatic admission.
- Show a small foundation catalog with explicit direction controls. Keep legacy IDs readable with the new finishes
  and proper old junction masks. Old cell-based placements are not silently migrated to different coordinates.
- Use only the current Sprite2D frame for picking, including flips and source regions. The full animation sheet must
  never become the gate's selectable or collision rectangle. Diagonal editor occupancy indexes individual crossed cells.

## Consequences

Every finish can form an enclosure whose corners and gates meet at the same grid vertices. Old maps retain their
object IDs and programs. Adding a finish uses the shared upright painter, so independent art generations cannot
quietly disagree about post height or gate socket location. Runtime PNG loading is cached; missing images have a
painter fallback. Cardinal edges still leave both neighboring cells available; diagonals have a documented cell cost.

Review and verification commands are in the foundation README. Native closed/open/reversed enclosure and builder
screenshots are saved under `shots/studio/boundary-foundation-*.png`; focused checks cover material/view coverage,
fixed frames, crossing direction, diagonal blocking, wall replacement/restoration and undo.


## Follow-up: direction follows the drag

A chosen axis is the click preference. A deliberate wall drag recomputes horizontal/vertical/both diagonal directions
from the press-to-pointer vector using equal angular sectors and a small jitter dead zone. Committing an inferred
axis does not write it into the next placement template. R can explicitly turn an active gesture. Gates prefer the
actual picked wall sprite or nearest host ground line and fit one/two-unit spans in that host direction; this makes
both diagonal hosts and clicks on their raised artwork usable without manual rotation. Ground anchors and mounting
checks stay shared by preview and commit. Screenshots: `shots/studio/boundary-snapping-{gate,drag}.png`.
