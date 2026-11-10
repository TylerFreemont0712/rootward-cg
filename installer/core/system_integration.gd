class_name SystemIntegration
extends RefCounted
## What makes an installed game feel installed: a Start-menu or app-menu entry, an optional desktop shortcut, and on
## Windows an entry in Settings > Apps (with its Uninstall button), all per user. Undone by `remove`.

const UNINSTALL_KEY := "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Rootward"


## Adds the entries; returns the shortcut files made, for the install record. `report` receives a line per problem.
static func add(dir: String, version: String, size_bytes: int, menu: bool, desktop: bool, report: Callable) -> Array[String]:
	if SetupPaths.windows():
		return _add_windows(dir, version, size_bytes, menu, desktop, report)
	return _add_linux(dir, menu, desktop, report)


static func remove(record: InstallRecord, report: Callable) -> void:
	for path in record.shortcuts:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if SetupPaths.windows() and record.registered:
		var script := "Remove-Item -Path '%s' -Recurse -Force -ErrorAction SilentlyContinue\n" % UNINSTALL_KEY
		_powershell(script, report)


static func _add_windows(dir: String, version: String, size_bytes: int, menu: bool, desktop: bool, report: Callable) -> Array[String]:
	var made: Array[String] = []
	var exe := _win(SetupPaths.game_exe(dir))
	var lines := PackedStringArray(["$ErrorActionPreference = 'Stop'", "$shell = New-Object -ComObject WScript.Shell"])
	var links: Array[String] = []
	if menu:
		links.append(OS.get_environment("APPDATA").replace("\\", "/").path_join("Microsoft/Windows/Start Menu/Programs/Rootward.lnk"))
	if desktop:
		links.append(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").path_join("Rootward.lnk"))
	for link in links:
		lines.append("$s = $shell.CreateShortcut(%s)" % _quote(_win(link)))
		lines.append("$s.TargetPath = %s" % _quote(exe))
		lines.append("$s.WorkingDirectory = %s" % _quote(_win(dir)))
		lines.append("$s.IconLocation = %s" % _quote(exe + ",0"))
		lines.append("$s.Description = 'Rootward: program the spell, descend into the machine.'")
		lines.append("$s.Save()")
		made.append(link)
	# LEARN: a per-user entry under HKCU\...\Uninstall is what lists a program in Settings > Apps without asking for
	# administrator rights; UninstallString is the command Windows runs when the player presses Uninstall.
	var setup := _win(SetupPaths.setup_exe(dir))
	var values := {
		"DisplayName": "Rootward", "DisplayVersion": version, "Publisher": "Rootward",
		"DisplayIcon": exe + ",0", "InstallLocation": _win(dir),
		"UninstallString": "\"%s\" --uninstall" % setup, "QuietUninstallString": "\"%s\" --uninstall --silent" % setup,
	}
	lines.append("New-Item -Path %s -Force | Out-Null" % _quote(UNINSTALL_KEY))
	for name: String in values:
		lines.append("New-ItemProperty -Path %s -Name %s -Value %s -PropertyType String -Force | Out-Null" % [
			_quote(UNINSTALL_KEY), name, _quote(str(values[name]))])
	for flag: String in ["NoModify", "NoRepair"]:
		lines.append("New-ItemProperty -Path %s -Name %s -Value 1 -PropertyType DWord -Force | Out-Null" % [_quote(UNINSTALL_KEY), flag])
	lines.append("New-ItemProperty -Path %s -Name EstimatedSize -Value %d -PropertyType DWord -Force | Out-Null" % [
		_quote(UNINSTALL_KEY), int(size_bytes / 1024.0)])
	if not _powershell("\r\n".join(lines) + "\r\n", report):
		made.clear()
	return made


static func _add_linux(dir: String, menu: bool, desktop: bool, report: Callable) -> Array[String]:
	var made: Array[String] = []
	var icon := dir.path_join("rootward.png")
	var texture := load("res://brand/icon.png") as Texture2D
	if texture != null:
		texture.get_image().save_png(icon)
	var entry := "\n".join(PackedStringArray([
		"[Desktop Entry]", "Type=Application", "Name=Rootward",
		"Comment=Program the spell. Descend into the machine.",
		"Exec=\"%s\"" % SetupPaths.game_exe(dir), "Path=%s" % dir, "Icon=%s" % icon,
		"Terminal=false", "Categories=Game;", "StartupWMClass=Rootward", "Actions=uninstall;", "",
		"[Desktop Action uninstall]", "Name=Uninstall Rootward", "Exec=\"%s\" --uninstall" % SetupPaths.setup_exe(dir), "",
	]))
	var places: Array[String] = []
	if menu:
		var data := OS.get_environment("XDG_DATA_HOME")
		if data == "":
			data = OS.get_environment("HOME").path_join(".local/share")
		places.append(data.path_join("applications/rootward.desktop"))
	if desktop:
		places.append(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("rootward.desktop"))
	for path in places:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			report.call("could not write %s" % path)
			continue
		file.store_string(entry)
		file.close()
		FileAccess.set_unix_permissions(path, PackageWork.EXECUTABLE)
		made.append(path)
		if path.get_base_dir() == OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP):
			# GNOME shows a launcher on the desktop only once it is marked trusted; elsewhere this does nothing.
			OS.execute("gio", ["set", path, "metadata::trusted", "true"])
	return made


static func _powershell(script: String, report: Callable) -> bool:
	var path := OS.get_temp_dir().path_join("rootward-setup-%d.ps1" % Time.get_ticks_usec())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		report.call("could not write %s" % path)
		return false
	file.store_string(script)
	file.close()
	var output: Array = []
	var code := OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", path],
		output, true)
	DirAccess.remove_absolute(path)
	if code != 0:
		report.call("PowerShell (%d): %s" % [code, "".join(PackedStringArray(output)).strip_edges()])
	return code == 0


## Windows wants back slashes in these paths; Godot uses forward ones.
static func _win(path: String) -> String:
	return path.replace("/", "\\")


## A PowerShell string literal: single quotes, with any single quote inside doubled.
static func _quote(text: String) -> String:
	return "'" + text.replace("'", "''") + "'"


## On Windows a running program cannot delete itself, so the uninstaller leaves a small script that waits for it to
## exit, then removes the folder and the script.
static func remove_after_exit(dir: String) -> void:
	if not SetupPaths.windows():
		return
	var script := OS.get_temp_dir().path_join("rootward-uninstall-%d.cmd" % Time.get_ticks_usec())
	var file := FileAccess.open(script, FileAccess.WRITE)
	if file == null:
		return
	# LEARN: Windows will not remove a folder that is some process's current directory, and this script inherits the
	# uninstaller's, which is the game's folder: everything inside went, the empty folder stayed (seen on the Windows
	# check). So the script first moves to its own folder (%~dp0, the TEMP folder), then tries for up to 30 seconds, in
	# case something else (an antivirus scan) holds the folder for a moment.
	var target := _win(dir)
	var lines := PackedStringArray([
		"@echo off", "cd /d \"%~dp0\"", "set tries=0", ":again", "ping -n 3 127.0.0.1 >nul",
		"attrib -r \"%s\\*\" /s /d >nul 2>&1" % target, "rmdir /s /q \"%s\" >nul 2>&1" % target, "set /a tries+=1",
		"if exist \"%s\" if %%tries%% lss 15 goto again" % target, "del \"%~f0\"",
	])
	file.store_string("\r\n".join(lines) + "\r\n")
	file.close()
	OS.create_process("cmd.exe", ["/c", _win(script)])
