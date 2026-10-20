extends SceneTree

func _init() -> void:
	for a: String in ["ui_accept", "ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_cancel"]:
		for e: InputEvent in InputMap.action_get_events(a):
			print(a, ": ", e)
	quit()
