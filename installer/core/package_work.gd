class_name PackageWork
extends RefCounted
## The slow parts of an install, run on a worker thread so the window keeps drawing: checking a download's
## SHA-256, unpacking a zip, putting a file in place. Each reports its progress through a Progress.

const CHUNK := 4 * 1024 * 1024
## rwxr-xr-x and rw-r--r-- (GDScript has no octal literals, so the permission bits are spelled out).
const EXECUTABLE := (FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER
	| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP | FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER)
const WRITABLE := (FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_READ_GROUP
	| FileAccess.UNIX_READ_OTHER)


class Progress:
	extends RefCounted
	var _mutex := Mutex.new()
	var _done := 0
	var _total := 0

	func set_total(total: int) -> void:
		_mutex.lock()
		_total = total
		_done = 0
		_mutex.unlock()

	func add(amount: int) -> void:
		_mutex.lock()
		_done += amount
		_mutex.unlock()

	func fraction() -> float:
		_mutex.lock()
		var value := 0.0 if _total <= 0 else clampf(float(_done) / float(_total), 0.0, 1.0)
		_mutex.unlock()
		return value


static func sha256(path: String, progress: Progress = null) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	if progress != null:
		progress.set_total(file.get_length())
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		var chunk := file.get_buffer(CHUNK)
		if chunk.is_empty():
			break
		hashing.update(chunk)
		if progress != null:
			progress.add(chunk.size())
	file.close()
	return hashing.finish().hex_encode()


## Unpacks `zip` into `dir`. Returns "" or what went wrong. Names that would leave `dir` are refused.
static func extract(zip: String, dir: String, executables: Array, progress: Progress) -> String:
	var reader := ZIPReader.new()
	if reader.open(zip) != OK:
		return "could not open %s" % zip.get_file()
	var names := reader.get_files()
	progress.set_total(names.size())
	for name in names:
		progress.add(1)
		if name.ends_with("/"):
			continue
		if name.begins_with("/") or name.contains("..") or name.contains(":") or name.contains("\\"):
			reader.close()
			return "the package has a file outside the game's folder: %s" % name
		var target := dir.path_join(name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var error := write_bytes(target, reader.read_file(name))
		if error != "":
			reader.close()
			return error
		if name in executables and not SetupPaths.windows():
			FileAccess.set_unix_permissions(target, EXECUTABLE)
	reader.close()
	return ""


## Writes a file, replacing one that is there even when it is marked read-only. Returns "" or the problem.
static func write_bytes(target: String, bytes: PackedByteArray) -> String:
	make_writable(target)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return "could not write %s (is Rootward still running?)" % target
	file.store_buffer(bytes)
	file.close()
	return ""


## Moves a finished download into place.
static func place(source: String, target: String) -> String:
	make_writable(target)
	if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
		return "could not replace %s (is Rootward still running?)" % target
	if DirAccess.rename_absolute(source, target) != OK and DirAccess.copy_absolute(source, target) != OK:
		return "could not put %s in place" % target.get_file()
	DirAccess.remove_absolute(source)
	return ""


static func make_writable(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	if SetupPaths.windows():
		FileAccess.set_read_only_attribute(path, false)
	else:
		FileAccess.set_unix_permissions(path, WRITABLE)


## Removes a folder and everything in it, read-only files included (the sandbox's Python library is marked so).
## Symbolic links are removed as links, never followed.
static func remove_tree(dir: String, keep: String = "") -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	access.include_hidden = true
	for name in access.get_directories():
		var sub := dir.path_join(name)
		if access.is_link(name):
			access.remove(name)
		else:
			remove_tree(sub, keep)
	for name in access.get_files():
		var path := dir.path_join(name)
		if path == keep:
			continue
		make_writable(path)
		access.remove(name)
	DirAccess.remove_absolute(dir)
