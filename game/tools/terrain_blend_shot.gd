extends Node2D
## Deterministic material contacts, rendered by the real GroundLayer rather than a hand-composited art sheet.

const LEGEND := {
	".": "grass", "a": "meadow", "b": "dry_grass", "c": "forest_floor", "d": "moss",
	"e": "soil", "g": "tilled_soil", "h": "sand", "i": "gravel", "j": "brick_path",
	"k": "stone_path", "l": "wood_path", "m": "root_floor", "n": "fern_moss",
	"o": "glow_moss", ",": "path", "=": "cobble", "~": "water", "*": "flowers",
}


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#211f2a")
	background.size = Vector2(4096, 4096)
	add_child(background)
	var title := Label.new()
	title.text = "Lanternroot / terrain contacts"
	title.position = Vector2(60, 15)
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)
	var terrain: Dictionary = OverworldContent.load_world().catalog.terrain
	if OS.get_environment("ROOTWARD_TERRAIN_SHOT") == "angles":
		_panel("Dirt on meadow / bends, forks and diagonals", Vector2(60, 110), _route_rows("a", ","), terrain)
		_panel("Brick on forest floor / varied road widths", Vector2(1020, 110), _route_rows("c", "j"), terrain)
		_panel("Stone on sand / connected interiors", Vector2(60, 620), _route_rows("h", "k"), terrain)
		_panel("Wood on moss / exposed edge bands", Vector2(1020, 620), _route_rows("d", "l"), terrain)
		return
	_panel("Meadow, grass and connected paths", Vector2(60, 110), [
		"..........aaaaaaaaaaa", "aaaaaaaaaaaaaaaaaaaaa", "aa,,,,,,,,,,,,,,,,,aa",
		"aaaaaa,,,,aaaaaaaaaaa", "aajjjjjjjjjjjjjjjjjaa", "aaaaaaaaaaaaaaaaaaaaa",
		"aakkkkkkkkkkkkkkkkkaa", "aaaaaaaaalllaaaaaaaaa", "aalllllllllllllllllaa",
	], terrain)
	_panel("Woodland grounds and roads", Vector2(1020, 110), [
		"cccccccdddddddmmmmmmm", "cccccccdddddddmmmmmmm", "cc,,,,,,,,,,,,,,,,,mm",
		"cccccccdddddddmmmmmmm", "nnnnnnnooooooommmmmmm", "nnjjjjjjjjjjjjjjjjjmm",
		"nnnnnnnooooooommmmmmm", "nnnnnnnooooooommmmmmm", "nnkkkkkkklllllll===mm",
	], terrain)
	_panel("Neighbouring materials and four-way junctions", Vector2(60, 620), [
		"aaaaaaabbbbbbbhhhhhhh", "aaaaaaabbbbbbbhhhhhhh", "aaaaaaabbbbbbbhhhhhhh",
		"aaaaaaabbbbbbbhhhhhhh", "eeeeeeegggggggiiiiiii", "eeeeeeegggggggiiiiiii",
		",,,,,,,jjjjjjjkkkkkkk", ",,,,,,,jjjjjjjkkkkkkk", ",,,,,,,jjjjjjjkkkkkkk",
	], terrain)
	_panel("Water against several banks", Vector2(1020, 620), [
		"aaaaaaahhhhhhheeeeeee", "aaaaaaahhhhhhheeeeeee", "aaaaaaahhhhhhheeeeeee",
		"aaaa~~~~~~~~~~~~~eeee", "aaa~~~~~~~~~~~~~~~eee", "aaa~~~~~~~~~~~~~~~eee",
		"cccc~~~~~~~~~~~~~mmmm", "cccccccdddddddmmmmmmm", "cccccccdddddddmmmmmmm",
	], terrain)


func _panel(caption: String, at: Vector2, rows: Array, terrain: Dictionary) -> void:
	var label := Label.new()
	label.text = caption
	label.position = at - Vector2(0, 44)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	var built := OverworldMap.build({
		"id": "terrain-review", "name": "Terrain review", "legend": LEGEND,
		"ground": rows, "objects": [], "start": [0, 0],
	}, terrain)
	assert(built.errors.is_empty(), str(built.errors))
	var ground := GroundLayer.new()
	ground.position = at
	add_child(ground)
	ground.show_map(built.map)
	ground.set_process(false)


func _route_rows(base: String, road: String) -> Array:
	var rows: Array = []
	for y in 9:
		rows.append(base.repeat(21))
	var cells := {}
	# One-cell loop and branches, a three-wide approach, diagonal stairs, and isolated diagonal contacts.
	for x in range(2, 10):
		cells[Vector2i(x, 1)] = true
		cells[Vector2i(x, 6)] = true
	for y in range(1, 7):
		cells[Vector2i(2, y)] = true
		cells[Vector2i(9, y)] = true
	for y in range(3, 6):
		for x in range(9, 15):
			cells[Vector2i(x, y)] = true
	for step in 6:
		cells[Vector2i(14 + step, 6 - step)] = true
		cells[Vector2i(14 + step, 7 - step)] = true
	cells[Vector2i(5, 3)] = true
	cells[Vector2i(6, 4)] = true
	for cell: Vector2i in cells:
		var row := String(rows[cell.y])
		rows[cell.y] = row.substr(0, cell.x) + road + row.substr(cell.x + 1)
	return rows
