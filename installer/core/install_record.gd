class_name InstallRecord
extends RefCounted
## rootward-install.json in the game's folder: what this installer put there. An update downloads only packages
## whose hash changed; an uninstall removes the folder only when this file says the installer made it.

var version := ""
var platform := ""
var packages: Dictionary = {}  # package id -> sha256
var shortcuts: Array[String] = []
var registered := false


static func read(dir: String) -> InstallRecord:
	var path := SetupPaths.marker(dir)
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return null
	var record := InstallRecord.new()
	record.version = str(data.get("version", ""))
	record.platform = str(data.get("platform", ""))
	record.packages = data.get("packages", {})
	for shortcut: Variant in data.get("shortcuts", []):
		record.shortcuts.append(str(shortcut))
	record.registered = bool(data.get("registered", false))
	return record


func write(dir: String) -> bool:
	var file := FileAccess.open(SetupPaths.marker(dir), FileAccess.WRITE)
	if file == null:
		return false
	var data := {
		"version": version, "platform": platform, "packages": packages, "shortcuts": shortcuts,
		"registered": registered, "installed": Time.get_datetime_string_from_system(true),
	}
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()
	return true
