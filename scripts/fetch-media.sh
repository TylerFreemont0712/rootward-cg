#!/usr/bin/env bash
# Installs Rootward's media (pictures, sound, models) from the packs on the repository's GitHub releases (ADR-0090).
#   scripts/fetch-media.sh            what the game shows and plays (the `game` packs, about 330 MB)
#   scripts/fetch-media.sh dev        the pipeline's sources too (the `dev` packs)
#   scripts/fetch-media.sh all        everything; or name packs: scripts/fetch-media.sh assets-foes assets-audio
#   scripts/fetch-media.sh --status   what is installed, missing or changed; installs nothing
#   --force                           also replace files changed here since they were fetched
# Every pack and file is pinned by SHA-256 in media.lock. Safe to re-run; it only fetches what is missing or stale.
# Downloads come straight from the public releases (the GitHub CLI is used only if that fails). Offline, point
# ROOTWARD_MEDIA_FROM at a folder holding the packs (`<pack>.tar`, or a cache's `<pack>-<hash>.tar`).
# The game runs without any of it: every picture and sound has a fallback.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--status" ]; then
	exec python3 "$root/scripts/media.py" status
fi
exec python3 "$root/scripts/media.py" fetch "$@"
