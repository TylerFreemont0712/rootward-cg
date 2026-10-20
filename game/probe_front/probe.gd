extends SceneTree


func _initialize() -> void:
	for p: Dictionary in ClassDB.class_get_property_list("Control", true):
		if String(p.name).contains("behavior"):
			print(p.name, " ", p.hint_string)
	print(ClassDB.class_get_property_default_value("ScrollContainer", "focus_mode"))
	print(ClassDB.class_has_method("Control", "set_focus_behavior_recursive"))
	quit(0)
