extends SceneTree
## Visual review of the real scene at arranged locations; saves disabled.
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
var game: Node
func _initialize() -> void: call_deferred("run")
func capture(file: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_jpg("res://docs/"+file,0.92)==OK)
func relocate(p: Vector2) -> void:
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
	relocate(Vector2(-70,50))
	await capture("returning-wood-flowered-path.jpg")
	relocate(Vector2(-118.5,-37.6))
	await capture("returning-wood-frog-dale.jpg")
	relocate(Vector2(76,8))
	await capture("returning-wood-eastern-path.jpg")
	relocate(Vector2(-95,-108))
	await capture("returning-wood-ridge.jpg")
	relocate(Layout.HUB)
	await capture("returning-wood-artemis-glade.jpg")
	game.save_enabled = false
	game.music.stop()
	game.frog_song.stop_song()
	game.queue_free()
	for i in 3: await process_frame
	quit()
