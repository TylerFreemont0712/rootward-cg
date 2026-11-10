#!/usr/bin/env bash
# Play Rootward: scripts/play.sh, or scripts/play.sh --editor to open the Godot editor on the project instead, or
# scripts/play.sh --lab to open the motion lab (the moves on the motion dummy, ADR-0030).
# The desktop launcher (scripts/install-launcher.sh) runs this. When anything in game/ changed since the last import,
# an import pass runs first (about 3 s), so new art or a new class_name never breaks a launch.
# Godot writes its log to ~/.local/share/godot/app_userdata/Rootward/logs/.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
game="$root/game"
GODOT="${GODOT_BIN:-$(command -v godot || echo "$HOME/godot")}"
if [ -f "$root/media.lock" ] && [ -z "$(find "$game/assets" -name '*.png' -print -quit 2>/dev/null)" ]; then
	echo "No pictures or sound yet (a fresh clone): scripts/fetch-media.sh installs them. Playing without." >&2
fi
stamp="$game/.godot/rootward-imported"
if [ ! -f "$stamp" ] || [ -n "$(find "$game" -path "$game/.godot" -prune -o -newer "$stamp" -type f -print -quit)" ]; then
	"$GODOT" --headless --import --path "$game" < /dev/null > /dev/null 2>&1 || true
	touch "$stamp"
fi
if [ "${1:-}" = "--editor" ]; then
	exec "$GODOT" --path "$game" --editor
fi
if [ "${1:-}" = "--lab" ]; then
	exec "$GODOT" --path "$game" res://tools/motion_lab.tscn
fi
exec "$GODOT" --path "$game"
