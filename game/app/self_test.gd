class_name SelfTest
extends RefCounted
## `Rootward -- --self-test` (on Windows `Rootward.console.exe -- --self-test`, which keeps a console): loads the
## content from wherever this build keeps it, finds the sandbox, and runs every card's and shard's worked examples in
## each language it has, then quits with 0 when all of them gave the bolts their examples promise, 1 otherwise.
## It proves a build works on a machine without playing it: the .pck holds the content, wasmtime starts, and Python,
## JavaScript and C++ all run (scripts/build.sh and the Windows check in .github/workflows/ run it).

const FLAG := "--self-test"


static func requested() -> bool:
	return OS.get_cmdline_user_args().has(FLAG)


static func run() -> int:
	var started := Time.get_ticks_msec()
	var version := str(ProjectSettings.get_setting("application/config/version", "?"))
	print("Rootward %s self-test on %s (%s)" % [version, OS.get_name(), "exported" if OS.has_feature("template") else "from source"])
	print("sandbox runtime: %s" % Sandbox.runtime_dir())
	print("stdlib files marked read-only now: %d" % Sandbox.protect_stdlib())
	var loaded := ContentLoader.load_shardrun()
	var catalog: Dictionary = loaded.catalog
	var diagnostics: Array[Dictionary] = []
	diagnostics.assign(loaded.diagnostics)
	var cards: Dictionary = (catalog.get("programs", {}) as Dictionary).get("cards", {})
	print("content: %d shards, %d program cards, %d relics, %d foes" % [
		(catalog.get("shards", {}) as Dictionary).size(), cards.size(),
		(catalog.get("relics", {}) as Dictionary).size(), (catalog.get("foes", {}) as Dictionary).size()
	])
	var languages: Array[String] = []
	for language: String in SandboxJob.LANGUAGES:
		var here := Sandbox.is_available(language)
		print("  %-10s %s" % [SandboxJob.NAMES[language], "ready" if here else "MISSING"])
		if here:
			languages.append(language)
	var failed := languages.size() < SandboxJob.LANGUAGES.size()
	if loaded.ok and not languages.is_empty():
		diagnostics.append_array(ShardExamples.check(catalog, languages))
	var errors := diagnostics.filter(func(d: Dictionary) -> bool: return d.severity == "error")
	for diagnostic: Dictionary in errors.slice(0, 20):
		print("  " + ContentLoader.describe(diagnostic))
	var examples := 0
	for shard: Dictionary in (catalog.get("shards", {}) as Dictionary).values() + cards.values():
		examples += (shard.get("examples", []) as Array).size()
	failed = failed or not loaded.ok or not errors.is_empty()
	print("%d worked examples x %d languages: %d error(s) in %.1fs -> %s" % [
		examples, languages.size(), errors.size(), (Time.get_ticks_msec() - started) / 1000.0,
		"FAILED" if failed else "OK"
	])
	return 1 if failed else 0
