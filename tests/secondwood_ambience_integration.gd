extends SceneTree
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
var game: Node
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(name: String, value: bool) -> void:
	print(("PASS " if value else "FAIL ")+name)
	if not value: failures.append(name)
func run() -> void:
	game = Scene.instantiate()
	game.save_enabled = false
	root.add_child(game)
	await process_frame
	game.start_level(false)
	game.set_physics_process(false)
	game.state.player.x = Layout.ARTEMIS.x
	game.state.player.z = Layout.ARTEMIS.y
	game.interact()
	check("Artemis first conversation accepts and explains Spring Vessel",game.state.artemis_accepted and game.toast_label.text.contains("Spring Vessel"))
	check("Moon glow uses layered rings and 22 motes",game.moon_motes.size()==22 and game.moon_aura.visible)
	check("Artemis bends head in response",game.artemis_bow>0)
	game.state.player.x = -118
	game.state.player.z = -40
	game.music.muted = false
	game.interact()
	check("E starts original frog song",game.frog_song.is_playing())
	game._physics_process(0.1)
	check("Three banjo-playing frogs present",game.frog_band.players.size()==3)
	game.interact()
	check("E stops frog song",not game.frog_song.is_playing())
	game.interact()
	game.show_pause()
	check("Pause stops song",game.paused and not game.frog_song.is_playing())
	game.resume_game()
	game.interact()
	game.toggle_sound()
	check("Mute stops song",game.music.muted and not game.frog_song.is_playing())
	game.interact()
	check("Muted frogs offer clear prompt",game.toast_label.text.contains("Turn sound on") and not game.frog_song.is_playing())
	game.toggle_sound()
	game.interact()
	game.set_pipes(true)
	check("Raising pipes stops song",not game.frog_song.is_playing())
	game.set_pipes(false)
	game.interact()
	game.state.player.x = 0
	game.state.player.z = 40
	game._physics_process(0.1)
	check("Walking away stops song",not game.frog_song.is_playing())
	check("Five squirrels and five ambient particle fields",game.ambience.squirrels.size()==5 and game.ambience.fields.size()==5)
	game.save_enabled = false
	game.queue_free()
	quit(1 if not failures.is_empty() else 0)
