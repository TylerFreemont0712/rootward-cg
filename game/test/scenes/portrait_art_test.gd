extends GdUnitTestSuite
## One backdrop policy, complete silhouettes and bottom-aligned busts in every portrait consumer.


func _solid(color: Color, size := Vector2i(32, 32)) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func test_an_opaque_painting_keeps_its_exact_pixels_and_composition() -> void:
	var source := _solid(Color("#ad774b"))
	var result := PortraitArt.compose(source, _solid(Color.BLUE))
	assert_object(result).is_same(source)
	assert_bool(PortraitArt.needs_backdrop(source)).is_false()


func test_small_transparent_corners_do_not_reframe_an_existing_background() -> void:
	var source := _solid(Color("#ad774b"))
	source.set_pixel(0, 0, Color.TRANSPARENT)
	assert_bool(PortraitArt.needs_backdrop(source)).is_false()
	assert_object(PortraitArt.compose(source)).is_same(source)


func test_a_cutout_uses_the_shared_background_without_changing_its_source() -> void:
	var source := _solid(Color.TRANSPARENT)
	source.fill_rect(Rect2i(4, 6, 24, 18), Color.RED)
	var original := source.get_data()
	var background := _solid(Color.BLUE)
	var background_data := background.get_data()
	var result := PortraitArt.compose(source, background)
	assert_bool(PortraitArt.needs_backdrop(source)).is_true()
	assert_that(result.get_pixel(0, 0)).is_equal(Color.BLUE)
	assert_that(result.get_pixel(16, 31)).is_equal(Color.RED)
	assert_that(result.get_pixel(16, 16)).is_equal(Color.RED)
	assert_that(source.get_data()).is_equal(original)
	assert_that(background.get_data()).is_equal(background_data)


func test_framing_keeps_the_entire_subject_below_headroom_and_flush_with_the_bottom() -> void:
	for bounds: Rect2i in [Rect2i(1, 18, 126, 92), Rect2i(0, 0, 128, 128), Rect2i(12, 2, 92, 122)]:
		var frame := PortraitArt.framing(bounds, Vector2i(128, 128))
		assert_int(frame.end.y).is_equal(128)
		assert_int(frame.position.y).is_greater_equal(5)
		assert_int(frame.size.x).is_less_equal(128)
		assert_int(frame.position.x).is_greater_equal(0)
		assert_int(frame.end.x).is_less_equal(128)


func test_missing_backdrop_has_a_readable_opaque_fallback_and_soft_edges_blend() -> void:
	var source := _solid(Color(1, 0, 0, 0.5))
	var result := PortraitArt.compose(source)
	assert_float(result.get_pixel(0, 0).a).is_equal(1.0)
	var blended := result.get_pixel(16, 16)
	assert_float(blended.a).is_equal(1.0)
	assert_float(blended.r).is_greater(PortraitArt.FALLBACK.r)
	assert_float(blended.g).is_greater(0.0)


func test_registered_cutouts_are_cached_and_authored_backgrounds_stay_original() -> void:
	for id: String in ["nessa", "daro", "bram", "maribel", "innkeeper"]:
		var portrait := OverworldArt.portrait(id)
		assert_object(portrait).override_failure_message(id).is_not_null()
		assert_object(OverworldArt.portrait(id)).is_same(portrait)
		assert_bool(PortraitArt.needs_backdrop(portrait.get_image())).override_failure_message(id + " is opaque").is_false()
	var original := OverworldArt.texture(OverworldArt.ROOT + "portraits/tavi.png")
	assert_object(OverworldArt.portrait("tavi")).is_same(original)
	assert_object(OverworldArt.portrait("missing-portrait")).is_null()
