extends SceneTree
## Native visual QA. Requires a display and writes captures in docs/.
## godot --path . --script tools/capture-map-expansion.gd
const Scene = preload("res://main.tscn")
var game: Node
var captures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	game.update_hud()
	game._update_camera(1.0)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = game.get_viewport().get_texture().get_image()
	assert(image != null and image.get_width() == 1280)
	assert(image.save_jpg("res://docs/"+filename,0.92) == OK)
	captures.append(filename)

func run() -> void:
	assert(DisplayServer.get_name() != "headless","Run native visual QA with a display.")
	game = Scene.instantiate()
	game.save_enabled = false
	game.save_path = "user://map-capture-isolated.json"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.new_game(false)
	game.music.muted = true
	game.music.stop()
	game.toast_clock = 0.0
	game.toast_label.hide()
	game.clock = 8.0
	game.camera_distance = 17.0
	game.camera_pitch = -0.63
	var locations: Array = [
		[Vector2(-99,-88),"farwood-fern-hollow.jpg",PI+0.18],
		[Vector2(0,-105),"farwood-wind-stones.jpg",PI+0.18],
		[Vector2(104,-46),"farwood-willow-pool.jpg",PI+0.5],
		[Vector2(67,99),"farwood-sunwash.jpg",PI+0.18],
		[Vector2(-91,75),"farwood-elder-ring.jpg",PI+0.18]
	]
	for entry: Array in locations:
		var p: Vector2 = entry[0]
		game.state.player.x = p.x
		game.state.player.z = p.y
		game.body.position = Vector3(p.x,game.valley.height_at(p.x,p.y),p.y)
		game.camera_yaw = entry[2]
		game.faun.animate(0.016,false,false,false,game.clock)
		await capture(entry[1])
	game.show_journal()
	await capture("farwood-journal-map.jpg")
	print(JSON.stringify({"engine":Engine.get_version_info().string,"captures":captures,"display":DisplayServer.get_name(),"scope":"Native renders use isolated state and relocations. They establish appearance, not controller traversal or hardware frame rate."}))
	for tween in get_processed_tweens(): tween.kill()
	game.queue_free()
	for i in 3: await process_frame
	quit()
