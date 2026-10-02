## 시작 화면 렌더와 준비 상태 연결 확인. 실제 저장 경로는 열지 않는다.
extends SceneTree

var finished := false

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	_run.call_deferred()

func _run() -> void:
	var boot = load("res://scenes/world/game_bootstrap.tscn").instantiate()
	root.add_child(boot)
	current_scene = boot
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://").path_join("../docs/qa/screenshots/product-start")
	DirAccess.make_dir_recursive_absolute(directory)
	var error := root.get_texture().get_image().save_png(directory.path_join("menu.png"))
	var args := OS.get_cmdline_user_args()
	var chapter := int(args[0]) if not args.is_empty() else 2
	boot._start(chapter, "user://product_chapter_preview")
	await process_frame
	await process_frame
	var world := current_scene
	var session = world.get_node("SaveSession")
	var snapshot: Dictionary = session.codec.capture(world.get_node("Player"), session.account.account_id)
	finished = error == OK and session.store.root == "user://product_chapter_preview" and session.codec.schema.character_error(snapshot, session.account) == ""
	await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png(directory.path_join("chapter-%d.png" % chapter))
	finished = finished and error == OK
	world.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("PRODUCT_START_PREVIEW_PASS" if finished else "PRODUCT_START_PREVIEW_FAIL")
	quit(0 if finished else 1)