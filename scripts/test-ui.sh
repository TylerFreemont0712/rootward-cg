#!/usr/bin/env bash
# Run gdUnit4 suites that need a real window (mouse events, viewports: the Studio's scene tests) on a private virtual X
# display, so nothing opens on the desktop. Headless Godot does not carry InputEvents, which is why scripts/test.sh
# fails those suites. The window is 2560x1440, the laptop the tests were written for (TEST_SIZE=1920x1080 for another);
# several tests reach rows that a smaller view does not show. Pass res:// suites or folders; with none, every Studio suite runs.
#   scripts/test-ui.sh res://test/scenes/studio_land_test.gd
set -uo pipefail
cd "$(dirname "$0")/../game"
GODOT="${GODOT_BIN:-godot}"
# SKIP_IMPORT=1 when several runs go side by side and an import pass has just been made.
[ -n "${SKIP_IMPORT:-}" ] || "$GODOT" --headless --import --path . >/dev/null 2>&1 || true
targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
	for file in test/scenes/studio_*_test.gd; do targets+=("res://$file"); done
fi
status=0
for target in "${targets[@]}"; do
	# --remote-debug to a port that is never bound keeps the debugger from waiting on a script error.
	xvfb-run -a -s "-screen 0 ${TEST_SIZE:-2560x1440}x24" "$GODOT" --path . --resolution "${TEST_SIZE:-2560x1440}" -s -d --remote-debug tcp://127.0.0.1:0 \
		res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a "$target" < /dev/null 2>&1 | sed 's/\x1b\[[0-9;]*m//g' \
		| grep -E "^Run Test Suite|FAILED|Overall Summary|Parse Error|SCRIPT ERROR|Expecting|but was|^\s+at '"
	[ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done
exit $status
