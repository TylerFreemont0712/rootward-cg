extends Node2D
## Inspect actual player occlusion against both hinges and both vertical gate arcs.


func _ready() -> void:
	var objects: Array[Dictionary] = []
	for index: int in 8:
		objects.append({"kind": "prop", "art": "gate_v", "at": [3 + index % 4 * 7, 4 + index / 4 * 8],
			"size": [1, 1], "boundary_edge": "vertical", "boundary_style": "brick", "solid": false,
			"flip": index % 4 >= 2})
	var rows: Array[String] = []
	for y: int in 17: rows.append(".".repeat(30))
	var built := OverworldMap.build({"id": "gate-depth", "ground": rows, "legend": {".": "grass"}, "objects": objects}, {"grass": {"walk": true}})
	var view := TownMapView.new({})
	view.position = Vector2(350, 170)
	add_child(view)
	view.show_map(built.map)
	view.set_process(false)
	for index: int in 8:
		var gate := view._gates[index]
		gate.set_process(false)
		gate.progress = 1.0
		gate.swing_side = -1 if index % 2 == 0 else 1
		gate._show_frame()
		var walker := Walker.new(OverworldArt.player_character({"model": "male"}))
		view.things.add_child(walker)
		var at := Vector2i(3 + index % 4 * 7, 4 + index / 4 * 8)
		walker.place(at if index < 4 else at + Vector2i.UP, "down")
		walker.set_process(false)
		var label := Label.new()
		label.position = view.position + Vector2((at.x - 2) * 40, (at.y - 3) * 40)
		label.text = ("First hinge" if index % 4 < 2 else "Second hinge") + (" · left arc" if index % 2 == 0 else " · right arc")
		add_child(label)
	var title := Label.new()
	title.position = Vector2(350, 45)
	title.text = "GATE DEPTH · fixed jambs and leaf sort independently"
	title.add_theme_font_size_override("font_size", 26)
	add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(350, 90)
	subtitle.text = "Top: player stands on gate cell     Bottom: player stands one cell above"
	add_child(subtitle)
