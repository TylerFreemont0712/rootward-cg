extends GdUnitTestSuite
## The player's language (ADR-0047): keys translate whole, formats before they are filled, and the rules' English
## sentences by matching the overlays' formats, with the names inside translated too.


func after_test() -> void:
	Text.setup("en")


func test_english_is_left_as_it_is() -> void:
	Text.setup("en")
	assert_str(Text.t("Amplify")).is_equal("Amplify")
	assert_str(Text.sentence("Tally Wisp takes 9.")).is_equal("Tally Wisp takes 9.")


func test_a_key_translates_and_an_unknown_line_stays_english() -> void:
	Text.setup("ja")
	assert_str(Text.t("Amplify")).is_equal("増幅")
	assert_str(Text.t("Not a line anyone translated")).is_equal("Not a line anyone translated")


func test_adult_japanese_uses_complete_translations_and_preserves_unknown_text() -> void:
	Text.setup("ja", "kanji")
	assert_str(Text.t("Japanese reading")).is_equal("日本語の表記")
	assert_str(Text.t("Choose a paradigm.")).is_equal("パラダイムを選ぼう。")
	assert_str(Text.apply_japanese_reading("まちがって いろいろ")).is_equal("まちがって いろいろ")
	assert_str(Text.apply_japanese_reading("`かず` \"まち\" codeWord")).is_equal("`かず` \"まち\" codeWord")
	assert_str(Text.apply_japanese_reading("中心 行動 山札")).is_equal("中心 行動 山札")
	assert_str(Text.apply_japanese_reading("なまえ")).is_equal("なまえ")
	assert_str(Text.t("Your name")).is_equal("名前を入力")
	assert_str(Text.t("Name")).is_equal("名前")
	Text.setup("ja", "hiragana")
	assert_str(Text.apply_japanese_reading("数 色 時間 番人 町 整数 行 辞書")).is_equal(
		"かず いろ じかん ばんにん まち せいすう ぎょう じしょ")
	assert_str(Text.apply_japanese_reading("60文字までだよ")).is_equal("60もじまでだよ")
	assert_str(Text.apply_japanese_reading("番人（ばんにん）")).is_equal("ばんにん")
	assert_str(Text.apply_japanese_reading("中心 行動 山札")).is_equal("中心 行動 山札")

func test_a_sentence_is_matched_to_its_format_and_its_names_translated() -> void:
	Text.setup("ja")
	assert_str(Text.sentence("Tally Wisp takes 9.")).is_equal("%sに9ダメージ。" % Text.t("Tally Wisp"))
	assert_str(Text.t("Tally Wisp")).is_not_equal("Tally Wisp")


func test_numbered_slots_put_the_values_in_the_translations_order() -> void:
	Text.setup("ja")
	var line := Text.sentence("Tally Wisp moves first: 28 ops is faster than your 111.")
	assert_str(line).is_equal("%sが先に動いた！ 28 opsは、きみの111より速い。" % Text.t("Tally Wisp"))


func test_a_log_line_of_several_sentences_is_translated_one_by_one() -> void:
	Text.setup("ja")
	var line := Text.sentences("Tally Wisp takes 9. Tally Wisp breaks apart. Something left in English.")
	var wisp := Text.t("Tally Wisp")
	assert_str(line).is_equal("%sに9ダメージ。%sはくだけ散った。Something left in English." % [wisp, wisp])


func test_a_format_is_translated_before_it_is_filled() -> void:
	assert_str(Text.fill("{2} / {1}", [1, 2])).is_equal("2 / 1")
	assert_str(Text.fill("%d of %d", [1, 2])).is_equal("1 of 2")
	assert_array(Text.split_sentences("A. B! C? D")).is_equal(["A.", "B!", "C?", "D"])
