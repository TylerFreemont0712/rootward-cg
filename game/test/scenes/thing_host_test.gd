extends GdUnitTestSuite
## A linked hook can answer while a thing's code editor stays open. The editor must keep its own target, so neither
## Close nor a second Run writes its program into the linked thing.

const ROOT := "user://test-thing-host"
const SOURCE := "def on_use(thing, player):\n    return {\"say\": \"source\"}\n"
const EDITED := "def on_use(thing, player):\n    return {\"say\": \"edited\"}\n"
const LINKED := "def on_change(thing, player):\n    return {\"say\": \"linked\"}\n"
const GATE := {"id": "gate", "kind": "prop", "at": [2, 2], "program": {"hook": "on_use", "fields": {}, "raises": []}}
const LAMP := {"id": "lamp", "kind": "prop", "at": [3, 2], "program": {"hook": "on_change", "fields": {}, "raises": []}}

var _host: ThingHost
var _editor: ThingEditor
var _state: Dictionary
var _answered: Array[String] = []


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	_state = OverworldState.fresh("test", Vector2i.ZERO, "down", BootsCode.PYTHON)
	_state.flags = {"first-action": true}
	_answered.clear()
	_host = ThingHost.new()
	add_child(_host)
	_host.setup({"gate": {"code": {"python": SOURCE}}, "lamp": {"code": {"python": LINKED}}}, func() -> Dictionary: return _state)
	_host.state_changed.connect(func(next: Dictionary) -> void: _state = next)
	_host.answered.connect(_on_answered)
	_editor = _host.get("_editor") as ThingEditor


func after_test() -> void:
	Background.finish_all()
	if is_instance_valid(_host):
		_host.queue_free()
	Sound.silence()
	await get_tree().process_frame
	Game.reset()


func test_close_after_a_linked_answer_keeps_code_on_the_edited_thing(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed",
) -> void:
	await _run_gate()
	(_editor.get("_code") as BootsCodePanel).show_code(EDITED)
	_editor.call("_close")
	assert_str(ThingHost.source_of(_state, "gate", "python", {})).is_equal(EDITED)
	assert_str(ThingHost.source_of(_state, "lamp", "python", {})).is_empty()


func test_run_after_a_linked_answer_still_runs_the_edited_thing(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed",
) -> void:
	await _run_gate()
	(_editor.get("_code") as BootsCodePanel).show_code(EDITED)
	_editor.call("_run_code")
	await _idle()
	assert_array(_answered).is_equal(["gate", "lamp", "gate", "lamp"])
	assert_str(ThingHost.source_of(_state, "gate", "python", {})).is_equal(EDITED)
	assert_str(ThingHost.source_of(_state, "lamp", "python", {})).is_empty()


func _run_gate() -> void:
	_host.edit(GATE, ["right"])
	_editor.call("_run_code")
	await _idle()
	assert_array(_answered).is_equal(["gate", "lamp"])


func _on_answered(thing: Dictionary, _verdict: Dictionary, depth: int) -> void:
	_answered.append(String(thing.id))
	if depth == 0 and String(thing.id) == "gate":
		_host.run_hook(LAMP, ["right"], "on_change", {}, 1)


func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while bool(_host.get("_running")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(bool(_host.get("_running"))).override_failure_message("linked hooks did not finish").is_false()
