extends GdUnitTestSuite
## The v0.4 task editor, its Builder blocks and its results (ADR-0068): opened on the shortcuts task (an old task,
## kept as a fixture: test/fixtures/old_tasks), in a save folder of its own. The sandbox takes about 0.1 s per check, so a check is awaited with a generous timeout.

const ROOT := "user://test-task-editor"

var _task: Dictionary
var _catalog: Dictionary


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	_catalog = TestWorld.catalog(["shortcuts"])
	_task = _catalog.tasks.shortcuts
	CodeHints.remembered_open = false
	HintBox.remembered_open = false


func after_test() -> void:
	CodeHints.remembered_open = false
	HintBox.remembered_open = false
	Sound.silence()
	Game.reset()


func _state(style := OverworldState.BUILDER, language := "python") -> Dictionary:
	var state := OverworldState.fresh("kindle-hollow", Vector2i(18, 8), "right", language)
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


func test_the_hints_start_folded_with_the_first_one_earned() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var box := editor.hint_box()
	assert_bool(box.is_open()).is_false()
	assert_int(box.shown_count()).is_equal(1)
	assert_int(box.total()).is_equal(Tasks.hints(_task, 0).size())
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[0])
	assert_str(box.bar_text()).contains("1 of %d" % box.total())
	await _frames(2)


func test_a_failed_try_earns_the_next_hint_quietly() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var box := editor.hint_box()
	await editor.try_it()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[1])
	assert_bool(box.is_open()).override_failure_message("a failed try must not open the box").is_false()
	assert_bool(box.has_unseen()).is_true()
	await _frames(2)


func test_asking_for_a_hint_opens_the_box_on_it() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var box := editor.hint_box()
	assert_bool(box.reveal()).is_true()
	assert_bool(box.is_open()).is_true()
	assert_bool(box.has_unseen()).is_false()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[1])
	box.reveal()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[2])
	await _frames(2)


func test_every_hint_can_be_earned_and_no_more() -> void:
	var box := HintBox.new()
	add_child(box)
	var hints: Array[String] = ["one", "two", "three"]
	box.setup(hints)
	assert_bool(box.earn()).is_true()
	assert_bool(box.earn()).is_true()
	assert_bool(box.earn()).override_failure_message("nothing is left to earn").is_false()
	assert_int(box.shown_count()).is_equal(3)
	box.setup([])
	assert_bool(box.visible).override_failure_message("a stage without hints has no bar").is_false()
	await _frames(2)


func test_a_new_stage_starts_over_and_the_bar_remembers_open_for_the_run() -> void:
	var box := HintBox.new()
	add_child(box)
	var hints: Array[String] = ["one", "two"]
	box.setup(hints)
	box.reveal()
	assert_bool(HintBox.remembered_open).is_true()
	box.setup(hints)
	assert_int(box.shown_count()).is_equal(1)
	assert_bool(box.is_open()).override_failure_message("the next stage opens as the last was left").is_true()
	await _frames(2)


func test_the_open_box_is_last_in_the_editor_so_it_takes_the_mouse_first() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var box := editor.hint_box()
	box.set_open(true)
	await _frames(2)
	assert_bool(box.box_visible()).is_true()
	var body := box.next_button().get_parent().get_parent() as Control
	assert_object(body.get_parent()).is_same(editor)
	assert_int(body.get_index()).override_failure_message("the box is the editor's last child").is_equal(editor.get_child_count() - 1)
	box.set_open(false)
	assert_bool(box.box_visible()).is_false()
	await _frames(2)


func test_ctrl_h_folds_and_opens_the_hints() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var box := editor.hint_box()
	var press := InputEventKey.new()
	press.keycode = KEY_H
	press.ctrl_pressed = true
	press.pressed = true
	editor._input(press)
	assert_bool(box.is_open()).is_true()
	editor._input(press)
	assert_bool(box.is_open()).is_false()
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


# --- the Builder shows blocks, and its code arrives when it works (ADR-0085) ---------------------------------------------


## The Builder's answer for the shortcuts task, as its fixture has it.
func _answer(editor: TaskEditor) -> void:
	var blocks := editor.get("_blocks") as TaskBlocks
	blocks.set_toggle("menu", true)
	blocks.choose("menu_key", 1)
	blocks.choose("menu_panel", 1)


func test_learn_and_the_hints_are_folded_chips_until_the_player_opens_them() -> void:
	var editor := await _editor()
	var guide := editor.get("_guide") as LessonGuide
	assert_bool(guide.is_expanded()).is_false()
	assert_bool(guide.visible).override_failure_message("nothing of the notes takes room while folded").is_false()
	assert_bool(editor.hint_box().is_open()).is_false()
	var chip := guide.get("_toggle") as Button
	assert_str(chip.text).contains("Learn")
	assert_bool(chip.is_inside_tree()).override_failure_message("the chip sits in the editor's row of chips").is_true()
	guide.set_expanded(true)
	assert_bool(guide.visible).is_true()
	assert_bool((guide.get("_details") as ScrollContainer).visible).is_true()
	await _frames(2)


func test_the_builder_shows_only_blocks_and_keeps_its_code_behind_a_note() -> void:
	var editor := await _editor()
	var code := editor.get("_code") as LessonCode
	assert_object(editor.get("_blocks")).is_not_null()
	assert_bool(code.is_veiled()).is_true()
	assert_bool(code.editor.visible).is_false()
	assert_str(code.editor.text).override_failure_message("the code is not even in the editor").is_empty()
	# A try that does not work leaves it behind the note.
	await editor.try_it()
	await _frames(2)
	assert_bool(code.is_veiled()).is_true()
	await _frames(2)


func test_the_scribe_is_a_separate_screen_with_no_blocks_and_no_note() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var code := editor.get("_code") as LessonCode
	assert_object(editor.get("_blocks")).is_null()
	assert_bool(code.is_veiled()).is_false()
	assert_bool(code.editor.visible).is_true()
	assert_bool(code.editor.editable).is_true()
	await _frames(2)


func test_the_code_is_revealed_when_every_case_works_and_copies_of_the_chips_fly_to_it() -> void:
	var saved := Settings.reduced_motion
	Settings.reduced_motion = false
	var editor := await _editor()
	var code := editor.get("_code") as LessonCode
	_answer(editor)
	await editor.try_it()
	assert_bool(code.is_veiled()).is_false()
	assert_str(code.editor.text).is_equal(Tasks.source(_task, (editor.get("_blocks") as TaskBlocks).blocks(), "python"))
	await _frames(4)
	var fx := editor.get("_fx") as Control
	var mapped := Tasks.source_map(_task, (editor.get("_blocks") as TaskBlocks).blocks(), "python")
	assert_int(fx.get_child_count()).override_failure_message("a copy of each chip and each switch").is_equal((mapped.slots as Array).size() + (mapped.toggles as Array).size())
	# Each copy begins over its chip, inside the editor, and none is left once the reveal is over.
	var inside := (editor.get("_panel") as Control).get_global_rect().grow(4.0)
	for ghost: Node in fx.get_children():
		assert_bool(inside.has_point((ghost as Control).global_position)).is_true()
	await get_tree().create_timer(2.6).timeout
	assert_int(fx.get_child_count()).is_equal(0)
	assert_float(code.modulate.a).is_equal_approx(1.0, 0.001)
	Settings.reduced_motion = saved


func test_with_reduced_motion_the_code_is_simply_there() -> void:
	var saved := Settings.reduced_motion
	Settings.reduced_motion = true
	var editor := await _editor()
	_answer(editor)
	await editor.try_it()
	await _frames(3)
	assert_bool((editor.get("_code") as LessonCode).is_veiled()).is_false()
	assert_int((editor.get("_fx") as Control).get_child_count()).is_equal(0)
	Settings.reduced_motion = saved


func test_a_stage_that_passed_before_shows_its_code_from_the_start() -> void:
	var editor := await _editor(0, {"passed": 1, "source": "x", "language": "python"})
	assert_bool((editor.get("_code") as LessonCode).is_veiled()).is_false()
	assert_str((editor.get("_code") as LessonCode).editor.text).is_equal(Tasks.source(_task, (editor.get("_blocks") as TaskBlocks).blocks(), "python"))
	assert_int((editor.get("_fx") as Control).get_child_count()).is_equal(0)
	await _frames(2)


func test_the_builders_trips_do_not_name_a_line_of_code_the_player_cannot_see() -> void:
	var editor := await _editor()
	var blocks := editor.get("_blocks") as TaskBlocks
	blocks.set_toggle("menu", true)
	blocks.choose("menu_key", 2)
	await editor.try_it()
	await _frames(2)
	var results := editor.get("_results") as TaskResults
	for label: Label in results.find_children("*", "Label", true, false):
		assert_str(label.text.to_lower()).override_failure_message("no row says line: %s" % label.text).not_contains("(line ").not_contains("line 1:")
	assert_str((editor.get("_advice") as Label).text.to_lower()).not_contains("line ")
	await _frames(2)


func test_the_hints_pop_down_as_wide_as_the_chips_column_and_under_it() -> void:
	var editor := await _editor()
	var box := editor.hint_box()
	box.set_open(true)
	await _frames(3)
	var body := box.next_button().get_parent().get_parent() as Control
	var chips_row := box.get_parent() as Control
	var asks := chips_row.get_parent() as Control
	assert_float(body.global_position.x).is_equal_approx(asks.global_position.x, 2.0)
	assert_float(body.size.x).is_equal_approx(asks.size.x, 2.0)
	assert_bool(body.global_position.y >= chips_row.global_position.y + chips_row.size.y - 1.0).is_true()
	await _frames(2)


func test_every_code_line_of_the_blocks_starts_at_the_same_left_edge_inside_a_card_or_not() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	await _frames(3)
	var edges: Array[float] = []
	for row in (blocks.get("_column") as VBoxContainer).get_children():
		var body: Control = null
		var lines := (blocks.get("_group_lines") as Dictionary).values()
		for candidate: Variant in lines:
			if (row as Node).is_ancestor_of(candidate as Node):
				body = candidate as Control
		if body == null:
			body = (row as Node).get_child(1) as Control
		edges.append(body.global_position.x)
	assert_int(edges.size()).is_greater(1)
	for edge: float in edges:
		assert_float(edge).override_failure_message("lines start at %s" % [edges]).is_equal_approx(edges[0], 1.0)
	blocks.queue_free()
	await _frames(2)
