extends SceneTree
## Native visual QA with isolated saves. Requires a display.
const Start = preload("res://start.tscn")
const Scene = preload("res://secondwood.tscn")
var game: Node
var captures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image != null and image.get_width()>=1000)
	assert(image.save_jpg("res://docs/"+filename,0.92)==OK)
	captures.append(filename)

func relocate(p: Vector2) -> void:
	game.state.player.x = p.x
	game.state.player.z = p.y
	game._sync_position()
	game.update_hud()
	game._update_camera(1.0)
	game.toast_label.hide()
	game.toast_clock = 0.0

func run() -> void:
	assert(DisplayServer.get_name()!="headless","Native visual QA needs a display.")
	var selection: Control = Start.instantiate()
	selection.save_paths = {"valley":"user://capture-valley-isolated.json","secondwood":"user://capture-secondwood-isolated.json"}
	root.add_child(selection)
	await capture("secondwood-level-select.jpg")
	selection.queue_free()
	for i in 3: await process_frame
	game = Scene.instantiate()
	game.save_enabled = false
	game.save_path = "user://capture-secondwood-isolated.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_level(false)
	game.music.muted = true
	game.music.stop()
	relocate(Vector2(0,40))
	await capture("secondwood-turning-glade.jpg")
	game.show_journal()
	await capture("secondwood-routes-locked.jpg")
	game.resume_game()
	relocate(Vector2(-78,30))
	await capture("secondwood-western-curl.jpg")
	relocate(Vector2(-15,25))
	await capture("secondwood-source-before.jpg")
	game.state.inventory.append("vessel")
	game.interact()
	await create_timer(1.8).timeout
	game.toast_label.hide()
	await capture("secondwood-source-after.jpg")
	game.state.inventory.assign(["vessel","spore","spindle"])
	game.state.healed.assign(["source","hollow","ash"])
	game.map.sync(game.state.healed)
	game.update_hud()
	game.show_journal()
	await capture("secondwood-routes-open.jpg")
	game.resume_game()
	relocate(Vector2(54,-63))
	game.set_pipes(true)
	for pitch: int in game.FINAL_PHRASE: game.play_midi(pitch)
	await capture("secondwood-complete.jpg")
	var report: Dictionary = {"status":"passed","engine":Engine.get_version_info().string,"captures":captures,"display":DisplayServer.get_name(),"scope":"Native visual captures use isolated saves, explicit relocations and arranged state. They establish appearance. Separate progression and controller reports exercise the real journey."}
	var file := FileAccess.open("res://docs/secondwood-visual-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	game.save_enabled = false
	game.music.stop()
	for tween in get_processed_tweens(): tween.kill()
	game.queue_free()
	for i in 3: await process_frame
	quit()
