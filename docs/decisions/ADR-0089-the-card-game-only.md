# ADR-0089: The card game only

Accepted 2026-11-07 on the player's word: *"I want to really slim down this game to just the card game piece … delete
the 3d models … delete and purge anything that is associated with 'the road' … keep the current vesper 1.0 1.5 and
2.0. The motions and things like that can stay for now … we're going to use more 2d assets throughout the game."*
Supersedes ADR-0055, ADR-0061 to ADR-0066, ADR-0068 to ADR-0074 and ADR-0076 to ADR-0088 (all removed).

## Context

The title had two launches: Adventure (the Shardrun, Spellforge and the card run) and **The Road** (Lanternroot, then
Kindle Hollow, Pebblebrook and the Studio, the open-world RPG). The Road was ported to its own project
(`~/personal-project/Voxel-Rootward`). This repository is to be used for an evaluation task, which needs the
GitHub repository under 1 GB. Its history held about 900 MB, most of it world art, concept boards and 3D models.
Some of the 3D models (a VRoid model, portraits of third-party reference skins) were also unsafe to keep in a
public repository.

## Decision

1. **The Road is gone from the working tree:** `core`, `scenes`, `content` and `sandbox` folders for `lanternroot`,
   `overworld` and `studio`; `assets/overworld`; the town's music, locales, tests, fixtures, tools and screenshot
   scenes; `pipeline/world`, `pipeline/pixel`, `pipeline/animation`; `scripts/world.sh`, `pixel.sh`, `cast.sh`,
   `animation.sh`; the `Concept/v0.*` boards and the town's prototypes; the Road's ADRs and plan sections. The title
   has one launch, Adventure, and Settings has no Developer (Studio) tab.
2. **No 3D models ship:** Emberfox, Shibu (VRM) and the motion dummy, their portraits, the portraits of the local
   reference skins, the Blender scripts that built Vesper in 3D and `scripts/character.sh`. The skins are
   `vesper`, `vesper-v1-5` and `vesper-v2`, all sprite sheets. The move library (`game/characters/moves/`,
   `pipeline/moves/`), the 3D character code (`StageCharacter`, the anime shaders) and the VRM addons stay for now;
   with no model on disk a 3D skin falls back to the drawn placeholder, as before.
3. **History is rewritten** (git filter-repo) so no commit carries the removed paths, and `main` is force-pushed.
   The full history before the rewrite is kept outside the repository in
   `~/personal-project/Rootward-backup-2026-11-07/rootward-all-refs.bundle`.

## Consequences

- Old commits no longer build as they did: the removed files are absent from every commit.
- Tests that only measured the 3D models (Emberfox import, VRM clips, anime restyle) were removed; the rehearsal and
  hero tests now run on the Vesper sprite skins.
- New art for this repository is 2D, for one consistent look.
