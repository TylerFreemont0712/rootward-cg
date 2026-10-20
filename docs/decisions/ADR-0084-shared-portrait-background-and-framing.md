# ADR-0084: Shared portrait background and grounded framing

Accepted 2026-10-20.

## Context

Some v0.5 avatars are transparent cutouts, while others have painted backgrounds. Several cutouts have enough
transparent lower padding that their cropped torsos appear raised in portrait windows. Dialogue also animated a
TextureRect inside a PanelContainer back to y=0, overriding the container's six-pixel padding after a happy hop.

## Decision

- Keep source cutouts intact. Generate one reusable, blurred village background, retain its source and exact prompt,
  and import a 512 × 512 runtime copy. Apply it centrally through `OverworldArt.portrait()`.
- More than 5% sampled transparency identifies cutouts; this tolerates small rounded or antialiased corners on
  otherwise complete paintings. Opaque portraits retain their original texture and composition.
- Frame a cutout using its visible alpha bounds, preserve its aspect and full silhouette, allow 4% headroom and
  anchor the visible bottom to the canvas bottom. Cache the composed texture by source/background texture identity.
- Use an opaque sage background when the shared picture is absent. A missing portrait retains the existing null
  fallback. Raw portraits and high-quality concept avatars are never overwritten by composition.
- Animate dialogue slide/hop offsets on the outer frame and combine them with its live layout baseline. The
  PanelContainer owns the child margins. Cancel/reset motion on replacement, interruption and reduced motion.

## Consequences

Every existing portrait consumer gets consistent backgrounds and shoulder alignment, with one composition per
cached texture. New transparent portraits automatically participate without per-character metadata. A future portrait
with substantial intentional transparent decoration will need an explicit override if it should retain that space.
Painted portraits remain authored compositions; this does not change their crop or repaint their backgrounds.

The reusable source, prompt, importer and native review commands are documented in
`Concept/v0.5/characters/portrait-backdrop/README.md`. Focused tests cover image preservation, framing, caching,
missing background art, layout ownership, resize, interruption and reduced motion.
