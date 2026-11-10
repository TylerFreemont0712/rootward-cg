#!/usr/bin/env bash
# Installs a launcher for this checkout, "Rootward (CG-Small)", in the app menu and on the Desktop. It runs
# scripts/play.sh: an import pass when anything in game/ changed, then the game from source, so a change is one
# double-click away. Right-click it for "Open in the Godot editor" or "Play the last build" (build/stage/linux/).
#   scripts/install-launcher.sh            install, or reinstall after moving the repo
#   scripts/install-launcher.sh --remove   take it away again
# Every checkout keeps its own launcher: LAUNCHER_ID and LAUNCHER_NAME name this one differently, and other Rootward
# launchers (the original project's "Rootward (Godot)", an installed game) are left alone. The icon is the game's emblem
# with a "CG" tab so it stands apart from them. On Cinnamon it goes to the Desktop's top-right corner.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
id="${LAUNCHER_ID:-rootward-cg-small}"
name="${LAUNCHER_NAME:-Rootward (CG-Small)}"
apps="$HOME/.local/share/applications"
icons="$HOME/.local/share/icons/hicolor/256x256/apps"
desktop="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
# LEARN: a gio from Homebrew (or any GLib without the system's GVFS module) cannot write file metadata, and fails with
# "not supported": the desktop's own /usr/bin/gio can, so it goes first.
gio_bin="$(command -v /usr/bin/gio || command -v gio || echo gio)"

# LEARN: Cinnamon's desktop is drawn by nemo-desktop. It keeps each file icon's place in the file's GIO metadata
# ("x,y", the top left of its grid cell) and the desktop's own mode in ~/.config/nemo/desktop-metadata. With
# auto-arrange on it ignores stored places, and it rewrites every place when it quits, so the order is: stop it, turn
# auto-arrange off (the other icons keep where they are), write the place, start it again.
place_top_right() { # desktop file
	local file="$1" config="$HOME/.config/nemo/desktop-metadata" now width cell_x
	pgrep -x nemo-desktop > /dev/null || return 0
	width="$(xdpyinfo 2> /dev/null | awk '/dimensions:/ {split($2, size, "x"); print size[1]; exit}')"
	# Nemo's grid at the standard zoom: cells 130 pixels wide from x = 86, 100 tall from y = 8.
	cell_x=$((86 + ((${width:-1920} - 86 - 134) / 130) * 130))
	nemo-desktop --quit 2> /dev/null || true
	for _ in $(seq 1 25); do pgrep -x nemo-desktop > /dev/null || break; sleep 0.2; done
	now="$(date +%s)"
	if [ -f "$config" ] && grep -q '^nemo-icon-view-auto-layout=true' "$config"; then
		sed -i "0,/^nemo-icon-view-auto-layout=true/s//nemo-icon-view-auto-layout=false/" "$config"
		sed -i "0,/^nemo-icon-view-layout-timestamp=.*/s//nemo-icon-view-layout-timestamp=$now/" "$config"
		echo "Turned the desktop's Auto-arrange off so the icon can stay in the corner (right-click the desktop to turn it back on)."
	fi
	"$gio_bin" set "$file" metadata::nemo-icon-position "$cell_x,8"
	"$gio_bin" set "$file" metadata::nemo-icon-position-timestamp "$((now + 5))"
	sleep 1
	# The session may start it again by itself; if not, start it detached from this shell.
	pgrep -x nemo-desktop > /dev/null || (setsid nemo-desktop > /dev/null 2>&1 < /dev/null &)
}

if [ "${1:-}" = "--remove" ]; then
	rm -f "$apps/$id.desktop" "$desktop/$id.desktop" "$icons/$id.png"
	update-desktop-database "$apps" 2> /dev/null || true
	echo "Removed the $name launcher."
	exit 0
fi

chmod +x "$root/scripts/play.sh"
mkdir -p "$apps" "$icons"

# The icon: the emblem with a small amber "CG" tab in its lower right corner (Pillow, from the pipeline's environment).
# Without the media or the pipeline, the plain emblem, or Godot's own icon, will do.
emblem="$root/game/assets/brand/icon-256.png"
icon="$icons/$id.png"
if [ -f "$emblem" ] && command -v uv > /dev/null 2>&1 && uv run --quiet --project "$root/pipeline" python - "$emblem" \
	"$root/game/ui/fonts/cinzel.ttf" "$icon" << 'PY' 2> /dev/null; then
import sys
from PIL import Image, ImageDraw, ImageFont
emblem, font_path, out = sys.argv[1:4]
image = Image.open(emblem).convert("RGBA").resize((256, 256), Image.LANCZOS)
draw = ImageDraw.Draw(image)
box = (140, 178, 252, 250)
draw.rounded_rectangle(box, radius=14, fill=(18, 14, 10, 245), outline=(242, 165, 65, 255), width=4)
font = ImageFont.truetype(font_path, 44)
left, top, right, bottom = draw.textbbox((0, 0), "CG", font=font)
x = (box[0] + box[2] - (right - left)) / 2 - left
y = (box[1] + box[3] - (bottom - top)) / 2 - top
draw.text((x, y), "CG", font=font, fill=(242, 165, 65, 255))
image.save(out)
PY
	:
elif [ -f "$emblem" ]; then
	cp "$emblem" "$icon"
else
	icon="$root/game/icon.svg"
fi

entry="$apps/$id.desktop"
cat > "$entry" << EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
GenericName=Programming Roguelike
Comment=Play Rootward from this checkout ($root): every spell is real code
Exec="$root/scripts/play.sh"
Path=$root
Icon=$icon
Terminal=false
StartupNotify=true
Categories=Game;
Keywords=rootward;roguelike;programming;godot;cg;
Actions=Editor;Build;

[Desktop Action Editor]
Name=Open in the Godot editor
Exec="$root/scripts/play.sh" --editor

[Desktop Action Build]
Name=Play the last build (build/stage/linux)
Exec="$root/build/stage/linux/Rootward.x86_64"
EOF
chmod +x "$entry"
update-desktop-database "$apps" 2> /dev/null || true

if [ -d "$desktop" ]; then
	cp "$entry" "$desktop/$id.desktop"
	chmod +x "$desktop/$id.desktop"
	# Desktops that ask before running a launcher (GNOME, Nemo) accept one marked as trusted.
	"$gio_bin" set "$desktop/$id.desktop" metadata::trusted true 2> /dev/null || true
	place_top_right "$desktop/$id.desktop"
fi
echo "Installed \"$name\": $entry${desktop:+, and on the Desktop}"
