extends GdUnitTestSuite


func test_parse_standard_builds() -> void:
	_assert_bulk([
		["4.2.2.stable.official.b09f793f5",       "v4.2.2-stable"],
		["4.5.stable.official",                   "v4.5-stable"],
		["4.0.beta4.official",                    "v4.0-beta4"],
		["4.0.rc1.official",                      "v4.0-rc1"],
		["3.5.3.stable.official",                 "v3.5.3-stable"],
		["4.7.dev3.official",                     "v4.7-dev3"],
	])


func test_parse_mono_builds() -> void:
	_assert_bulk([
		["4.2.2.stable.mono.official.b09f793f5",  "v4.2.2-stable-mono"],
		["4.5.stable.mono.official",              "v4.5-stable-mono"],
		["4.0.beta4.mono.official",               "v4.0-beta4-mono"],
	])


func test_parse_with_leading_blank_lines() -> void:
	assert_str(utils.parse_godot_version_output("\n4.2.2.stable.mono.official\n"))\
		.is_equal("v4.2.2-stable-mono")


func test_parse_failures() -> void:
	assert_str(utils.parse_godot_version_output("")).is_equal("")
	assert_str(utils.parse_godot_version_output("not a version")).is_equal("")


func _assert_bulk(cases: Array) -> void:
	for c: Array in cases:
		assert_str(utils.parse_godot_version_output(c[0] as String)).is_equal(c[1] as String)
