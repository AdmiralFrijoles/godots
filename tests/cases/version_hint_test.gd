extends GdUnitTestSuite


func test_exact_equality() -> void:
	assert_bool(VersionHint.are_equal("4.2.2-stable-mono", "4.2.2-stable-mono")).is_true()
	assert_bool(VersionHint.are_equal("4.2.2-stable", "4.2.2-stable")).is_true()


func test_patch_zero_normalization() -> void:
	assert_bool(VersionHint.are_equal("4.5-stable-mono", "4.5.0-stable-mono")).is_true()
	assert_bool(VersionHint.are_equal("4.5.0-stable", "4.5-stable")).is_true()
	assert_bool(VersionHint.are_equal("4.0.0.0-stable", "4-stable")).is_true()


func test_mono_must_match_by_default() -> void:
	assert_bool(VersionHint.are_equal("4.2.2-stable-mono", "4.2.2-stable")).is_false()
	assert_bool(VersionHint.are_equal("4.2.2-stable-mono", "4.2.2-stable", true)).is_true()


func test_stage_must_match() -> void:
	assert_bool(VersionHint.are_equal("4.2.2-stable", "4.2.2-rc1")).is_false()


func test_different_versions_not_equal() -> void:
	assert_bool(VersionHint.are_equal("4.2.1-stable", "4.2.2-stable")).is_false()
	assert_bool(VersionHint.are_equal("4.5-stable", "4.6-stable")).is_false()
