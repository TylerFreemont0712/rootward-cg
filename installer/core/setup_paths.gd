class_name SetupPaths
extends RefCounted
## Where things go on this computer. Per user, no administrator needed: Windows puts per-user programs in
## %LOCALAPPDATA%\Programs (as VS Code and Discord do), Linux in the XDG data folder.

const MARKER := "rootward-install.json"


static func windows() -> bool:
	return OS.has_feature("windows")


static func platform() -> String:
	return "windows" if windows() else "linux"


static func default_dir() -> String:
	if windows():
		var local := OS.get_environment("LOCALAPPDATA")
		if local == "":
			local = OS.get_environment("USERPROFILE").path_join("AppData/Local")
		return local.replace("\\", "/").path_join("Programs/Rootward")
	var data := OS.get_environment("XDG_DATA_HOME")
	if data == "":
		data = OS.get_environment("HOME").path_join(".local/share")
	return data.path_join("Rootward")


## A folder the player picked: Rootward goes into a "Rootward" folder inside it, unless it is one already, so an
## uninstall can remove the whole folder without touching anything else that lives where the player pointed.
static func install_dir_for(chosen: String) -> String:
	var clean := chosen.replace("\\", "/").trim_suffix("/")
	return clean if clean.get_file().to_lower() == "rootward" else clean.path_join("Rootward")


static func game_exe(dir: String) -> String:
	return dir.path_join("Rootward.exe" if windows() else "Rootward.x86_64")


## The program to run for a check whose output must be read: Windows GUI programs have no console, so the export's
## console wrapper is used there.
static func check_exe(dir: String) -> String:
	return dir.path_join("Rootward.console.exe" if windows() else "Rootward.x86_64")


static func setup_exe(dir: String) -> String:
	return dir.path_join("Rootward Setup.exe" if windows() else "rootward-setup")


static func marker(dir: String) -> String:
	return dir.path_join(MARKER)


static func saves_dir() -> String:
	# Godot's own default for a game named Rootward; the game keeps it (CLAUDE.md).
	if windows():
		return OS.get_environment("APPDATA").replace("\\", "/").path_join("Godot/app_userdata/Rootward")
	var data := OS.get_environment("XDG_DATA_HOME")
	if data == "":
		data = OS.get_environment("HOME").path_join(".local/share")
	return data.path_join("godot/app_userdata/Rootward")


static func human_size(bytes: float) -> String:
	if bytes >= 1e9:
		return "%.1f GB" % (bytes / 1e9)
	if bytes >= 1e6:
		return "%.0f MB" % (bytes / 1e6)
	return "%.0f KB" % (bytes / 1e3)
