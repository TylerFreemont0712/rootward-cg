extends GdUnitTestSuite
## Container margins belong to the container. Portrait motion offsets the frame and always returns to live layout.

const PERSON := {"name": "Pip", "portrait": "pip", "voice": 1.0}

var _dialogue: DialogueBox
var _old_reduced_motion := false


func before_test() -> void:
	_old_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = false
	_dialogue = auto_free(DialogueBox.new())
	add_child(_dialogue)
	_dialogue.set_process(false)
	_dialogue.size = Vector2(1920, 1080)
	await _frames(2)


func after_test() -> void:
	Settings.reduced_motion = _old_reduced_motion


func test_happy_hop_preserves_child_padding_and_returns_to_neutral_alignment() -> void:
	_say("normal")
	await _frames(2)
	var child_origin := _dialogue._portrait.position
	assert_vector(child_origin).is_equal(Vector2(6, 6))
	_step_motion(1.0)
	var neutral := _dialogue._portrait_frame.position
	_say("happy")
	_step_motion(0.04)
	assert_float(_dialogue._portrait_frame.position.y).is_less(neutral.y)
	assert_vector(_dialogue._portrait.position).is_equal(child_origin)
	_step_motion(1.0)
	assert_vector(_dialogue._portrait.position).is_equal(child_origin)
	assert_vector(_dialogue._portrait_frame.position).is_equal(neutral)


func test_resize_during_hop_and_slide_uses_the_new_layout_baseline() -> void:
	_say("happy")
	await _frames(2)
	var child_origin := _dialogue._portrait.position
	_step_motion(0.04)
	_dialogue._box.offset_top -= 80.0
	_dialogue._layout()
	assert_float(_dialogue._portrait_frame.position.y).is_less(_baseline().y)
	_step_motion(1.0)
	assert_vector(_dialogue._portrait_frame.position).is_equal(_baseline())
	assert_vector(_dialogue._portrait.position).is_equal(child_origin)


func test_repeated_happy_lines_and_neutral_interruption_do_not_accumulate_offsets() -> void:
	_say("happy")
	await _frames(2)
	var child_origin := _dialogue._portrait.position
	_step_motion(0.04)
	var first := _dialogue._hop
	_dialogue._show_line()
	_pause_motion()
	assert_bool(first.is_valid()).is_false()
	_step_motion(0.04)
	_dialogue._lines[0].mood = "normal"
	_dialogue._show_line()
	_pause_motion()
	_step_motion(1.0)
	assert_vector(_dialogue._portrait_frame.position).is_equal(_baseline())
	assert_vector(_dialogue._portrait.position).is_equal(child_origin)


func test_finish_and_replacement_conversation_cancel_portrait_motion() -> void:
	_say("happy")
	await _frames(2)
	var child_origin := _dialogue._portrait.position
	_step_motion(0.04)
	_dialogue._finish()
	assert_vector(_dialogue._portrait_frame.position).is_equal(_baseline())
	assert_bool(_dialogue._hop == null or not _dialogue._hop.is_valid()).is_true()
	assert_bool(_dialogue._slide == null or not _dialogue._slide.is_valid()).is_true()
	_say("normal")
	_step_motion(1.0)
	assert_bool(_dialogue.visible).is_true()
	assert_bool(_dialogue.busy).is_true()
	assert_vector(_dialogue._portrait_frame.position).is_equal(_baseline())
	assert_vector(_dialogue._portrait.position).is_equal(child_origin)


func test_reduced_motion_does_not_slide_or_hop_the_portrait() -> void:
	Settings.reduced_motion = true
	_say("happy")
	await _frames(2)
	assert_vector(_dialogue._portrait_frame.position).is_equal(_baseline())
	assert_vector(_dialogue._portrait.position).is_equal(Vector2(6, 6))
	assert_float(_dialogue._portrait_frame.modulate.a).is_equal(1.0)
	assert_bool(_dialogue._hop == null or not _dialogue._hop.is_valid()).is_true()
	assert_bool(_dialogue._slide == null or not _dialogue._slide.is_valid()).is_true()


func test_enabling_reduced_motion_during_a_hop_restores_the_baseline() -> void:
	_say("happy")
	await _frames(2)
	_step_motion(0.04)
	Settings.reduced_motion = true
	_dialogue._process(0.0)
	assert_vector(_dialogue._portrait_frame.position).is_equal(_baseline())
	assert_vector(_dialogue._portrait.position).is_equal(Vector2(6, 6))
	assert_bool(_dialogue._hop == null or not _dialogue._hop.is_valid()).is_true()
	assert_bool(_dialogue._slide == null or not _dialogue._slide.is_valid()).is_true()


func _say(mood: String) -> void:
	_dialogue.say([{"text": "A short line.", "speaker": "", "mood": mood}], PERSON)
	_pause_motion()


func _pause_motion() -> void:
	for tween: Tween in [_dialogue._fade, _dialogue._slide, _dialogue._hop]:
		if tween != null and tween.is_valid():
			tween.pause()


func _step_motion(delta: float) -> void:
	for tween: Tween in [_dialogue._slide, _dialogue._hop]:
		if tween != null and tween.is_valid():
			tween.custom_step(delta)


func _baseline() -> Vector2:
	return Vector2(DialogueBox.PORTRAIT_X, _dialogue._box.position.y - DialogueBox.PORTRAIT - 4.0)


func _frames(count: int) -> void:
	for index: int in count:
		await get_tree().process_frame
