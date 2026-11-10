# The plan

Rootward 1.0.0 is the starting point (2026-11-10): the card game alone, playable without Godot on Linux and Windows
through Rootward Setup. Everything before it is in git at the tag `archive/pre-v1.0` (the full ADRs, the old plan
with its phases, research and concept boards); `docs/DECISIONS.md` keeps one line per decision.

Each step ends with tests green, screenshots of anything visible, this file ticked, and a commit.

## 1.0.0 (done)

- [x] Media out of git (ADR-0090): a clone is about 40 MB; `scripts/fetch-media.sh` brings the pictures and sound.
- [x] Cleanup: old docs, plans, research, concept boards and 22 unused pictures removed (the game's media went from
      533 MB to 377 MB with the dev sources, 327 MB for the game).
- [x] Builds for Linux and Windows (ADR-0091) with the sandbox beside the game, compiled for each system; `--self-test`.
- [x] Rootward Setup for both systems: download with progress, SHA-256 checks, shortcuts, Apps entry, update, repair,
      uninstall, silent mode. Tested end to end on Linux; on Windows by `.github/workflows/windows-check.yml`.

## Next

- [ ] **Where public downloads live.** The repository is private, so the installer installs only from files beside it.
      Choose: a public repository holding only the release files, the source made public, or offline installs only.
      Before anything is public: itemised credits for the CC-BY and OGA-BY sounds, and the AI models' licences
      (`docs/ASSET_LICENCES.md`; YuE's music weights are CC BY-NC).
- [ ] A known failing test: ten program cards have no upgrade (`program_upgrades_test`).
- [ ] The dormant 3D character stack (VRM and MToon addons, the move library, `pipeline/moves`, `pipeline/blender`): no
      3D skin ships since ADR-0089. Remove it, or bring a 3D skin back.
- [ ] Code signing for Windows (free options only, the player's rule; otherwise players keep clicking "Run anyway").
- [ ] A smaller Windows installer: a zip around it, or a Godot export template built without 3D.
