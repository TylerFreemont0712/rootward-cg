extends SceneTree
## Writes the engine's licence and its third-party notices, as this Godot build reports them, for a shipped game
## (scripts/build.py):  godot --headless --path game -s res://tools/licenses.gd -- <out file>


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var lines: PackedStringArray = ["Godot Engine (https://godotengine.org)", "", Engine.get_license_text(), ""]
	lines.append("Godot Engine includes these third-party components:")
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append("- %s" % component.name)
		for part: Dictionary in component.parts:
			for holder: String in part.copyright:
				lines.append("  Copyright %s" % holder)
			lines.append("  License: %s" % part.license)
	var texts: Dictionary = Engine.get_license_info()
	for name: String in texts:
		lines.append("")
		lines.append("License: %s" % name)
		lines.append("")
		lines.append(str(texts[name]))
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	quit()
