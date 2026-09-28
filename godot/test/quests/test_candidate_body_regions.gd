extends GutTest

const Candidates = preload("res://scripts/tools/yeoulmok_candidate_assets.gd")


func _sheet() -> Image:
	var image := Image.create(120, 60, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(10, 10, 24, 30), Color.WHITE)
	image.fill_rect(Rect2i(60, 15, 30, 30), Color.WHITE)
	return image


func test_halos_and_external_specks_do_not_change_body_bounds() -> void:
	var image := _sheet()
	image.fill_rect(Rect2i(95, 0, 20, 60), Color(1, 1, 1, 0.2))
	image.set_pixel(0, 0, Color.WHITE)
	image.set_pixel(48, 20, Color.WHITE)
	assert_eq(Candidates.body_regions(image), [Rect2i(10, 10, 24, 30), Rect2i(60, 15, 30, 30)])


func test_missing_or_third_body_is_rejected() -> void:
	var image := _sheet()
	image.fill_rect(Rect2i(60, 15, 30, 30), Color.TRANSPARENT)
	assert_true(Candidates.body_regions(image).is_empty())
	image = _sheet()
	image.fill_rect(Rect2i(96, 10, 24, 30), Color.WHITE)
	assert_true(Candidates.body_regions(image).is_empty())
