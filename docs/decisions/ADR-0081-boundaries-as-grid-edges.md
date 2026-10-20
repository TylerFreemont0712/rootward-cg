# ADR-0081: Walls and gates occupy tile edges

Accepted 2026-10-20. Supersedes the connected, cell-footprint model in ADR-0080 and ADR-0072.

Artwork, gate triggers and diagonal restrictions superseded by ADR-0082.

## Context

The connector atlas made walls and gates occupy full tile cells. That conflicted with other objects in the same cells,
made gates look offset, and let a new fence stroke silently replace nearby art with posts, corners or junctions. The
Studio also mixed buildings, gates and ordinary props in one Build shelf, and F2 always opened at a map-wide zoom.

## Decision

- A boundary is stored in a map object with `boundary_edge` (`horizontal` or `vertical`), `at` as the first grid
  vertex, and `size` as the run along that edge. JSONC keeps `at` and `size` as two-number arrays; the built map may
  use `Vector2i` values in memory.
- Boundaries occupy the shared edge between cells. They do not reserve either adjacent cell and do not conflict with
  ordinary props there. Walking is blocked when a step crosses a closed boundary edge. The grid's outer outline is a
  valid boundary location.
- A placement creates only the selected segments. It never rewrites existing segments to form a join, corner, post or
  intersection. Users make an outline by placing edges that meet at grid vertices. This leaves each placed piece
  stable and undoable as the action that created it.
- Walls, fences and gates use one boundary placement path. Horizontal and vertical catalog variants choose their
  edge orientation; a drag stays on its starting axis. Boundary objects cannot be resized as ordinary cell footprints.
- The generated boundary atlas supplies eight material styles. A vertical segment or gate uses a clockwise quarter-turn
  of its matching horizontal module, so it spans a full grid edge with the same construction and finish. The placed
  gate and Studio ghost share bounds centered on the edge coordinate; a vertical edge uses `x = at.x * TILE`.
- An automatic gate opens while a Walker approaches or occupies either side of its edge. The opener's facing selects
  the swing side; the incoming side resolves along-edge approaches. An open gate releases its edge collision. Existing
  one- and two-cell gate families remain the supported sizes.
- The Build shelf has three explicit scopes: Buildings, Walls & doors, and Other objects. The active workspace tab has
  a stronger highlight. F2 starts one zoom step wider than Play, while Fit map (and O) deliberately enter the full-map
  overview; zooming or panning from that overview remains available.
- Walls remain cardinal. Diagonal collision is deferred until movement rules can cross diagonal edges consistently.

## Consequences

The map schema, Studio preview, placement checks, pick geometry, town drawing, gate swing and movement collision use
the same edge coordinates. A boundary can sit beside a barrel or crop without taking its cell, and a gate is exactly
one or two edge segments wide. Neighboring art stays unchanged unless the user explicitly edits it. Existing cell-based
boundary placements need conversion to edge coordinates when they are authored or migrated.

The edge review is `shots/studio/edge-boundaries.png`; the generated art and grid review is
`shots/studio/edge-boundaries-redesign.png`; the Build shelf review is `shots/studio/build-walls-doors.png`. Focused
checks cover map schema retention, cell movement, boundary placement and undo, gate orientation/opening, Build shelf
scopes, and F2/Fit map behavior.
