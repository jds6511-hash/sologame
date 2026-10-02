extends GutTest


func test_reset_releases_streams_and_can_play_again() -> void:
	BgmManager.play_track(&"field_eastern_frontier_south", 0.0, 0.0)
	BgmManager.play_fanfare()
	BgmManager.reset()
	for player in BgmManager._players:
		assert_null(player.stream)
		assert_false(player.playing)
	assert_null(BgmManager._fanfare_player.stream)
	BgmManager.play_track(&"field_eastern_frontier_south", 0.0, 0.0)
	assert_true(BgmManager.is_playing())
	BgmManager.reset()
