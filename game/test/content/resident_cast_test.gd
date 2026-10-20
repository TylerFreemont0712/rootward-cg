extends GdUnitTestSuite
## Authored v0.5 residents keep stable sheet identities, full directional art and ordinary placeable people data.

const RESIDENTS: Array[String] = [
	"tavi", "merrit", "oren", "sumi", "rowan", "halen", "keir", "maribel",
	"nessa", "bram", "ilya", "lio", "amaya", "viola", "daro",
]

var _world: Dictionary = {}


func before() -> void:
	_world = OverworldContent.load_world()


func test_residents_keep_named_art_and_complete_placeable_catalog_entries() -> void:
	var entries: Dictionary = Jsonc.parse_file(StudioAssets.PATH).value.assets
	var index := OverworldArt.cast_index()
	for id: String in RESIDENTS:
		assert_bool(_world.catalog.townsfolk.has(id)).override_failure_message(id).is_true()
		var person: Dictionary = _world.catalog.townsfolk.get(id, {})
		assert_str(String(person.get("look", {}).get("cast", ""))).override_failure_message(id).is_equal(id)
		assert_str(OverworldArt.cast_file(index, person.look)).override_failure_message(id).is_equal(id + ".png")
		assert_str(String(entries.get(id, {}).get("kind", ""))).override_failure_message(id).is_equal("person")
		assert_array(entries[id].place).contains(["indoor", "outdoor"])
		assert_str(String(entries[id].category)).is_equal("people")
		assert_str(String(person.talk)).is_equal(id)
		assert_array(Talk.problems(_world.catalog.talk[id])).override_failure_message(id).is_empty()


func test_resident_art_has_four_grounded_views_and_a_portrait() -> void:
	for id: String in RESIDENTS:
		var sheet := OverworldArt.character(_world.catalog.townsfolk[id].look)
		assert_object(sheet.texture).override_failure_message(id).is_not_null()
		if sheet.texture == null:
			continue
		assert_that(Vector2i(sheet.texture.get_size())).override_failure_message(id).is_equal(Vector2i(128, 384))
		assert_that(sheet.frame).is_equal(Vector2i(64, 96))
		assert_int(sheet.ground).is_equal(93)
		assert_float(sheet.scale).is_equal(1.0)
		for facing: String in ["down", "up", "left", "right"]:
			var frame := sheet.texture.get_image().get_region(sheet.rect(facing, CharacterSheet.STAND))
			var bounds := frame.get_used_rect()
			assert_bool(bounds.has_area()).override_failure_message(id + ": " + facing).is_true()
			assert_int(bounds.end.y).override_failure_message(id + " feet remain inside frame").is_less_equal(94)
		assert_object(OverworldArt.portrait(id)).override_failure_message(id + " portrait").is_not_null()
		assert_object(StudioThumbs.thumb(id, "person")).override_failure_message(id + " builder thumbnail").is_not_null()


func test_new_residents_do_not_appear_on_maps_or_receive_schedules_until_placed() -> void:
	for id: String in RESIDENTS:
		assert_bool(_world.catalog.schedules.has(id)).override_failure_message(id).is_false()
		for map_id: String in _world.catalog.maps:
			for person: Dictionary in _world.catalog.maps[map_id].people:
				assert_str(String(person.id)).override_failure_message(id + " must be placed deliberately").is_not_equal(id)
