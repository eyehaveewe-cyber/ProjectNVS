extends SceneTree
## Run Godot --headless --path . --script tests/godot_smoke.gd
## Add -- --capture with a real display to save native screenshots.
const Scene = preload("res://main.tscn")
const State = preload("res://scripts/grove_state.gd")
var checks: Array[String] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(label: String, condition: bool) -> void:
	if condition:
		checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func screenshot(game: Node, filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name()=="headless":
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = game.get_viewport().get_texture().get_image()
	check("Native screenshot "+filename,image!=null and image.get_width()>0)
	image.save_jpg("res://docs/"+filename,0.9)

func _run() -> void:
	var game: Node = Scene.instantiate()
	root.add_child(game)
	game.save_enabled = false
	await process_frame
	check("Root project loads the native main scene",game.valley.definitions.size()==9)
	check("Native faun has all animated joints",game.faun.joints.size()==7)
	check("World includes native mesh surfaces",game.valley.heart.mesh.get_surface_count()==1)
	check("Solid scenery has matching colliders",game.valley.colliders.size()>100)
	check("Native MBean pipe bank contains playable notes",game.music.tones.size()==14)
	var wave: AudioStreamWAV = game.music.tones[69]
	var maximum: int = 0
	for i in range(0,wave.data.size(),2):
		maximum = maxi(maximum,absi(wave.data.decode_s16(i)))
	check("Native pipe bank contains nonzero finite PCM",maximum>100 and maximum<32767)
	game.new_game(false)
	game.set_physics_process(false)
	await screenshot(game,"godot-gameplay.jpg")
	var start := Vector2(float(game.state.player.x),float(game.state.player.z))
	var movement := InputEventKey.new()
	movement.keycode = KEY_D
	movement.physical_keycode = KEY_D
	movement.pressed = true
	Input.parse_input_event(movement)
	await process_frame
	game._physics_process(0.25)
	check("Native walking responds to keyboard input",Vector2(float(game.state.player.x),float(game.state.player.z)).distance_to(start)>0.3)
	movement.pressed = false
	Input.parse_input_event(movement)
	game.set_pipes(false)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	check("Native Space input raises the pipes",game.playing)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_SPACE
	release.keycode = KEY_SPACE
	release.pressed = false
	Input.parse_input_event(release)
	var completed: int = 0
	for site in game.state.definitions:
		game.state.player.x = float(site.x)
		game.state.player.z = float(site.z)+1.5
		game.body.position = Vector3(float(site.x),game.valley.height_at(float(site.x),float(site.z)),float(site.z)+1.5)
		game.set_pipes(true)
		game.play_note(3)
		check("Wrong note does not heal "+str(site.id),game.state.healed.size()==completed)
		game.set_pipes(true)
		for index in site.sequence:
			game.play_note(int(index))
		completed += 1
		check("Native music restores "+str(site.id),game.state.healed.size()==completed)
		if completed==1:
			await screenshot(game,"godot-restoration.jpg")
	check("All sanctuaries still require the final heart song",not game.state.won)
	game.state.player.x = 0.0
	game.state.player.z = 2.0
	game.body.position = Vector3(0,game.valley.height_at(0,2),2)
	game._update_camera(1.0)
	game.set_pipes(true)
	for index in game.HEART:
		game.play_note(index)
	check("Final native heart song completes the journey",game.state.won and game.paused)
	await screenshot(game,"godot-ending.jpg")
	var record: Dictionary = game.state.serialize()
	var restored := State.new()
	restored.definitions = game.state.definitions
	restored.restore(JSON.parse_string(JSON.stringify(record)))
	check("Native save format round trips completed progress",restored.healed.size()==9 and restored.won)
	game.save_path = "user://nvs-smoke-temporary.json"
	game.save_enabled = true
	game.save_game()
	check("Native save writes a real journey file",FileAccess.file_exists(game.save_path))
	game.new_game(true)
	check("Continue loads the real native save",game.state.healed.size()==9 and game.state.won)
	game.save_enabled = false
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(game.save_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path+suffix))
	var broken := State.new()
	broken.definitions = game.state.definitions
	broken.restore({"player":{"x":"bad","energy":INF},"healed":["fake","grove-roots","grove-roots"]})
	check("Native save boundary rejects malformed values",broken.healed.size()==1 and broken.player.x==0.0 and broken.player.energy==1.0)
	game.resume_game()
	game.state.player.x = 0.0
	game.state.player.z = 4.0
	game.state.player.energy = 0.2
	game.state.player.comfort = 0.2
	game.rest()
	game.state.tick(2.0)
	check("Rest does not complete early",game.state.resting>0.0 and game.state.player.energy<0.3)
	game.state.tick(2.0)
	check("Timed native rest replenishes needs",game.state.resting==0.0 and game.state.player.energy>0.5)
	game.state.player.energy = 0.2
	game.rest()
	game.state.player.x = 10.0
	game.state.tick(4.0)
	check("Leaving camp cancels rest",game.state.player.energy<0.3)
	game.music.stop()
	# Let the audio server consume queued stop commands before tearing down the
	# test tree. This avoids a shutdown-only playback leak in fast dummy runs.
	await create_timer(0.15).timeout
	check("Pausing stops native audio voices",game.music.voices.is_empty())
	var report: Dictionary = {"engine":Engine.get_version_info().string,"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"note":"Native scene and restoration were exercised. Test relocates the faun between sites. No browser or Node runtime is used by this test."}
	var file := FileAccess.open("res://docs/godot-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report,"  "))
	for tween in get_processed_tweens():
		tween.kill()
	game.queue_free()
	for i in 3:
		await process_frame
	quit(0 if failures.is_empty() else 1)
