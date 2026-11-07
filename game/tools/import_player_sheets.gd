extends SceneTree
## Slice complete authored figures into one runtime texture. No poses or anatomy are synthesized.

const FACINGS: Array[String] = ["down", "up", "left", "right"]
const FRAME := Vector2i(64, 96)
const GROUND := 93
const CELL_STEP_COLUMNS: Array[int] = [0, 0, 1, 0, 2, 3, 4, 0, 5, 6, 7, 0]

var _root := ""
var _report: Dictionary = {}
var _outputs: Dictionary = {}
var _failed := false


func _initialize() -> void:
	_root = ProjectSettings.globalize_path("res://..")
	var config_path := _root.path_join("pipeline/animation/player_sources.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("models", null) is Dictionary:
		_fail("Invalid player source manifest: " + config_path)
		return
	var config: Dictionary = parsed
	for model: String in config.models:
		var entry: Dictionary = config.models[model]
		if entry.has("source"):
			_import_cell_model(model, entry, config)
		else:
			_import_legacy_model(model, entry, config)
		if _failed:
			return
	if config.has("commander"):
		_import_commander(config.commander)
		if _failed:
			return
	# Validate every source and registered frame before replacing any runtime picture.
	for path: String in _outputs:
		_save(_outputs[path], path)
		if _failed:
			return
	var report_path := _root.path_join(String(config.get(
		"registration_report", "Concept/v0.3/animation/player/registration.json"
	)))
	var directory_error := DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if directory_error != OK:
		_fail("Could not create registration report directory: " + error_string(directory_error))
		return
	var report := FileAccess.open(report_path, FileAccess.WRITE)
	if report == null:
		_fail("Could not write registration report: " + report_path)
		return
	report.store_string(JSON.stringify(_report, "  ") + "\n")
	quit()


func _import_cell_model(model: String, entry: Dictionary, config: Dictionary) -> void:
	var source_path := String(entry.source)
	var grid: Array = entry.get("source_grid", config.get("source_grid", [8, 4]))
	if grid.size() != 2 or int(grid[0]) != 8 or int(grid[1]) != FACINGS.size():
		_fail("%s: cell-step source must have 8 columns and 4 directional rows" % model)
		return
	var row_edges: Array = entry.get("source_row_edges", [])
	var cells := _load_cells(source_path, 8, FACINGS.size(), row_edges)
	if _failed:
		return
	var mapping: Array = config.get("runtime_source_columns", CELL_STEP_COLUMNS)
	if mapping.size() != 12:
		_fail("%s: runtime_source_columns must declare all 12 runtime columns" % model)
		return
	for column: Variant in mapping:
		if int(column) < 0 or int(column) >= 8:
			_fail("%s: source column %s is outside the 8-column source" % [model, column])
			return
	var neutrals: Array[Image] = []
	for row in FACINGS.size():
		neutrals.append(cells[row * 8])
	var scale_factor := _scale_for(neutrals, float(config.get("player_height", 84)))
	var sheet := Image.create_empty(FRAME.x * 12, FRAME.y * FACINGS.size(), false, Image.FORMAT_RGBA8)
	var anchors: Dictionary = {}
	for row in FACINGS.size():
		var neutral := _scaled(cells[row * 8], scale_factor)
		var used := neutral.get_used_rect()
		var head_x := _head_center(neutral)
		var offset := Vector2i(roundi(FRAME.x / 2.0 - head_x), GROUND - used.end.y)
		anchors[FACINGS[row]] = {
			"neutral_source_column": 0,
			"scaled_head_center_x": head_x,
			"scaled_ground_row": used.end.y,
			"offset": [offset.x, offset.y],
		}
		var registered: Array[Image] = []
		for column in 8:
			var label := "%s/%s source column %d" % [model, FACINGS[row], column]
			registered.append(_pack_frame(_scaled(cells[row * 8 + column], scale_factor), offset, label))
			if _failed:
				return
		for column in mapping.size():
			sheet.blit_rect(registered[int(mapping[column])], Rect2i(Vector2i.ZERO, FRAME), Vector2i(column * FRAME.x, row * FRAME.y))
	_report[model] = {
		"source": source_path,
		"source_grid": grid,
		"source_row_edges": row_edges,
		"rows": FACINGS,
		"source_columns": config.get("source_columns", []),
		"runtime_source_columns": mapping,
		"scale": scale_factor,
		"target_height": config.get("player_height", 84),
		"frame": [FRAME.x, FRAME.y],
		"ground": GROUND,
		"anchors": anchors,
	}
	_outputs["res://assets/overworld/player/" + model + ".png"] = sheet


## Retain the older per-direction 4 x 3 source schema for rebuilding archived sheets.
func _import_legacy_model(model: String, entries: Dictionary, config: Dictionary) -> void:
	var sheet := Image.create_empty(FRAME.x * 12, FRAME.y * FACINGS.size(), false, Image.FORMAT_RGBA8)
	for row in FACINGS.size():
		var way := FACINGS[row]
		if not entries.has(way):
			_fail("%s: missing source for direction %s" % [model, way])
			return
		var entry: Dictionary = entries[way]
		var cells := _load_cells(String(entry.source), 4, 3)
		if _failed:
			return
		var scale_factor := _scale_for(cells.slice(8, 12), float(config.get("player_height", 84)))
		var flip: Array[int] = []
		for value: Variant in entry.get("flip_frames", []):
			flip.append(int(value))
		for index in cells.size():
			if flip.has(index):
				cells[index].flip_x()
			var frame := _registered(cells[index], scale_factor, "%s/%s source column %d" % [model, way, index])
			if _failed:
				return
			var column := index - 8 if index >= 8 else index + 4
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(column * FRAME.x, row * FRAME.y))
		_report[model + "/" + way] = {"source": entry.source, "scale": scale_factor, "flip_frames": flip}
	_outputs["res://assets/overworld/player/" + model + ".png"] = sheet


func _import_commander(officer: Dictionary) -> void:
	var cells := _load_cells(String(officer.source), 4, 2)
	if _failed:
		return
	var sheet := Image.create_empty(FRAME.x * 2, FRAME.y * FACINGS.size(), false, Image.FORMAT_RGBA8)
	for row in FACINGS.size():
		var pair: Array[Image] = [cells[row], cells[row + 4]]
		var scale_factor := _scale_for(pair, float(officer.height))
		for column in 2:
			var frame := _registered(pair[column], scale_factor, "commander/%s column %d" % [FACINGS[row], column])
			if _failed:
				return
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, FRAME), Vector2i(column * FRAME.x, row * FRAME.y))
	_outputs[String(officer.output)] = sheet


func _load_cells(path: String, columns: int, rows: int, row_edges: Array = []) -> Array[Image]:
	var absolute := _root.path_join(path)
	if not FileAccess.file_exists(absolute):
		_fail("Missing sprite source: " + path)
		return []
	var source := Image.load_from_file(absolute)
	if source == null or source.is_empty():
		_fail("Could not decode sprite source: " + path)
		return []
	if source.get_width() < columns or source.get_height() < rows:
		_fail("%s: source is smaller than its %d x %d grid" % [path, columns, rows])
		return []
	if not row_edges.is_empty() and row_edges.size() != rows + 1:
		_fail("%s: source_row_edges must contain %d row boundaries" % [path, rows + 1])
		return []
	var boundaries: Array[int] = []
	for index in rows + 1:
		var edge := floori(float(index) * source.get_height() / rows)
		if not row_edges.is_empty():
			var value: Variant = row_edges[index]
			if not (value is int or value is float) or float(value) != float(int(value)):
				_fail("%s: source_row_edges[%d] must be an integer pixel boundary" % [path, index])
				return []
			edge = int(value)
		if edge < 0 or edge > source.get_height() or (index > 0 and edge <= boundaries[index - 1]):
			_fail("%s: source_row_edges must increase strictly between 0 and source height %d" % [path, source.get_height()])
			return []
		boundaries.append(edge)
	if boundaries[0] != 0 or boundaries[rows] != source.get_height():
		_fail("%s: source_row_edges must begin at 0 and end at source height %d" % [path, source.get_height()])
		return []
	source.convert(Image.FORMAT_RGBA8)
	var cells: Array[Image] = []
	for row in rows:
		for column in columns:
			var start := Vector2i(floori(float(column) * source.get_width() / columns), boundaries[row])
			var end := Vector2i(floori(float(column + 1) * source.get_width() / columns), boundaries[row + 1])
			var cell := source.get_region(Rect2i(start, end - start))
			# Retain opaque art and binary alpha, matching the original pixel-art import.
			for y in cell.get_height():
				for x in cell.get_width():
					var pixel := cell.get_pixel(x, y)
					pixel.a = 1.0 if pixel.a >= 0.8 else 0.0
					cell.set_pixel(x, y, pixel if pixel.a > 0.0 else Color.TRANSPARENT)
			var used := cell.get_used_rect()
			if not used.has_area():
				_fail("%s: empty source cell at row %d, column %d" % [path, row, column])
				return []
			if used.position.x <= 0 or used.position.y <= 0 or used.end.x >= cell.get_width() or used.end.y >= cell.get_height():
				_fail("%s: source figure touches its cell boundary at row %d, column %d; repair the clipped source" % [path, row, column])
				return []
			cells.append(cell)
	return cells


func _scale_for(cells: Array[Image], height: float) -> float:
	var heights: Array[float] = []
	for cell in cells:
		heights.append(float(cell.get_used_rect().size.y))
	heights.sort()
	return height / maxf(1.0, heights[heights.size() / 2])


func _scaled(source: Image, scale_factor: float) -> Image:
	var picture: Image = source.duplicate()
	picture.resize(maxi(1, roundi(picture.get_width() * scale_factor)), maxi(1, roundi(picture.get_height() * scale_factor)), Image.INTERPOLATE_NEAREST)
	return picture


func _head_center(picture: Image) -> float:
	var used := picture.get_used_rect()
	var total := 0.0
	var count := 0
	for y in range(used.position.y, used.position.y + roundi(used.size.y * 0.42)):
		for x in range(used.position.x, used.end.x):
			if picture.get_pixel(x, y).a > 0.0:
				total += x
				count += 1
	return total / maxf(1.0, count)


func _registered(source: Image, scale_factor: float, label: String) -> Image:
	var picture := _scaled(source, scale_factor)
	var offset := Vector2i(roundi(FRAME.x / 2.0 - _head_center(picture)), GROUND - picture.get_used_rect().end.y)
	return _pack_frame(picture, offset, label)


func _pack_frame(picture: Image, offset: Vector2i, label: String) -> Image:
	var used := picture.get_used_rect()
	var placed := Rect2i(used.position + offset, used.size)
	if not used.has_area() or not Rect2i(Vector2i.ZERO, FRAME).encloses(placed):
		_fail("%s: registered figure %s would be empty or clipped by the %s runtime frame; correct its source registration" % [label, placed, FRAME])
		return null
	var frame := Image.create_empty(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
	frame.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), offset)
	return frame


func _save(sheet: Image, path: String) -> void:
	var error := sheet.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("Could not save %s: %s" % [path, error_string(error)])
		return
	print("Packed %s (%s)" % [path, sheet.get_size()])


func _fail(message: String) -> void:
	_failed = true
	push_error("Player sheet import: " + message)
	quit(1)
