extends SceneTree
## Visual review uses arranged positions and no player save.
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
var game: Node
func _initialize() -> void: call_deferred("run")
func take(file: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_jpg("res://docs/"+file,0.92)==OK)
func move_to(p: Vector2) -> void:
	game.state.player.x = p.x
	game.state.player.z = p.y
	game._sync_position()
	game._update_camera(1.0)
	game.ambience._process(0.1)
	game._update_moon_aura(1.0)
	game.update_hud()
	game.toast_label.hide()
func run() -> void:
	game = Scene.instantiate()
	game.save_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_level(false)
	game.music.stop()
	move_to(Layout.HUB+Vector2(0,2))
	await take("woodland-moonlit-artemis.jpg")
	move_to(Vector2(-118,-36.7))
	game.interact()
	game.frog_band.animate(0.7,true)
	await take("woodland-frog-band.jpg")
	move_to(Vector2(-65,-11))
	await take("woodland-squirrel.jpg")
	game.save_enabled = false
	game.music.stop()
	game.frog_song.stop_song()
	game.queue_free()
	for i in 3: await process_frame
	quit()
