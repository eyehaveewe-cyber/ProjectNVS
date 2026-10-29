extends SceneTree
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
var game: Node
var captures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func capture(filename: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image!=null and image.get_width()>=1000)
	assert(image.save_jpg("res://docs/"+filename,0.92)==OK)
	captures.append(filename)
func relocate(p: Vector2) -> void:
	game.state.player.x = p.x
	game.state.player.z = p.y
	game._sync_position()
	game.update_hud()
	game._update_camera(1.0)
	game.toast_label.hide()
	game.toast_clock = 0
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	game = Scene.instantiate()
	game.save_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.start_level(false)
	game.music.muted = true
	game.music.stop()
	relocate(Layout.HUB)
	await capture("artemis-turning-glade.jpg")
	game.state.artemis_accepted = true
	game.state.inventory.assign(["vessel","spore","spindle","lens","spool"])
	game.state.healed.assign(["source","hollow","ash"])
	for item in game.items.values(): item.hide()
	game.map.sync(game.state.flags())
	game._sync_relics()
	relocate(Layout.LENS)
	await capture("artemis-mirror-wetland.jpg")
	game.state.relic_attunements.assign(["lens"])
	relocate(Layout.TARGETS["west-ridge-roots"].position)
	game.interact()
	game.set_pipes(true)
	game.state.lens_progress = 0.8
	game._update_lens_beam()
	game.update_hud()
	await capture("artemis-lens-progress.jpg")
	game.set_pipes(false)
	game._update_lens_beam()
	relocate(Layout.TARGETS["east-root-bridge"].position)
	game.interact()
	game.state.repair_anchors["east-root-bridge"] = [0]
	game._sync_relics()
	game.toast_label.hide()
	await capture("artemis-root-repair.jpg")
	game.state.crossings_complete.assign(["west-sluice","west-ridge-roots","east-root-bridge","ash-east-cut","south-return"])
	game.state.acorn_state = "planted"
	game.map.sync(game.state.flags())
	game._sync_relics()
	relocate(Layout.CROWN)
	await capture("artemis-young-canopy.jpg")
	game.show_journal()
	await capture("artemis-expanded-map.jpg")
	game.resume_game()
	relocate(Layout.ARTEMIS)
	game.state.artemis_finale_done = true
	game.show_ending()
	await capture("artemis-finale.jpg")
	var report := {"status":"passed","engine":Engine.get_version_info().string,"captures":captures,"scope":"Native rendered screenshots use explicit relocations and arranged quest fixtures for visual review. Separate progression report walks the real quest with zero relocations."}
	var file := FileAccess.open("res://docs/artemis-visual-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	game.music.stop()
	for tween in get_processed_tweens(): tween.kill()
	game.queue_free()
	for i in 3: await process_frame
	quit()
