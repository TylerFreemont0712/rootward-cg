# ADR-0090: Media lives in release packs, not in git

Accepted 2026-11-10 on the player's word, for the experimental slim copy (`rootward-cg`): *"I want to have it so that
this version is able to be downloaded from github with as little of a initial download as possible … the github clone
would be <100 mb … the superfluous information or models or data … can be done separately from the initial github
clone download."*

## Context

After ADR-0089 the repository's history still held about 600 MB, and a checkout about 550 MB. Almost all of it was
media: 842 files (PNG, JPEG, WebP, Ogg, glTF) of 533 MB. The code, content, tests and docs are about 20 MB. The
game already treats every picture and sound as optional (AGENT.md: "Assets are optional"): nothing preloads a file
under `res://assets/`, and every lookup goes through `ResourceLoader.exists` with a drawn or silent fallback.

Options:

1. **Git LFS.** Pointers in git, files on GitHub's LFS store. The free plan's LFS storage and monthly bandwidth are
   small enough that a few fresh clones of 350 MB would exhaust them, it needs `git-lfs` on every machine, and
   rewriting history into LFS still leaves the pointers' churn. Not free in the way the player's asset rule asks for.
2. **Shallow or partial clones** (`--depth 1`, `--filter=blob:none`). Each person cloning has to know the flags;
   a plain `git clone` is still huge. It fixes nothing for the repository itself.
3. **A second repository for media**, as a submodule. Two histories to keep in step, and a submodule a plain clone
   leaves empty anyway.
4. **Packs on GitHub releases, pinned by a lock file in git.** Release assets do not count against the repository's
   size or an LFS quota, each may be up to 2 GB, and a private repository's releases are as private as its code.

## Decision

Option 4.

1. **What media is:** one block at the top of `.gitignore` (`# >>> media` … `# <<< media`) ignores the media
   extensions everywhere, except the addons (as their authors ship them) and the four README screenshots
   (`docs/images/rootward-*`). The small text files beside the media stay in git: `music.json`, sprite `clips.json`,
   sheet `.json` and the SVGs. A media file's `.import` sidecar travels **with it, in the pack**: it holds the
   picture's UID and import settings (an Ogg's loop points), and Godot's `ResourceLoader.exists()` answers true for
   any path with a `.import` file, so a sidecar without its picture would turn every quiet fallback into a failed
   `load()` and an error in the log. (Measured: a clone that kept them logged two errors per missing picture.)
2. **`media.lock`** (committed, tab separated) names the repository, each pack (release tag, SHA-256, size) and each
   file (pack, SHA-256, size, path). Every commit therefore says exactly which media it expects, as LFS pointers
   would, but in one file.
3. **Packs are folders:** `assets-<dir>` for `game/assets/<dir>/`, `game-<dir>` for the rest of `game/` (the game
   uses these), and `dev-<dir>` for top-level folders (concept boards, pipeline sources, research figures: only for
   making things). A change to the foes' art rebuilds and re-uploads `assets-foes` alone, and a fetch downloads only
   packs with a file missing or stale. Tars are deterministic (sorted, zero times and owners) and uncompressed:
   PNG and Ogg are already compressed, and zstd saved 2%.
4. **Scripts** (`scripts/media.py`, stdlib Python, behind two wrappers): `scripts/fetch-media.sh [game|dev|all|<pack>]`
   installs from the release through `gh` (or `ROOTWARD_MEDIA_FROM`, a folder of packs), checks every pack and file
   against the lock, and writes only to the paths the lock names. It remembers what it installed (inside `.git`), so
   a picture the player changed since is kept unless `--force`. `scripts/pack-media.sh` reports what changed,
   `--write` rebuilds the changed packs into `~/.cache/rootward/media/` and rewrites the lock under a new release tag,
   `--publish` uploads what the release lacks.
5. **History is rewritten** (git filter-repo) so no commit carries a media file; the first release, `media-1`, holds
   the media of the last commit. The history before the split stays in the original repository and in the local
   ref `pre-media-split` of the copy it was made from.

## Consequences

- A clone is small (measured when this was done: see `docs/PLAN.md`), and the game launches and its tests run
  from it without any media. `scripts/fetch-media.sh` (about 350 MB) brings the art and sound.
- New art or audio is invisible to `git status`: after the pipeline writes files, `scripts/pack-media.sh` shows
  them, and the commit that needs them carries the new `media.lock`. Forgetting this leaves a commit whose lock
  names old media; the files on the machine that made them are unaffected.
- Old commits never had their media in git after the rewrite; only the media of `media-1` onwards is fetchable.
- A screenshot added to the docs needs a name under `docs/images/rootward-*` to stay in git, or it becomes media.
- The repository is private, so a fetch needs `gh auth login` (or the packs copied by hand).
