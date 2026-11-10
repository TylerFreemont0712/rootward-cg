extends Control
## Rootward Setup (ADR-0091): installs, updates, repairs and uninstalls the game, per user, on Windows and Linux.
##
## It reads rootward-manifest.json from where the packages are (a folder beside the installer, for an offline
## install, or the download address in config.json), downloads what the game in this folder lacks, checks every
## file's SHA-256 before it touches the folder, unpacks, adds the shortcuts, and runs the game's own self-test to
## prove the sandbox works on this machine.
##
##   Rootward Setup                      the window
##   --silent [--install|--uninstall]    no window, for scripts and the Windows check (with Godot's --headless)
##   --dir <folder>  --from <url|folder>  --repair  --no-shortcuts  --log <file>

const GROUND := Color("#120e0a")
const PANEL := Color("#1a1410")
const LINE := Color("#3c2f21")
const AMBER := Color("#f2a541")
const AMBER_DIM := Color("#a8712a")
const TEXT := Color("#e9dcc0")
const MUTED := Color("#a58f6e")
const FAINT := Color("#6f5e46")
const PASS := Color("#8bc96a")
const FAIL := Color("#e2584f")
const WARN := Color("#e9c46a")
const MANIFEST := "rootward-manifest.json"
const STAGING := ".setup-download"
## How much of the bar each phase fills: downloading is most of the wait.
const WEIGHTS := {"download": 0.78, "verify": 0.08, "install": 0.09, "finish": 0.05}
const STEPS: Array[String] = ["download", "verify", "install", "finish"]

var _version := "dev"
var _source := ""
var _manifest: Dictionary = {}
var _spec: Dictionary = {}
var _dir := ""
var _existing: InstallRecord = null
var _silent := false
var _uninstall := false
var _repair := false
var _shortcuts := true
var _cancelled := false
var _busy := false
var _log_path := ""
var _problems: PackedStringArray = []
var _check_line := ""
var _last_silent_tenth := -1

var _cinzel: Font
var _body: Font
var _body_bold: Font
var _page: VBoxContainer
var _bar: ProgressBar
var _status: Label
var _detail: Label
var _step_dots: Dictionary = {}
var _dir_edit: LineEdit
var _menu_box: CheckBox
var _desktop_box: CheckBox
var _size_label: Label
var _install_button: Button
var _folder_dialog: FileDialog


func _ready() -> void:
	_read_arguments()
	if FileAccess.file_exists("res://version.txt"):
		_version = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	_log("Rootward Setup %s on %s; log: %s" % [_version, OS.get_name(), _log_path])
	_existing = InstallRecord.read(_dir)
	if _silent:
		_run_silent.call_deferred()
		return
	get_window().title = "Rootward Setup"
	get_window().close_requested.connect(_on_close)
	_build_frame()
	if _uninstall:
		_show_uninstall_confirm()
	else:
		_show_welcome()
		_load_manifest_for_welcome.call_deferred()


# --- arguments, logging --------------------------------------------------------------------------------------------


func _read_arguments() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	_silent = args.has("--silent")
	_uninstall = args.has("--uninstall")
	_repair = args.has("--repair")
	_shortcuts = not args.has("--no-shortcuts")
	_dir = _value(args, "--dir", "")
	if _dir == "":
		# Run from an installed game's folder (its own copy, or Settings > Apps > Uninstall), it manages that game.
		var own := OS.get_executable_path().get_base_dir()
		_dir = own if FileAccess.file_exists(SetupPaths.marker(own)) else SetupPaths.default_dir()
	else:
		_dir = SetupPaths.install_dir_for(_dir)
	_source = _value(args, "--from", "")
	_log_path = _value(args, "--log", OS.get_user_data_dir().path_join("setup.log"))
	var file := FileAccess.open(_log_path, FileAccess.WRITE)
	if file != null:
		file.close()


static func _value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var at := args.find(flag)
	return args[at + 1] if at != -1 and at + 1 < args.size() else fallback


func _log(line: String) -> void:
	print(line)
	var file := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file != null:
		file.seek_end()
		file.store_line("[%s] %s" % [Time.get_time_string_from_system(), line])
		file.close()


func _problem(line: String) -> void:
	_problems.append(line)
	_log("problem: " + line)


# --- where the packages come from ----------------------------------------------------------------------------------


## A folder beside the installer that holds the release files wins (an offline install); then --from; then the
## download address the build wrote into config.json.
func _resolve_source() -> String:
	if _source != "":
		return _source
	var beside := OS.get_executable_path().get_base_dir()
	if FileAccess.file_exists(beside.path_join(MANIFEST)):
		return beside
	var from_env := OS.get_environment("ROOTWARD_DOWNLOADS")
	if from_env != "":
		return from_env
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://config.json"))
	return str((config as Dictionary).get("downloads", "")) if config is Dictionary else ""


static func _is_url(source: String) -> bool:
	return source.begins_with("http://") or source.begins_with("https://")


static func _join(source: String, file: String) -> String:
	return (source if source.ends_with("/") else source + "/") + file if _is_url(source) else source.path_join(file)


## Reads the manifest; returns "" or why it could not.
func _load_manifest() -> String:
	_source = _resolve_source()
	if _source == "":
		return "this installer does not know where to download Rootward from"
	_log("packages from %s" % _source)
	var text := ""
	if _is_url(_source):
		var request := HTTPRequest.new()
		request.max_redirects = 10
		request.timeout = 30.0
		add_child(request)
		var state := {"done": false, "result": 0, "code": 0, "body": PackedByteArray()}
		request.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			state.done = true
			state.result = result
			state.code = code
			state.body = body)
		if request.request(_join(_source, MANIFEST)) != OK:
			request.queue_free()
			return "could not start a download"
		while not state.done:
			await get_tree().process_frame
		request.queue_free()
		if state.result != HTTPRequest.RESULT_SUCCESS:
			return "could not reach the download server (%s)" % _http_result(state.result)
		if state.code != 200:
			return "the download server answered %d%s" % [state.code,
				": the release may be private; put the release files beside this installer instead" if state.code == 404 else ""]
		text = (state.body as PackedByteArray).get_string_from_utf8()
	else:
		text = FileAccess.get_file_as_string(_join(_source, MANIFEST))
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not (data as Dictionary).has("platforms"):
		return "the package list (%s) is not readable" % MANIFEST
	_manifest = data
	var platforms: Dictionary = _manifest.platforms
	if not platforms.has(SetupPaths.platform()):
		return "this release has no build for %s" % OS.get_name()
	_spec = platforms[SetupPaths.platform()]
	_log("Rootward %s for %s: %d packages" % [_manifest.version, SetupPaths.platform(), (_spec.packages as Array).size()])
	return ""


static func _http_result(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "no internet connection?"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "the connection failed"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "a secure connection could not be made"
		HTTPRequest.RESULT_TIMEOUT:
			return "it took too long"
	return "error %d" % result


## The packages this folder needs: all of them for a new install or a repair, else those whose hash changed.
func _needed() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for package: Dictionary in _spec.packages:
		var have := "" if _existing == null or _repair else str(_existing.packages.get(package.id, ""))
		if have != package.sha256 or not FileAccess.file_exists(SetupPaths.game_exe(_dir)):
			out.append(package)
	return out


# --- the work ------------------------------------------------------------------------------------------------------


## Installs or updates; returns "" or what went wrong.
func _install() -> String:
	_busy = true
	_cancelled = false
	_problems.clear()
	_check_line = ""
	if _manifest.is_empty():
		var failed := await _load_manifest()
		if failed != "":
			return failed
	_existing = InstallRecord.read(_dir)
	var occupied := DirAccess.dir_exists_absolute(_dir) and not (DirAccess.get_files_at(_dir).is_empty()
		and DirAccess.get_directories_at(_dir).is_empty())
	if occupied and _existing == null:
		return "%s already holds other files; choose an empty folder" % _dir
	if DirAccess.make_dir_recursive_absolute(_dir) != OK:
		return "could not create %s" % _dir
	var staging := _dir.path_join(STAGING)
	DirAccess.make_dir_recursive_absolute(staging)
	var todo := _needed()
	var total := 0
	for package in todo:
		total += int(package.size)
	_log("%d package(s) to fetch, %s" % [todo.size(), SetupPaths.human_size(total)])
	# 1. Download (or copy from the folder beside the installer) into a staging folder inside the game's folder.
	_enter_step("download")
	var fetched := 0
	for package in todo:
		var local := staging.path_join(str(package.file))
		var label := _package_label(str(package.id))
		var failed := await _fetch(package, local, label, fetched, total)
		if failed != "":
			return failed
		fetched += int(package.size)
	# 2. Check every file before any of them changes the game's folder.
	_enter_step("verify")
	for i in todo.size():
		var package := todo[i]
		var progress := PackageWork.Progress.new()
		var local := staging.path_join(str(package.file))
		_say("Checking %s" % _package_label(str(package.id)).to_lower(), "SHA-256 of %s" % package.file)
		var digest: String = await _in_thread(func() -> String: return PackageWork.sha256(local, progress), progress, "verify", i,
			todo.size())
		if digest != str(package.sha256):
			DirAccess.remove_absolute(local)
			return "%s did not arrive intact (its SHA-256 does not match); try again" % package.file
	# 3. Put everything in place.
	_enter_step("install")
	for i in todo.size():
		var package := todo[i]
		var local := staging.path_join(str(package.file))
		var progress := PackageWork.Progress.new()
		_say("Installing %s" % _package_label(str(package.id)).to_lower(), _dir)
		var failed := ""
		if package.kind == "zip":
			if package.id == "sandbox":
				PackageWork.remove_tree(_dir.path_join("sandbox"))  # a sandbox from an older version goes whole
			var executables: Array = _spec.get("executables", [])
			var into := _dir
			failed = await _in_thread(func() -> String: return PackageWork.extract(local, into, executables, progress), progress,
				"install", i, todo.size())
			DirAccess.remove_absolute(local)
		else:
			failed = PackageWork.place(local, _dir.path_join(str(package.get("target", package.file))))
		if failed != "":
			return failed
	PackageWork.remove_tree(staging)
	# 4. The installer's own copy (for updates and uninstalling), shortcuts, the record, and the sandbox check.
	_enter_step("finish")
	_say("Adding shortcuts", "")
	var own := OS.get_executable_path()
	var copy := SetupPaths.setup_exe(_dir)
	if own != copy and FileAccess.file_exists(own) and not OS.has_feature("editor"):
		PackageWork.make_writable(copy)
		if DirAccess.copy_absolute(own, copy) == OK and not SetupPaths.windows():
			FileAccess.set_unix_permissions(copy, PackageWork.EXECUTABLE)
	var record := InstallRecord.new()
	record.version = str(_manifest.version)
	record.platform = SetupPaths.platform()
	for package: Dictionary in _spec.packages:
		record.packages[package.id] = package.sha256
	if _existing != null:
		SystemIntegration.remove(_existing, _problem)
	if _shortcuts:
		var menu := _menu_box.button_pressed if _menu_box != null else true
		var desktop := _desktop_box.button_pressed if _desktop_box != null else true
		record.shortcuts = SystemIntegration.add(_dir, record.version, int(_spec.get("installed_size", 0)), menu, desktop, _problem)
		record.registered = SetupPaths.windows()
	if not record.write(_dir):
		return "could not write %s" % SetupPaths.marker(_dir)
	_existing = record
	_set_bar(WEIGHTS.download + WEIGHTS.verify + WEIGHTS.install + WEIGHTS.finish * 0.3)
	_say("Testing the sandbox", "Every card's worked examples, in Python, JavaScript and C++")
	var exe := SetupPaths.check_exe(_dir)
	var result: Array = await _in_thread(func() -> Array: return _self_test(exe), null, "finish", 0, 1)
	_check_line = str(result[1])
	if int(result[0]) != 0:
		_problem("the sandbox check did not pass: %s" % _check_line)
	_set_bar(1.0)
	_busy = false
	return ""


func _fetch(package: Dictionary, local: String, label: String, before: int, total: int) -> String:
	var source := _join(_source, str(package.file))
	if FileAccess.file_exists(local) and PackageWork.sha256(local) == str(package.sha256):
		return ""  # already here from an attempt that stopped later
	if not _is_url(_source):
		_say("Copying %s" % label.to_lower(), str(package.file))
		var copied: int = await _in_thread(func() -> int: return DirAccess.copy_absolute(source, local), null, "download", 0, 1)
		_set_progress("download", float(before + int(package.size)) / maxf(total, 1))
		return "" if copied == OK else "could not copy %s from %s" % [package.file, _source]
	var request := HTTPRequest.new()
	request.use_threads = true
	request.max_redirects = 10
	request.download_chunk_size = 1 << 20
	request.download_file = local + ".part"
	add_child(request)
	var state := {"done": false, "result": 0, "code": 0}
	request.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		state.done = true
		state.result = result
		state.code = code)
	if request.request(source) != OK:
		request.queue_free()
		return "could not start downloading %s" % package.file
	_log("downloading %s" % source)
	var started := Time.get_ticks_msec()
	var speed := 0.0
	var last_bytes := 0
	var last_time := started
	while not state.done:
		if _cancelled:
			request.cancel_request()
			request.queue_free()
			DirAccess.remove_absolute(local + ".part")
			return "cancelled"
		var now := Time.get_ticks_msec()
		var got := request.get_downloaded_bytes()
		if now - last_time >= 400:
			var instant := float(got - last_bytes) * 1000.0 / float(now - last_time)
			speed = instant if speed == 0.0 else lerpf(speed, instant, 0.3)
			last_bytes = got
			last_time = now
		var size := int(package.size)
		var left := "" if speed <= 1.0 else " · about %s left" % _duration((total - before - got) / speed)
		_say("Downloading %s" % label.to_lower(), "%s of %s · %s/s%s" % [SetupPaths.human_size(got),
			SetupPaths.human_size(size), SetupPaths.human_size(speed), left])
		_set_progress("download", float(before + got) / maxf(total, 1))
		await get_tree().process_frame
	request.queue_free()
	if state.result != HTTPRequest.RESULT_SUCCESS or state.code != 200:
		DirAccess.remove_absolute(local + ".part")
		var why: String = _http_result(state.result) if state.result != HTTPRequest.RESULT_SUCCESS else "the server answered %d" % state.code
		return "%s could not be downloaded (%s)" % [package.file, why]
	_log("downloaded %s in %.1fs" % [package.file, (Time.get_ticks_msec() - started) / 1000.0])
	return PackageWork.place(local + ".part", local)


## Runs `work` on a thread while the window keeps drawing and the bar follows `progress` through `step`.
func _in_thread(work: Callable, progress: PackageWork.Progress, step: String, index: int, count: int) -> Variant:
	var thread := Thread.new()
	thread.start(work)
	while thread.is_alive():
		if progress != null:
			_set_progress(step, (index + progress.fraction()) / maxf(count, 1))
		await get_tree().process_frame
	return thread.wait_to_finish()


## [exit code, its last line]. Runs the installed game's self-test (SelfTest in the game).
static func _self_test(exe: String) -> Array:
	var output: Array = []
	var code := OS.execute(exe, ["--headless", "--", "--self-test"], output, true)
	var lines := "".join(PackedStringArray(output)).strip_edges().split("\n")
	return [code, lines[lines.size() - 1].strip_edges() if not lines.is_empty() else "no output"]


func _uninstall_now() -> String:
	_busy = true
	if _existing == null:
		return "no Rootward installed by this setup is in %s" % _dir
	_mark_steps("install")
	_set_bar(0.05)
	_say("Removing shortcuts", "")
	SystemIntegration.remove(_existing, _problem)
	_set_bar(0.3)
	_say("Removing Rootward", _dir)
	var own := OS.get_executable_path()
	var keep := own if own.get_base_dir() == _dir and SetupPaths.windows() else ""
	var dir := _dir
	await _in_thread(func() -> void: PackageWork.remove_tree(dir, keep), null, "install", 0, 1)
	if keep != "":
		SystemIntegration.remove_after_exit(_dir)
	_set_bar(1.0)
	_existing = null
	_busy = false
	return ""


# --- silent mode ---------------------------------------------------------------------------------------------------


func _run_silent() -> void:
	var version := str(_manifest.get("version", "")) if _existing == null else _existing.version
	var failed := ""
	if _uninstall:
		failed = await _uninstall_now()
	else:
		failed = await _install()
	if failed != "":
		_log("FAILED: " + failed)
		get_tree().quit(1)
		return
	for line in _problems:
		_log("warning: " + line)
	_log("%s %s in %s%s" % ["uninstalled" if _uninstall else "installed", _manifest.get("version", version), _dir,
		"" if _check_line == "" else "; sandbox check: " + _check_line])
	get_tree().quit(2 if not _problems.is_empty() else 0)


# --- the window ----------------------------------------------------------------------------------------------------


func _build_frame() -> void:
	_cinzel = _font("res://brand/cinzel.ttf")
	_body = _font("res://brand/spectral.ttf")
	_body_bold = _font("res://brand/spectral-600.ttf")
	theme = _make_theme()
	var ground := ColorRect.new()
	ground.color = GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var backdrop := TextureRect.new()
	backdrop.texture = _texture("res://brand/backdrop.webp")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# The title screen's light: dark under the words on the left, the painting open on the right.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(GROUND, 0.97))
	gradient.set_color(1, Color(GROUND, 0.05))
	gradient.add_point(0.5, Color(GROUND, 0.82))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.fill_from = Vector2(0, 0)
	fill.fill_to = Vector2(1, 0)
	shade.texture = fill
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, {"left": 64, "top": 48, "right": 420, "bottom": 36}[side])
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var wordmark := _texture("res://brand/wordmark.png")
	if wordmark != null:
		var mark := TextureRect.new()
		mark.texture = wordmark
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		mark.custom_minimum_size = Vector2(400, 130)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(mark)
	else:
		column.add_child(_label("ROOTWARD", _cinzel, 64, AMBER))
	column.add_child(_label("Program the spell. Descend into the machine.", _cinzel, 17, MUTED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	column.add_child(gap)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 14)
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_page)
	column.add_child(_label("Rootward Setup %s · %s" % [_version, OS.get_name()], _body, 13, FAINT))


func _clear_page() -> void:
	for child in _page.get_children():
		child.queue_free()
	_step_dots.clear()
	_bar = null


func _show_welcome() -> void:
	_clear_page()
	var installed := _existing != null
	_page.add_child(_label("Rootward %s is installed" % _existing.version if installed else "Install Rootward", _cinzel, 28, TEXT))
	_page.add_child(_label("For you alone; no administrator needed. Your saves are never touched by setup.", _body, 17, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_dir_edit = LineEdit.new()
	_dir_edit.text = _dir
	_dir_edit.editable = not installed
	_dir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dir_edit.text_changed.connect(func(text: String) -> void:
		_dir = SetupPaths.install_dir_for(text) if text.strip_edges() != "" else _dir)
	row.add_child(_dir_edit)
	if not installed:
		row.add_child(_button("Change…", false, _choose_folder))
	_page.add_child(_label("Install to", _body_bold, 15, MUTED))
	_page.add_child(row)
	_menu_box = _check("Add Rootward to the %s" % ("Start menu" if SetupPaths.windows() else "app menu"))
	_desktop_box = _check("Put a shortcut on the desktop")
	_page.add_child(_menu_box)
	_page.add_child(_desktop_box)
	_size_label = _label("Looking for the latest version…", _body, 15, FAINT)
	_page.add_child(_size_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_install_button = _button("Install" if not installed else "Update", true, _start_install)
	_install_button.disabled = true
	buttons.add_child(_install_button)
	if installed:
		buttons.add_child(_button("Play", false, _play))
		buttons.add_child(_button("Uninstall", false, _show_uninstall_confirm))
	buttons.add_child(_button("Close", false, _on_close))
	_page.add_child(_spacer())
	_page.add_child(buttons)


func _load_manifest_for_welcome() -> void:
	var failed: String = await _load_manifest()
	if _size_label == null or not is_instance_valid(_size_label):
		return
	if failed != "":
		_size_label.text = "Cannot install yet: %s." % failed
		_size_label.add_theme_color_override("font_color", FAIL)
		return
	var todo := _needed()
	var download := 0
	for package in todo:
		download += int(package.size)
	var up_to_date := _existing != null and todo.is_empty()
	if up_to_date:
		_size_label.text = "Rootward %s is up to date. Update repairs it: every file is fetched again." % _manifest.version
		_install_button.text = "Repair"
		_repair = true
	else:
		_size_label.text = "Rootward %s · %s to download · %s on disk" % [_manifest.version, SetupPaths.human_size(download),
			SetupPaths.human_size(float(_spec.get("installed_size", 0)))]
	_size_label.add_theme_color_override("font_color", MUTED)
	_install_button.disabled = false
	if (OS.get_cmdline_args() + OS.get_cmdline_user_args()).has("--install") and not _busy:
		_start_install()  # the window, without waiting for a click


func _show_working(title: String) -> void:
	_clear_page()
	_page.add_child(_label(title, _cinzel, 28, TEXT))
	_status = _label("", _cinzel, 18, TEXT)
	_page.add_child(_status)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.max_value = 1.0
	_bar.step = 0.0
	_page.add_child(_bar)
	_detail = _label("", _body, 15, MUTED)
	_page.add_child(_detail)
	var steps := VBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	var names := {"download": "Download", "verify": "Check every file", "install": "Install", "finish": "Shortcuts and a sandbox test"}
	if _uninstall:
		names = {"install": "Remove the game, its shortcuts and its entry"}
	for step: String in names:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", _dot_style(FAINT, false))
		line.add_child(dot)
		var name_label := _label(names[step], _body, 15, MUTED)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF  # a wrapping label in a row has no width of its own
		line.add_child(name_label)
		steps.add_child(line)
		_step_dots[step] = dot
	_page.add_child(steps)
	_page.add_child(_spacer())
	if not _uninstall:
		var cancel := _button("Cancel", false, func() -> void: _cancelled = true)
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_page.add_child(cancel)


func _show_done(title: String, lines: PackedStringArray, play: bool) -> void:
	_clear_page()
	_page.add_child(_label(title, _cinzel, 28, TEXT))
	for line in lines:
		_page.add_child(_label(line, _body, 16, MUTED))
	if _check_line != "":
		var ok := _check_line.ends_with("OK")
		_page.add_child(_label(("Sandbox check passed: " if ok else "Sandbox check: ") + _check_line, _body, 15, PASS if ok else WARN))
	for problem in _problems:
		_page.add_child(_label("Note: " + problem, _body, 14, WARN))
	_page.add_child(_spacer())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	if play:
		buttons.add_child(_button("Play Rootward", true, _play))
	buttons.add_child(_button("Close", not play, _on_close))
	_page.add_child(buttons)


func _show_failed(why: String) -> void:
	_clear_page()
	_page.add_child(_label("Setup could not finish", _cinzel, 28, FAIL))
	_page.add_child(_label(why.substr(0, 1).to_upper() + why.substr(1) + ".", _body, 17, TEXT))
	_page.add_child(_label("Nothing half-done was left in place: a file is only installed after all of them check out.", _body, 15, MUTED))
	_page.add_child(_spacer())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Try again", true, func() -> void:
		_manifest = {}
		_show_welcome()
		_load_manifest_for_welcome()))
	buttons.add_child(_button("Open the log", false, func() -> void: OS.shell_open(_log_path)))
	buttons.add_child(_button("Close", false, _on_close))
	_page.add_child(buttons)


func _show_uninstall_confirm() -> void:
	_uninstall = true
	_clear_page()
	_page.add_child(_label("Uninstall Rootward?", _cinzel, 28, TEXT))
	_page.add_child(_label("This removes the game from %s, with its shortcuts%s." % [_dir,
		" and its entry in Settings > Apps" if SetupPaths.windows() else ""], _body, 17, MUTED))
	_page.add_child(_label("Your saves and settings stay in %s." % SetupPaths.saves_dir(), _body, 15, FAINT))
	_page.add_child(_spacer())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Uninstall", true, _start_uninstall))
	buttons.add_child(_button("Keep it", false, func() -> void:
		_uninstall = false
		if _existing != null:
			_show_welcome()
			_load_manifest_for_welcome()
		else:
			_on_close()))
	_page.add_child(buttons)


func _start_install() -> void:
	if _busy:
		return
	_show_working("Updating Rootward" if _existing != null else "Installing Rootward")
	var failed: String = await _install()
	_busy = false
	if failed == "cancelled":
		_show_welcome()
		_load_manifest_for_welcome()
		return
	if failed != "":
		_log("FAILED: " + failed)
		_show_failed(failed)
		return
	_show_done("Rootward is ready", PackedStringArray(["Installed in %s." % _dir,
		"Saves and settings live in %s." % SetupPaths.saves_dir()]), true)


func _start_uninstall() -> void:
	if _busy:
		return
	_show_working("Uninstalling Rootward")
	var failed: String = await _uninstall_now()
	if failed != "":
		_show_failed(failed)
		return
	_show_done("Rootward has been removed", PackedStringArray(["Your saves are still in %s, should you return." % SetupPaths.saves_dir()]), false)


func _choose_folder() -> void:
	if _folder_dialog == null:
		_folder_dialog = FileDialog.new()
		_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_folder_dialog.use_native_dialog = true
		_folder_dialog.title = "Where should Rootward go?"
		_folder_dialog.dir_selected.connect(func(chosen: String) -> void:
			_dir = SetupPaths.install_dir_for(chosen)
			_dir_edit.text = _dir)
		add_child(_folder_dialog)
	_folder_dialog.current_dir = _dir.get_base_dir()
	_folder_dialog.popup_centered_ratio(0.6)


func _play() -> void:
	OS.create_process(SetupPaths.game_exe(_dir), [])
	get_tree().quit()


func _on_close() -> void:
	if _busy:
		_cancelled = true
		return
	get_tree().quit()


# --- progress ------------------------------------------------------------------------------------------------------


func _enter_step(step: String) -> void:
	_mark_steps(step)
	_set_progress(step, 0.0)


## Lights the dots: the steps before `step` done, `step` under way.
func _mark_steps(step: String) -> void:
	var reached := false
	for name in STEPS:
		if not _step_dots.has(name):
			continue
		var dot: Panel = _step_dots[name]
		if name == step:
			reached = true
			dot.add_theme_stylebox_override("panel", _dot_style(AMBER, true))
		elif not reached:
			dot.add_theme_stylebox_override("panel", _dot_style(PASS, true))


func _set_progress(step: String, fraction: float) -> void:
	var start := 0.0
	for name in STEPS:
		if name == step:
			break
		start += float(WEIGHTS[name])
	_set_bar(start + float(WEIGHTS[step]) * clampf(fraction, 0.0, 1.0))


func _set_bar(value: float) -> void:
	if _bar != null:
		_bar.value = value
	if _silent:
		var tenth := int(value * 10.0)
		if tenth != _last_silent_tenth:
			_last_silent_tenth = tenth
			_log("%3d%%" % (tenth * 10))


func _say(status: String, detail: String) -> void:
	if _status != null:
		_status.text = status
		_detail.text = detail


func _package_label(id: String) -> String:
	return {"game": "The game", "data": "The game's pictures and sound", "sandbox": "The sandbox (Python, JavaScript, C++)"}.get(id, id)


static func _duration(seconds: float) -> String:
	if seconds >= 90.0:
		return "%d min" % ceili(seconds / 60.0)
	return "%d s" % maxi(1, ceili(seconds))


# --- looks ---------------------------------------------------------------------------------------------------------


func _make_theme() -> Theme:
	var made := Theme.new()
	if _body != null:
		made.default_font = _body
	made.default_font_size = 16
	made.set_color("font_color", "Label", TEXT)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(AMBER, {"normal": 0.06, "hover": 0.14, "pressed": 0.22, "disabled": 0.02, "focus": 0.06}[state])
		box.border_color = {"normal": AMBER_DIM, "hover": AMBER, "pressed": AMBER, "disabled": LINE, "focus": AMBER}[state]
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 22
		box.content_margin_right = 22
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		if state == "focus":
			box.bg_color = Color(0, 0, 0, 0)
			box.draw_center = false
		made.set_stylebox(state, "Button", box)
	made.set_color("font_color", "Button", TEXT)
	made.set_color("font_hover_color", "Button", AMBER)
	made.set_color("font_pressed_color", "Button", AMBER)
	made.set_color("font_disabled_color", "Button", FAINT)
	if _cinzel != null:
		made.set_font("font", "Button", _cinzel)
	made.set_font_size("font_size", "Button", 16)
	var field := StyleBoxFlat.new()
	field.bg_color = Color(PANEL, 0.9)
	field.border_color = LINE
	field.set_border_width_all(1)
	field.set_corner_radius_all(3)
	field.content_margin_left = 12
	field.content_margin_right = 12
	field.content_margin_top = 8
	field.content_margin_bottom = 8
	made.set_stylebox("normal", "LineEdit", field)
	var focused := field.duplicate() as StyleBoxFlat
	focused.border_color = AMBER_DIM
	made.set_stylebox("focus", "LineEdit", focused)
	made.set_stylebox("read_only", "LineEdit", field)
	made.set_color("font_color", "LineEdit", TEXT)
	made.set_color("font_uneditable_color", "LineEdit", MUTED)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		made.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())  # CheckBox inherits Button's boxes otherwise
	made.set_color("font_color", "CheckBox", TEXT)
	made.set_color("font_hover_color", "CheckBox", AMBER)
	made.set_color("font_pressed_color", "CheckBox", TEXT)
	made.set_color("font_hover_pressed_color", "CheckBox", AMBER)
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(PANEL, 0.92)
	trough.border_color = LINE
	trough.set_border_width_all(1)
	trough.set_corner_radius_all(4)
	made.set_stylebox("background", "ProgressBar", trough)
	var lit := StyleBoxFlat.new()
	lit.bg_color = AMBER
	lit.set_corner_radius_all(4)
	lit.shadow_color = Color(AMBER, 0.35)
	lit.shadow_size = 6
	made.set_stylebox("fill", "ProgressBar", lit)
	return made


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, primary: bool, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.add_theme_color_override("font_color", AMBER)
		var box := (theme.get_stylebox("normal", "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.bg_color = Color(AMBER, 0.16)
		box.border_color = AMBER
		button.add_theme_stylebox_override("normal", box)
	return button


func _check(text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = true
	box.add_theme_font_size_override("font_size", 16)
	return box


func _spacer() -> Control:
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return gap


static func _dot_style(color: Color, filled: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color if filled else Color(0, 0, 0, 0)
	box.border_color = color
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


## A brand file the build copied in (scripts/build.py); a missing one leaves plain text and colour.
static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func _font(path: String) -> Font:
	return load(path) as Font if ResourceLoader.exists(path) else null
