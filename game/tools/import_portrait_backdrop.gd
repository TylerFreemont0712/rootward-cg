extends SceneTree
## Import the shared imagegen backdrop at a suitable reusable portrait resolution.


func _init() -> void:
	var source := "res://../Concept/v0.5/characters/portrait-backdrop/village-source.png"
	var target := PortraitArt.BACKDROP
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null or image.is_empty():
		push_error("Missing portrait backdrop source: " + source)
		quit(1)
		return
	image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var error := image.save_png(target)
	if error != OK: push_error(error_string(error))
	quit(0 if error == OK else 1)
