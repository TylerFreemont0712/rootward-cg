extends SceneTree


func _init() -> void:
	var theme := ThemeDB.get_default_theme()
	print("CodeEdit constants: ", theme.get_constant_list("CodeEdit"))
	print("TextEdit constants: ", theme.get_constant_list("TextEdit"))
	var names: Array[String] = []
	for p: Dictionary in ClassDB.class_get_property_list("Control"):
		if String(p.name).begins_with("pivot"):
			names.append(String(p.name))
	print("Control pivot props: ", names)
	var tabs: Array[String] = []
	for p: Dictionary in ClassDB.class_get_property_list("TextEdit"):
		if String(p.name).contains("tab"):
			tabs.append(String(p.name))
	print("TextEdit tab props: ", tabs)
	for a: String in ["ui_up", "ui_left", "ui_select", "ui_focus_next", "ui_focus_prev"]:
		for e: InputEvent in InputMap.action_get_events(a):
			print(a, ": ", e.as_text())
	quit()
