class_name TestWorld
extends RefCounted
## A small world for the tests of engine features that the game's own content no longer uses (ADR-0087): things that
## take code, and the old parts' tasks. The real world, plus one map, `things-yard`, with a gate and a signpost that each
## take code (files in test/fixtures/things/), and, when asked, a task of the old curriculum (test/fixtures/old_tasks/).
## They go in through the same drafts the Studio plays (OverworldContent.load_world's second argument), so they pass the
## checks real content does, and nothing under content/ is touched.
##
##   OverworldScreen._catalog_cache = TestWorld.catalog()      # in before_test; the screen then walks the yard
##   var state := OverworldState.fresh(TestWorld.YARD, TestWorld.BY_GATE, "up", BootsCode.PYTHON)

const YARD := "things-yard"
const GATE := "cabbage-gate"
const SIGN := "crossroads-sign"
const WIDTH := 20
const HEIGHT := 16
## The gate's west tile (it is two wide), and the signpost.
const GATE_AT := Vector2i(4, 10)
const SIGN_AT := Vector2i(11, 5)
## Where the player stands to face each, looking up. Both are open grass.
const BY_GATE := Vector2i(4, 11)
const BY_SIGN := Vector2i(11, 6)
const THINGS_DIR := "res://test/fixtures/things"
const TASKS_DIR := "res://test/fixtures/old_tasks"


## The map: open grass, the gate across a path at the south and the signpost in the middle.
static func yard() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {
		"id": YARD, "name": "Things yard", "legend": {".": "grass"}, "ground": rows,
		"start": [BY_GATE.x, BY_GATE.y], "facing": "up",
		"objects": [
			{
				"kind": "prop", "art": "gate-wide-2", "at": [GATE_AT.x, GATE_AT.y], "size": [2, 1], "id": GATE,
				"solid_unless": "open",
				"program": {"hook": "on_use", "fields": {"open": {"type": "bool", "default": false}}},
			},
			{
				"kind": "prop", "art": "signpost", "at": [SIGN_AT.x, SIGN_AT.y], "id": SIGN,
				"text": "The Archive. The square. Home. Pick a road.",
				"program": {"hook": "on_use", "fields": {}},
			},
		],
	}


## The drafts that put the yard and its two things into the world, and the old tasks named (the files in TASKS_DIR):
## file path -> data (a starter is its text).
static func drafts(tasks: Array[String] = []) -> Dictionary:
	var base := ContentLoader.ROOT.path_join("packs/core/overworld")
	var out := {base.path_join("maps/%s.jsonc" % YARD): yard()}
	for id: String in [GATE, SIGN]:
		var thing := Jsonc.parse_file(THINGS_DIR.path_join("%s.jsonc" % id))
		assert(thing.ok, "the fixture thing %s should parse" % id)
		out[base.path_join("things/%s.jsonc" % id)] = thing.value
		for extension: String in OverworldContent.STARTERS.values():
			var starter := "%s.starter.%s" % [id, extension]
			out[base.path_join("things").path_join(starter)] = FileAccess.get_file_as_string(THINGS_DIR.path_join(starter))
	for id: String in tasks:
		var task := Jsonc.parse_file(TASKS_DIR.path_join("%s.jsonc" % id))
		assert(task.ok, "the fixture task %s should parse" % id)
		out[base.path_join("tasks/%s.jsonc" % id)] = task.value
		for extension: String in OverworldContent.STARTERS.values():
			var starter := "%s.starter.%s" % [id, extension]
			out[base.path_join("tasks").path_join(starter)] = FileAccess.get_file_as_string(TASKS_DIR.path_join(starter))
	return out


## The catalog of the real world with the yard and its things in it, and the old tasks named. A new Dictionary, not the
## screen's cache.
static func catalog(tasks: Array[String] = []) -> Dictionary:
	var loaded := OverworldContent.load_world(ContentLoader.ROOT, drafts(tasks))
	for diagnostic: Dictionary in loaded.diagnostics:
		if String(diagnostic.get("severity", "")) == "error":
			push_error(ContentLoader.describe(diagnostic))
	return loaded.catalog


## Puts the yard and its two things into a copy of the content (`content_dir` holds packs/), for the tests that edit a copy
## and load it themselves: the map as the Studio would write it, and the things' files beside it.
static func install(content_dir: String) -> void:
	var base := content_dir.path_join("packs/core/overworld")
	assert(StudioFiles.write_content(base.path_join("maps/%s.jsonc" % YARD), JsoncWriter.map_text("// Test world\n", yard())))
	DirAccess.make_dir_recursive_absolute(base.path_join("things"))
	for name: String in DirAccess.get_files_at(THINGS_DIR):
		if name.get_extension() in ["jsonc", "py", "js"]:
			assert(DirAccess.copy_absolute(THINGS_DIR.path_join(name), base.path_join("things").path_join(name)) == OK)
