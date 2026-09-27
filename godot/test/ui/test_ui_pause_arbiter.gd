extends GutTest

const PATH := "res://scripts/ui/ui_pause_arbiter.gd"


func after_each() -> void:
	get_tree().paused = false


func test_exclusive_owners_external_pause_and_late_release() -> void:
	assert_true(ResourceLoader.exists(PATH))
	if not ResourceLoader.exists(PATH):
		return
	var arbiter = load(PATH).new()
	add_child_autofree(arbiter)
	var owners := [Node.new(), Node.new(), Node.new()]
	for owner in owners:
		add_child_autofree(owner)
	for first in owners:
		for second in owners:
			if first == second:
				continue
			assert_true(arbiter.acquire(first))
			assert_false(arbiter.acquire(second))
			arbiter.release(second)
			assert_true(get_tree().paused)
			arbiter.release(first)
			assert_false(get_tree().paused)
	get_tree().paused = true
	assert_false(arbiter.acquire(owners[0]))
	get_tree().paused = false
	assert_true(arbiter.acquire(owners[0]))
	var previous: Node = arbiter.suspend()
	assert_eq(previous, owners[0])
	var next = load(PATH).new()
	add_child_autofree(next)
	assert_true(next.acquire(owners[1]))
	arbiter.release(owners[0])
	assert_true(get_tree().paused)
	next.release(owners[1])
	assert_true(arbiter.acquire(owners[0]))
	owners[0].free()
	assert_false(get_tree().paused)
