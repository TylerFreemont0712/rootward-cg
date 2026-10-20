# ADR-0080: Shared grid boundaries and opener-facing gate swings

Accepted 2026-10-20. Extends ADR-0072's connected placement and ADR-0074's occupied gate animation.

## Context

The original connected atlas covered only timber fence. New rail, garden, masonry and log pieces kept their own
orientation art, so a fence could meet a gate or wall at a different height or leave gaps at corners. The expanded
catalog also exposed a three-cell gate, and ordinary garden gates were marked solid, so their automatic swing could
not start. Gate art had only one opening direction and its registration differed from the boundary run.

## Decision

- All boundary materials use the same `join: "fence"` topology: four cardinal sockets, one tile footprint, a shared
  40 × 100 source canvas, center joint and ground anchor. Catalog `boundary_style` selects only the material recipe.
  The legacy timber atlas keeps its authored sixteen masks; newer styles are drawn from deterministic palette geometry.
- Painting, gate fitting, map rendering and Studio ghosts read the same socket rules. The town view builds one spatial
  index per join group and resolves all masks in a pass, so a long connected wall does not rescan the full object list
  for each sprite. Mixed materials can meet while retaining their own palette and surface detail.
- Gate catalog footprints are one or two cells, horizontal or vertical. The old three-cell gate is removed from
  catalog and build selection. Gate sockets connect only along the gate's axis; fitting rejects a neighboring branch
  or corner that the opening cannot cover.
- An unlocked gate is walkable at rest and opens when a Walker enters or approaches its footprint. The facing selects
  the opening side when it points across the gate; when the Walker faces along the gate, their side of entry resolves
  the swing. Programmed gates keep their existing lock and state rules.
- Active gate sheets carry two thirteen-frame swing arcs in the registered canvas. `frames_per_direction` and
  `open_sides` describe the arcs in the world index. Both arcs share the same hinges and closed endpoint; gates keep
  one/two-cell collision footprints while their art swings.
- Boundary runs remain four-directional. The map and Walker movement use cardinal steps; diagonal wall strokes need
  explicit diagonal collision and movement semantics before the editor can claim they block diagonal travel.

## Consequences

Each material can join the same rails, posts and gate sockets without hand-authoring sixteen connector images. Exact
socket placement is verified for all eight styles and all sixteen masks. Gate placement and movement use the same
grid footprint, and the screenshot `shots/studio/town-boundaries-after.png` reviews all materials, one-cell gates,
both opening sides and a two-cell gate. Diagonal walls remain a separate design step.
