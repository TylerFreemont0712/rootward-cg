extends GdUnitTestSuite
## Real cell transactions: pose and translation share progress, alternate boots, plant on arrival, then idle once.

var _reduced_motion := false


func before_test() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = false


func after_test() -> void:
	Settings.reduced_motion = _reduced_motion


func _walker(model := "male") -> Walker:
	var walker: Walker = auto_free(Walker.new(OverworldArt.player_character({"model": model})))
	add_child(walker)
	walker.set_process(false)
	walker.place(Vector2i(4, 4), "right")
	return walker


func _advance(walker: Walker, seconds: float) -> void:
	var tween: Tween = walker.get("_tween")
	tween.pause()
	tween.custom_step(seconds)


func _region(walker: Walker) -> Rect2:
	return (walker.get("_sprite") as Sprite2D).region_rect


func test_both_models_have_complete_native_art_and_opposite_step_phases() -> void:
	for model: String in ["male", "female"]:
		var sheet := OverworldArt.player_character({"model": model})
		assert_that(sheet.frame).is_equal(Vector2i(64, 96))
		assert_float(sheet.scale).is_equal(1.0)
		assert_int(sheet.ground).is_equal(93)
		assert_object(sheet.texture).is_not_null()
		assert_that(Vector2i(sheet.texture.get_size())).is_equal(Vector2i(768, 384))
		var image := sheet.texture.get_image()
		var directions := {}
		for way: String in ["down", "up", "left", "right"]:
			assert_bool(sheet.flipped(way)).is_false()
			var poses := {}
			for column in 12:
				var rect := Rect2i(column * 64, int(sheet.rows[way]) * 96, 64, 96)
				assert_bool(Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect)).is_true()
				var used := image.get_region(rect).get_used_rect()
				assert_bool(used.has_area()).is_true()
				assert_bool(used.position.x > 0 and used.end.x < 64).is_true()
				assert_int(used.end.y).is_between(89, 96)
				poses[hash(image.get_region(rect).get_data())] = true
			assert_int(poses.size()).is_greater_equal(5)
			var a := image.get_region(sheet.cell_step_rect(way, 0.5, 0))
			var b := image.get_region(sheet.cell_step_rect(way, 0.5, 1))
			assert_int(hash(a.get_data())).override_failure_message(model + "/" + way + " repeats the same foot").is_not_equal(hash(b.get_data()))
			directions[hash(image.get_region(sheet.rect(way, CharacterSheet.STAND)).get_data())] = true
		assert_int(directions.size()).is_equal(4)


func test_legacy_saved_parts_select_the_default_model() -> void:
	var old := {"outfit": "outfit/armor", "hair": "hair/spiky", "hat": "hat/kettle", "colours": {"skin": "skin_deep"}}
	assert_object(OverworldArt.player_character(old)).is_same(OverworldArt.player_character({"model": "male"}))
	assert_object(OverworldArt.player_character({})).is_same(OverworldArt.player_character({"model": "male"}))


func test_every_direction_moves_one_cell_and_finishes_planted_before_arrival_signal() -> void:
	for way: String in ["down", "up", "left", "right"]:
		var walker := _walker()
		var sheet := OverworldArt.player_character({"model": "male"})
		var from := walker.cell
		var to := from + Vector2i(BootsRules.STEPS[way])
		var arrivals: Array[Vector2i] = []
		walker.arrived.connect(func(at: Vector2i) -> void:
			arrivals.append(at)
			assert_bool(walker.moving).is_false()
			assert_that(walker.position).is_equal(Walker.feet(to))
			assert_that(_region(walker)).is_equal(Rect2(sheet.rect(way, CharacterSheet.STAND)))
		)
		walker.walk_to(to, way, 0.4)
		assert_that(_region(walker)).is_equal(Rect2(sheet.rect(way, CharacterSheet.STAND)))
		_advance(walker, 0.2)
		assert_that(walker.position).is_equal(Walker.feet(from).lerp(Walker.feet(to), 0.5))
		assert_that(_region(walker)).is_equal(Rect2(sheet.cell_step_rect(way, 0.5, 0)))
		# An independent render/idle clock cannot advance the step's pose.
		walker._process(10.0)
		assert_that(_region(walker)).is_equal(Rect2(sheet.cell_step_rect(way, 0.5, 0)))
		_advance(walker, 0.21)
		assert_array(arrivals).contains_exactly([to])
		walker._arrive()
		assert_int(arrivals.size()).is_equal(1)


func test_consecutive_cells_alternate_boots_and_a_new_step_interrupts_idle() -> void:
	var walker := _walker()
	var sheet := OverworldArt.player_character({"model": "male"})
	walker.walk_to(Vector2i(5, 4), "right", 0.4)
	_advance(walker, 0.41)
	walker._process(0.21)
	assert_that(_region(walker)).is_equal(Rect2(sheet.animation_rect("right", "idle", 0.21)))
	walker.walk_to(Vector2i(6, 4), "right", 0.4)
	assert_bool(walker.moving).is_true()
	assert_that(_region(walker)).is_equal(Rect2(sheet.rect("right", CharacterSheet.STAND)))
	_advance(walker, 0.2)
	assert_that(_region(walker)).is_equal(Rect2(sheet.cell_step_rect("right", 0.5, 1)))
	_advance(walker, 0.21)
	walker.walk_to(Vector2i(6, 3), "up", 0.4)
	_advance(walker, 0.2)
	assert_that(_region(walker)).is_equal(Rect2(sheet.cell_step_rect("up", 0.5, 0)))
	assert_int((walker.get("_art") as Node2D).get_child_count()).is_equal(1)


func test_idle_blinks_briefly_once_then_holds_the_planted_rest() -> void:
	var walker := _walker("female")
	var sheet := OverworldArt.player_character({"model": "female"})
	walker.walk_to(Vector2i(5, 4), "right", 0.1)
	_advance(walker, 1.0)
	assert_float(float(walker.get("_clock"))).is_equal(0.0)
	walker._process(0.21)
	assert_int(sheet.animation_column("idle", 0.21)).is_equal(2)
	assert_that(_region(walker)).is_equal(Rect2(sheet.animation_rect("right", "idle", 0.21)))
	walker._process(0.2)
	var planted := _region(walker)
	walker._process(100.0)
	assert_that(_region(walker)).is_equal(planted)
	assert_int(sheet.animation_column("idle", 100.0)).is_equal(3)
	assert_float(sheet.animation_duration("idle")).is_equal_approx(0.38, 0.000001)


func test_step_sampler_plants_both_endpoints_and_keeps_all_phases_at_any_speed() -> void:
	var sheet := OverworldArt.player_character({"model": "male"})
	for stride in 2:
		assert_int(sheet.cell_step_column(0.0, stride)).is_equal(0)
		assert_int(sheet.cell_step_column(1.0, stride)).is_equal(0)
		assert_int(sheet.cell_step_column(2.0, stride)).is_equal(0)
		assert_int(sheet.cell_step_column(0.2, stride)).is_equal(4 + 4 * stride)
		assert_int(sheet.cell_step_column(0.5, stride)).is_equal(5 + 4 * stride)
		assert_int(sheet.cell_step_column(0.75, stride)).is_equal(6 + 4 * stride)
	assert_float(Walker.STEP_TIME).is_equal_approx(0.176, 0.000001)


func test_invalid_steps_and_requests_during_travel_cannot_replace_the_active_cell() -> void:
	var walker := _walker()
	walker.walk_to(Vector2i(5, 5), "right")
	assert_bool(walker.moving).is_false()
	walker.walk_to(Vector2i(5, 4), "up")
	assert_bool(walker.moving).is_false()
	walker.walk_to(Vector2i(5, 4), "right", 0.4)
	var tween: Tween = walker.get("_tween")
	walker.walk_to(Vector2i(5, 3), "up")
	walker.face("left")
	walker.bump("left")
	assert_object(walker.get("_tween")).is_same(tween)
	assert_str(walker.facing).is_equal("right")
	assert_that(walker.cell).is_equal(Vector2i(5, 4))
	_advance(walker, 1.0)
	assert_that(walker.position).is_equal(Walker.feet(Vector2i(5, 4)))


func test_place_cancels_steps_and_bumps_without_offsets_or_stale_arrivals() -> void:
	var walker := _walker()
	var arrivals: Array[Vector2i] = []
	walker.arrived.connect(func(at: Vector2i) -> void: arrivals.append(at))
	walker.bump("left")
	_advance(walker, 0.025)
	assert_that((walker.get("_art") as Node2D).position).is_not_equal(Vector2.ZERO)
	walker.place(Vector2i(3, 3), "up")
	assert_that((walker.get("_art") as Node2D).position).is_equal(Vector2.ZERO)
	walker.walk_to(Vector2i(3, 2), "up", 0.4)
	_advance(walker, 0.2)
	walker.place(Vector2i(8, 8), "down")
	walker._arrive()
	assert_array(arrivals).is_empty()
	assert_that(walker.position).is_equal(Walker.feet(Vector2i(8, 8)))
	assert_int(int(walker.get("_stride"))).is_equal(0)


func test_arrival_callback_can_warp_without_being_overwritten() -> void:
	var walker := _walker()
	walker.arrived.connect(func(_at: Vector2i) -> void: walker.place(Vector2i(9, 9), "left"))
	walker.walk_to(Vector2i(5, 4), "right", 0.1)
	_advance(walker, 1.0)
	assert_that(walker.position).is_equal(Walker.feet(Vector2i(9, 9)))
	assert_str(walker.facing).is_equal("left")
	assert_int(int(walker.get("_stride"))).is_equal(0)


func test_arrival_callback_can_immediately_chain_the_next_cell() -> void:
	var walker := _walker()
	var sheet := OverworldArt.player_character({"model": "male"})
	var arrivals: Array[Vector2i] = []
	walker.arrived.connect(func(at: Vector2i) -> void:
		arrivals.append(at)
		if arrivals.size() == 1:
			walker.walk_to(at + Vector2i.RIGHT, "right", 0.4)
	)
	walker.walk_to(Vector2i(5, 4), "right", 0.4)
	_advance(walker, 0.41)
	assert_bool(walker.moving).is_true()
	assert_that(walker.cell).is_equal(Vector2i(6, 4))
	_advance(walker, 0.2)
	assert_that(_region(walker)).is_equal(Rect2(sheet.cell_step_rect("right", 0.5, 1)))
	_advance(walker, 0.21)
	assert_array(arrivals).contains_exactly([Vector2i(5, 4), Vector2i(6, 4)])
	assert_bool(walker.moving).is_false()


func test_missing_art_still_moves_and_legacy_cast_keeps_its_step_fallback() -> void:
	var walker: Walker = auto_free(Walker.new())
	add_child(walker)
	walker.place(Vector2i(2, 2))
	walker.walk_to(Vector2i(2, 3), "down", 0.1)
	_advance(walker, 1.0)
	assert_that(walker.position).is_equal(Walker.feet(Vector2i(2, 3)))
	assert_bool(walker.moving).is_false()
	var sheet := CharacterSheet.parts(null, Vector2i(25, 35))
	assert_int(sheet.cell_step_column(0.2, 0)).is_equal(1)
	assert_int(sheet.cell_step_column(0.5, 0)).is_equal(1)
	assert_int(sheet.cell_step_column(1.0, 0)).is_equal(0)


func test_sheet_replacement_preserves_travel_progress_and_reduced_motion_freezes_idle() -> void:
	var walker := _walker()
	walker.walk_to(Vector2i(5, 4), "right", 0.4)
	_advance(walker, 0.2)
	var at := walker.position
	var sheet := OverworldArt.player_character({"model": "female"})
	walker.set_sheet(sheet)
	assert_bool(walker.moving).is_true()
	assert_that(walker.position).is_equal(at)
	assert_that(_region(walker)).is_equal(Rect2(sheet.cell_step_rect("right", 0.5, 0)))
	_advance(walker, 0.21)
	Settings.reduced_motion = true
	walker._process(0.21)
	assert_that(_region(walker)).is_equal(Rect2(sheet.animation_rect("right", "idle", 0.0)))


func test_creator_preview_samples_the_same_per_cell_phases_as_walker() -> void:
	var preview: WalkPreview = auto_free(WalkPreview.new())
	add_child(preview)
	preview.set_process(false)
	preview.set_look({"model": "female"})
	preview.turning = false
	preview.facing = "up"
	var sheet := preview.figure()
	for stride in 4:
		for phase: float in [0.0, 0.2, 0.5, 0.75, 0.95]:
			preview.set("_clock", (stride + phase) * Walker.STEP_TIME)
			assert_that(preview.frame_region()).is_equal(sheet.cell_step_rect("up", phase, stride))
	Settings.reduced_motion = true
	assert_that(preview.frame_region()).is_equal(sheet.animation_rect("up", "idle", 0.0))


func test_creator_only_offers_male_and_female_and_saves_the_selected_sheet() -> void:
	var creator: CharacterCreator = auto_free(CharacterCreator.new())
	add_child(creator)
	creator.open(OverworldContent.load_world().catalog.looks, {}, "Tinker")
	assert_int((creator.get("_model_buttons") as Dictionary).size()).is_equal(2)
	creator._choose_model("female")
	assert_that(creator.look).is_equal({"model": "female"})
	assert_object(creator.preview_sheet()).is_same(OverworldArt.player_character({"model": "female"}))
	assert_str((creator.get("_name") as LineEdit).text).is_equal("Tinker")
