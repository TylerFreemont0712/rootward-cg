extends GdUnitTestSuite
## The v0.4 task editor, its Builder blocks and its results (Concept/v0.4): opened on the shortcuts task, in a save
## folder of its own. The sandbox takes about 0.1 s per check, so a check is awaited with a generous timeout.

const ROOT := "user://test-task-editor"

var _task: Dictionary
var _catalog: Dictionary


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	_catalog = OverworldContent.load_world().catalog
	_task = _catalog.tasks.shortcuts
	CodeHints.remembered_open = false


func after_test() -> void:
	CodeHints.remembered_open = false
	Sound.silence()
	Game.reset()


func _state(style := OverworldState.BUILDER, language := "python") -> Dictionary:
	var state := OverworldState.fresh("lanternroot", Vector2i(18, 8), "right", language)
	state.name = "Tinker"
	state.boots.style = style
	return state


func _editor(stage := 0, record := {}, state := {}) -> TaskEditor:
	var editor := TaskEditor.new()
	add_child(editor)
	editor.setup(_catalog)
	editor.open(_task, stage, record, state if not state.is_empty() else _state())
	await await_idle_frame()
	await await_idle_frame()
	return editor


func _frames(count: int) -> void:
	for i in count:
		await await_idle_frame()


func test_builder_blocks_make_the_source() -> void:
	var editor := await _editor()
	var blocks := editor.get("_blocks") as TaskBlocks
	assert_object(blocks).is_not_null()
	assert_str(editor.source()).is_equal(Tasks.source(_task, blocks.blocks(), "python"))
	blocks.set_toggle("menu", true)
	blocks.choose("menu_key", 1)
	blocks.choose("menu_panel", 1)
	await _frames(2)
	assert_str(editor.source()).contains('if key == "escape":').contains('return "menu"')
	assert_str(editor.source()).is_equal(Tasks.source(_task, blocks.blocks(), "python"))
	assert_str(editor.lesson_id()).is_equal("shortcuts")
	assert_bool(editor.is_open()).is_true()


func test_builder_passes_with_the_switch_and_the_choices() -> void:
	var editor := await _editor()
	var blocks := editor.get("_blocks") as TaskBlocks
	var passes: Array[Dictionary] = []
	editor.passed.connect(func(stage: int, record: Dictionary) -> void: passes.append({"stage": stage, "record": record}))
	blocks.set_toggle("menu", true)
	blocks.choose("menu_key", 1)
	blocks.choose("menu_panel", 1)
	await editor.try_it()
	await _frames(2)
	assert_int(passes.size()).override_failure_message("passed was emitted").is_equal(1)
	assert_int(int(passes[0].stage)).is_equal(0)
	var record: Dictionary = passes[0].record
	assert_str(String(record.source)).contains('"escape"')
	assert_str(String(record.language)).is_equal("python")
	assert_int(int(record.passed)).is_equal(1)
	assert_str((editor.get("_done") as Button).text).contains("✓")


func test_scribe_with_the_starter_fails_and_says_why() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var passes := []
	editor.passed.connect(func(_s: int, _r: Dictionary) -> void: passes.append(1))
	assert_str(editor.source()).is_equal(String(_task.code.python))
	await editor.try_it()
	await _frames(2)
	assert_array(passes).is_empty()
	var advice := (editor.get("_advice") as Label).text
	assert_str(advice).is_not_empty()
	var results := editor.get("_results") as TaskResults
	assert_bool(results.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == 'shortcut("escape")')).is_true()


func test_a_failed_try_shows_the_next_hint() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var first := editor.hint_text()
	assert_str(first).is_equal(Tasks.hints(_task, 0)[0])
	await editor.try_it()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[1])
	(editor.get("_next_hint") as Button).pressed.emit()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[2])
	await _frames(2)


func test_closing_hands_back_the_record() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var closed: Array[Dictionary] = []
	editor.closed.connect(func(record: Dictionary) -> void: closed.append(record))
	(editor.get("_code") as LessonCode).editor.text = "def shortcut(key):\n    return None  # mine\n"
	editor.close_editor()
	assert_int(closed.size()).is_equal(1)
	assert_str(String(closed[0].code.python)).contains("# mine")
	assert_str(String(closed[0].mode)).is_equal("code")
	assert_bool(editor.is_open()).is_false()


func test_blocks_hide_a_later_stage_at_stage_zero() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	assert_bool(blocks.is_slot_shown("menu_key")).is_true()
	assert_bool(blocks.is_slot_shown("bag_key")).is_false()
	assert_bool(blocks.is_toggle_shown("menu")).is_true()
	assert_bool(blocks.is_toggle_shown("bag")).is_false()
	var at_zero := blocks.lines_shown()
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 1)
	assert_bool(blocks.is_slot_shown("bag_key")).is_true()
	assert_bool(blocks.is_toggle_shown("bag")).is_true()
	assert_int(blocks.lines_shown()).is_greater(at_zero)
	await _frames(2)


func test_a_switch_dims_its_lines() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	var lines := (blocks.get("_group_lines") as Dictionary)["menu"] as Control
	assert_float(lines.modulate.a).is_equal_approx(TaskBlocks.DIM, 0.001)
	blocks.set_toggle("menu", true)
	assert_float(lines.modulate.a).is_equal(1.0)


func test_the_chips_show_the_choice_labels() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	var chip := blocks.chips["menu_panel"] as OptionButton
	var slot: Dictionary = _task.blocks.slots.menu_panel
	for i in chip.item_count:
		assert_str(chip.get_item_text(i)).is_equal(Tasks.choice_label(slot, i, "python"))


func test_glossary_for_a_task_has_three_sections() -> void:
	for language: String in ["python", "javascript"]:
		var sections := CodeGlossary.sections_for_task(_task, 0, language)
		assert_int(sections.size()).is_equal(3)
		assert_str(String(sections[0].entries[0].term)).is_equal(Tasks.signature(_task, 0, language))
		assert_bool((sections[2].entries as Array).is_empty()).is_false()


func test_experiment_runs_selected_input_without_awarding_progress() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE, "javascript"))
	var passes: Array = []
	editor.passed.connect(func(_stage: int, _record: Dictionary) -> void: passes.append(true))
	(editor.get("_code") as LessonCode).editor.text = 'function shortcut(key) { return "observed:" + key; }'
	var picker := editor.get("_case_picker") as OptionButton
	picker.select(1)
	picker.item_selected.emit(1)
	(editor.get("_prediction") as LineEdit).text = "my guess"
	await editor.practice_case()
	var said := (editor.get("_practice_output") as Label).text
	var selected: Dictionary = (editor.get("_practice_cases") as Array)[1]
	assert_str(said).contains('"observed:%s"' % String(selected.args[0])).contains("my guess")
	assert_array(passes).is_empty()
	assert_int(int(editor.record.get("passed", 0))).is_equal(0)
	assert_bool((editor.get("_try") as Button).disabled).is_false()


func test_experiment_cases_belong_only_to_current_stage() -> void:
	var editor := await _editor(1)
	var cases: Array = editor.get("_practice_cases")
	assert_int(cases.size()).is_equal((Tasks.stage(_task, 1).cases as Array).size())
	for case_data: Dictionary in cases:
		assert_int(int(case_data.stage)).is_equal(1)


func test_editing_during_a_check_does_not_award_the_old_program() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE, "javascript"))
	var passes: Array = []
	editor.passed.connect(func(_stage: int, _record: Dictionary) -> void: passes.append(true))
	var code := (editor.get("_code") as LessonCode).editor
	code.text = FileAccess.get_file_as_string("res://test/fixtures/tasks/shortcuts.js")
	editor.try_it()
	code.text = "function shortcut(key) { return null; }"
	while bool(editor.get("_running")):
		await _frames(1)
	await _frames(2)
	assert_array(passes).is_empty()
	assert_int(int(editor.record.get("passed", 0))).is_equal(0)
	assert_str((editor.get("_status") as Label).text).contains("changed while it ran")


func test_learning_guide_prediction_explains_and_can_be_retried() -> void:
	var guide := LessonGuide.new()
	add_child(guide)
	guide.setup({
		"idea": "A function gives a value back.",
		"steps": ["Read the argument."],
		"example": {"python": "def double(n):\n    return n * 2", "javascript": "function double(n) { return n * 2; }"},
		"predict": {"question": "double(3)?", "choices": ["3", "6"], "answer": 1, "explanation": "3 * 2 is 6."},
		"try": ["Try a different number."],
	}, "javascript")
	var choices := guide.get("_choices") as VBoxContainer
	(choices.get_child(0) as Button).pressed.emit()
	assert_str((guide.get("_feedback") as Label).text).contains("Trace").contains("3 * 2 is 6.")
	(choices.get_child(1) as Button).pressed.emit()
	assert_str((guide.get("_feedback") as Label).text).contains("Yes.")
	assert_str((guide.get("_example") as CodeEdit).text).contains("function double")
	guide.set_expanded(false)
	assert_bool((guide.get("_details") as ScrollContainer).visible).is_false()
	assert_bool((guide.get("_idea") as Label).visible).is_true()
