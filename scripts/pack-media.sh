#!/usr/bin/env bash
# Packs the media that changed and publishes it as a GitHub release (ADR-0090). After the art or audio pipeline
# writes new files (git ignores them: they are media), run:
#   scripts/pack-media.sh             what changed since media.lock; exits 1 if the lock is behind the files on disk
#   scripts/pack-media.sh --write     rebuild only the changed packs (in ~/.cache/rootward/media) and rewrite media.lock
#   scripts/pack-media.sh --publish   upload the packs media.lock names that are not on GitHub yet
# Then commit media.lock with the change that needed the new files. Order: --write, commit, push, --publish
# (a release's tag needs the commit on GitHub). Unchanged packs keep their release; nothing is uploaded twice.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
	"") exec python3 "$root/scripts/media.py" status ;;
	--write) shift; exec python3 "$root/scripts/media.py" pack "$@" ;;
	--publish) exec python3 "$root/scripts/media.py" publish ;;
	*) echo "usage: scripts/pack-media.sh [--write [--tag <tag>] [--repo <owner/name>] | --publish]" >&2; exit 2 ;;
esac
