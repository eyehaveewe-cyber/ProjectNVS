extends SceneTree
## Native scene integration. The faun is relocated between optional discoveries;
## squirrel travel and gameplay inputs still run through their real systems.
## Godot --headless --path . --script tests/woodland_expansion.gd
## With an X display, append -- --capture to write native screenshots.
const Scene = preload("res://main.tscn")
const State = preload("res://scripts/grove_state.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var captures: Array[String] = []
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(label: String, condition: bool) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func relocate(p: Vector2) -> void:
	game.state.player.x = p.x
	game.state.player.z = p.y
	game.body.position = Vector3(p.x,game.valley.height_at(p.x,p.y),p.y)
	game._update_camera(1.0)

func key(keycode: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func phrase(keys: Array) -> void:
	for keycode: int in keys:
		await key(keycode)
		await key(keycode,false)

func tick(seconds: float, step: float = 0.05) -> void:
	for i in ceili(seconds/step):
		game.clock += step
		game.journey.tick(step,game.clock)

func screenshot(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name()=="headless": return
	game.update_hud()
	game._update_camera(1.0)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = game.get_viewport().get_texture().get_image()
	var valid: bool = picture!=null and picture.get_width()>=1000
	check("Native rendered capture "+filename,valid)
	if valid:
		picture.save_jpg("res://docs/"+filename,0.91)
		captures.append(filename)

func run() -> void:
	game = Scene.instantiate()
	root.add_child(game)
	game.save_enabled = false
	game.save_path = "user://woodland-integration-temporary.json"
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	game.new_game(false)
	check("Native scene includes a 250-unit woodland and expanded connected trails",game.valley.bounds==125.0 and game.valley.expansion.paths.size()>6)
	check("Optional squirrel pursuit has six waypoints",game.journey.route.size()==6)
	check("Woodland retains eighteen seeds and adds outer-country pickups",game.journey.seeds.size()>18)
	check("Dryads and giant Artemis exist as native 3D actors",game.journey.cast.dryads.size()==2 and game.journey.cast.artemis.scale.x>3.0)
	check("Artemis remains hidden before three restorations",not game.journey.cast.artemis.visible)

	# Keyboard notes must win over walk-mode journal/rest shortcuts.
	relocate(Vector2(0,4))
	await key(KEY_TAB)
	await key(KEY_TAB,false)
	await key(KEY_J)
	await key(KEY_E)
	check("Holding J and E plays a chord without opening journal or starting rest",game.playing and not game.paused and game.state.resting==0 and game.held_keys.size()==2 and game.music.held.size()==2)
	await key(KEY_E,false)
	await key(KEY_J,false)
	check("Physical key releases clear held notes",game.held_keys.is_empty() and game.music.held.is_empty())
	await key(KEY_J)
	await key(KEY_TAB)
	await key(KEY_TAB,false)
	await key(KEY_J,false)
	check("Lowering pipes with Tab releases every held note",not game.playing and game.held_keys.is_empty() and game.music.held.is_empty())
	await key(KEY_TAB)
	await key(KEY_TAB,false)
	await key(KEY_J)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE,false)
	await key(KEY_J,false)
	check("Pause stops keyboard voices and clears held-key state",game.paused and game.held_keys.is_empty() and game.music.held.is_empty() and game.music.voices.is_empty())
	game.resume_game()
	game.set_pipes(false)
	await key(KEY_J)
	await key(KEY_J,false)
	var overview: Control = game.modal_box.find_child("WoodlandOverview",true,false)
	check("Walk-mode journal opens the labeled full woodland overview",game.paused and overview!=null and overview.map_size==420.0 and overview.label_clearings)
	var mapped_routes_fit: bool = overview!=null
	if overview!=null:
		var map_area := Rect2(Vector2(10,10),Vector2.ONE*(float(overview.map_size)-20.0))
		for route: Array in game.valley.expansion.paths:
			for point: Vector2 in route:
				mapped_routes_fit = mapped_routes_fit and map_area.has_point(overview._map(point))
	check("Whole-woodland overview keeps every route endpoint inside its map frame",mapped_routes_fit)
	game.resume_game()

	# Pickups are sparse and have permanent, unique IDs.
	relocate(game.journey.seeds[0])
	tick(0.1)
	tick(0.1)
	check("A seed pickup is collected once when approached twice",game.state.collected==["seed_00"] and not game.journey.seed_nodes[0].visible)
	check("Collecting seeds does not heal a sanctuary or unlock rain",game.state.healed.is_empty() and not game.state.rain_learned)

	# Knowing the melody alone must not bypass the squirrel discovery.
	relocate(Vector2(-58,-47))
	for pitch: int in game.journey.RAIN: game.play_midi(pitch)
	check("Playing Raincall before following the squirrel does not unlock or cast rain",not game.state.rain_learned and game.journey.rain_left==0)
	game.set_pipes(false)
	relocate(game.journey.route[0])
	tick(0.05)
	check("Approaching the squirrel begins its first real travel leg",game.state.squirrel_stage==1)
	for stage in range(1,game.journey.route.size()):
		# Observe every route waypoint as the animal crosses it. Short legs
		# can automatically advance while the faun remains within four units.
		var destination: Vector2 = game.journey.route[stage]
		var reached: bool = false
		for frame in 160:
			tick(0.05)
			if Vector2(game.journey.cast.squirrel.position.x,game.journey.cast.squirrel.position.z).distance_to(destination)<0.2:
				reached = true
				break
		check("Squirrel physically reaches trail waypoint %d" % stage,reached)
		relocate(destination)
		tick(0.15)
		if stage==3:
			relocate(destination+Vector2(0,3.0))
			game.camera_distance = 17
			game.camera_pitch = -0.55
			await screenshot("woodland-trail.jpg")
	check("Completing all six squirrel waypoints unlocks Raincall",game.state.rain_learned and game.state.squirrel_stage==5)
	game.music.stop()
	game.set_pipes(true)
	await phrase([KEY_Q,KEY_Q,KEY_E,KEY_T])
	check("An unrelated phrase does not cast rain",game.journey.rain_left==0)
	await phrase([KEY_W,KEY_R,KEY_I,KEY_U,KEY_R,KEY_W])
	check("Physical MBean keyboard Raincall starts a forty-five-second shower",game.journey.rain_left==45.0)

	# Rain starts small growth at the stump nursery, then grows it over time.
	relocate(game.journey.NURSERY+Vector2(1,3))
	tick(0.05)
	check("Rain nurtures the nursery without instantly making mature plants",game.state.nursery_watered and game.journey.growth>0 and game.journey.growth<0.1 and game.journey.sprouts[0].visible)
	var initial_growth: float = game.journey.growth
	tick(5.0)
	check("Nursery regrowth progresses over several seconds",game.journey.growth>initial_growth and game.journey.growth<1.0)
	check("Rain has native falling drops and a timed lifetime",game.journey.rain_mesh.visible and game.journey.drops.size()==150 and game.journey.rain_left<45)
	game.camera_distance = 17
	await screenshot("woodland-rain.jpg")
	tick(10.0)
	check("The nursery reaches its full small-sprout state",is_equal_approx(game.journey.growth,1.0))

	# The oily wildlife uses its own phrase, entered through real physical keys.
	relocate(game.journey.OIL_SPOT+Vector2(0,2))
	check("Approaching the oily fox exposes a distinct healing interaction",game.journey.near_oil() and bool(game.journey.oily_animal.get_meta("oiled")))
	await phrase([KEY_Q,KEY_Q,KEY_Q])
	check("Wrong fox melody leaves the animal polluted",not game.state.wildlife_healed)
	await phrase([KEY_E,KEY_W,KEY_Q,KEY_W,KEY_E,KEY_U])
	check("Physical key phrase removes oil and records wildlife recovery",game.state.wildlife_healed and not bool(game.journey.oily_animal.get_meta("oiled")))
	check("Wildlife recovery starts a dancing woodland troupe",game.journey.cast.restored_sites.has("wildlife") and not game.journey.cast.celebrations.is_empty())
	tick(1.6)
	check("Nearby celebration animals remain visible",game.journey.cast.residents[0].visible)
	game.camera_distance = 15
	await screenshot("woodland-celebration.jpg")

	# Dryad dialogue does not become a music input or a rest action.
	game.set_pipes(false)
	relocate(Vector2(-55,10))
	tick(0.05)
	check("Distant restored residents are culled beyond forty units",not game.journey.cast.residents[0].visible)
	await key(KEY_E)
	await key(KEY_E,false)
	check("Walk-mode E talks with a dryad without starting camp rest",game.toast_label.text.begins_with("Dryad:") and game.state.resting==0 and not game.paused)

	# Restore three actual sites and verify the moon meadow encounter gate.
	relocate(game.journey.ARTEMIS_SPOT)
	tick(0.05)
	check("Moon meadow stays unvisited before its restoration gate",not game.state.artemis_seen and not game.journey.cast.artemis.visible)
	for i in 3:
		var site: Dictionary = game.state.definitions[i]
		relocate(Vector2(float(site.x),float(site.z)+1))
		game.set_pipes(true)
		for index in site.sequence: game.play_note(int(index))
	check("Three real sanctuary melodies satisfy Artemis' arrival condition",game.state.healed.size()==3)
	relocate(game.journey.ARTEMIS_SPOT+Vector2(0,7))
	tick(0.05)
	check("Artemis appears in deer form and records the first encounter",game.state.artemis_seen and game.journey.cast.artemis.visible)
	game.set_pipes(false)
	check("Artemis offers a line about the silent forest",game.journey.interact() and game.toast_label.text.begins_with("Artemis:"))
	game.camera_distance = 20
	game.camera_pitch = -0.4
	game.toast_label.hide()
	await screenshot("woodland-artemis.jpg")

	# Write the actual v2 save, load it through Continue, and keep optional IDs.
	game.save_enabled = true
	game.save_game()
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	check("Real on-disk save uses version two with optional discovery flags",record is Dictionary and record.version==2 and record.rain_learned and record.wildlife_healed and record.artemis_seen and record.nursery_watered)
	game.new_game(true)
	check("Continue restores seeds, squirrel, rain, wildlife, nursery and Artemis",game.state.collected==record.collected and game.state.squirrel_stage==5 and game.state.rain_learned and game.state.wildlife_healed and game.state.nursery_watered and game.state.artemis_seen and game.state.healed.size()==3)
	check("Reloaded pickups stay hidden and nursery remains grown",not game.journey.seed_nodes[0].visible and game.journey.growth==1.0 and not bool(game.journey.oily_animal.get_meta("oiled")))
	# New country uses the same version-two save, with stable old seed IDs.
	var outer_seed: int = -1
	for i in range(18,game.journey.seeds.size()):
		var p: Vector2 = game.journey.seeds[i]
		if maxf(absf(p.x),absf(p.y))>75.0:
			outer_seed = i
			break
	check("An added seed lies beyond the former world boundary",outer_seed>=18)
	if outer_seed>=18:
		var outer_position: Vector2 = game.journey.seeds[outer_seed]
		var previous_pickups: Array = game.state.collected.duplicate()
		relocate(outer_position)
		tick(0.1)
		var outer_id: String = "seed_%02d" % outer_seed
		check("New outer seed pickup is appended without replacing seed_00",game.state.collected.has("seed_00") and game.state.collected.has(outer_id) and game.state.collected.size()==previous_pickups.size()+1 and game.state.collected.slice(0,previous_pickups.size())==previous_pickups)
		game.save_game()
		game.new_game(true)
		check("Continue retains positions beyond the former 75-unit boundary",Vector2(float(game.state.player.x),float(game.state.player.z)).distance_to(outer_position)<0.001 and Vector2(game.body.position.x,game.body.position.z).distance_to(outer_position)<0.001)
		check("Continue retains both old and appended seed IDs and their hidden pickups",game.state.collected.has("seed_00") and game.state.collected.has(outer_id) and not game.journey.seed_nodes[0].visible and not game.journey.seed_nodes[outer_seed].visible)
		check("Outer-country Continue preserves earlier optional and sanctuary progress",game.state.rain_learned and game.state.wildlife_healed and game.state.nursery_watered and game.state.artemis_seen and game.state.healed.size()==3)
	var previous_woodland := State.new()
	previous_woodland.definitions = game.state.definitions
	previous_woodland.restore({"version":2,"player":{"x":59.0,"z":-5.0},"collected":["seed_00","seed_17"],"squirrel_stage":5,"rain_learned":true,"wildlife_healed":true,"nursery_watered":true,"artemis_seen":true})
	check("Earlier woodland saves keep their original seed identities and discoveries",previous_woodland.collected==["seed_00","seed_17"] and previous_woodland.player.x==59.0 and previous_woodland.player.z==-5.0 and previous_woodland.squirrel_stage==5 and previous_woodland.rain_learned and previous_woodland.wildlife_healed and previous_woodland.nursery_watered and previous_woodland.artemis_seen)
	var malformed := State.new()
	malformed.definitions = game.state.definitions
	malformed.restore({"version":2,"player":{"x":100000.0,"z":-100000.0},"collected":["seed_00","seed_00","seed_999","seed_-1","seed_1","seed_bad"]})
	check("Expanded save boundary still clamps positions and rejects malformed or duplicate seeds",malformed.player.x==game.valley.bounds and malformed.player.z==-game.valley.bounds and malformed.collected==["seed_00"])
	var legacy := State.new()
	legacy.definitions = game.state.definitions
	legacy.restore({"version":1,"player":{"x":8.0,"z":-3.0},"healed":[str(game.state.definitions[0].id)],"elapsed":45.0,"won":false})
	check("Version-one journeys retain old progress and receive safe discovery defaults",legacy.healed.size()==1 and legacy.player.x==8.0 and legacy.collected.is_empty() and not legacy.rain_learned and legacy.squirrel_stage==0)
	game.save_enabled = false
	game.new_game(false)
	check("New Journey resets discoveries, rain, restored wildlife and nursery",game.state.collected.is_empty() and not game.state.rain_learned and not game.state.wildlife_healed and not game.state.nursery_watered and not game.state.artemis_seen and game.state.healed.is_empty() and game.journey.growth==0 and game.journey.rain_left==0 and bool(game.journey.oily_animal.get_meta("oiled")))
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(game.save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path+suffix))
	game.music.stop()
	await create_timer(0.2).timeout
	var report: Dictionary = {"engine":Engine.get_version_info().string,"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"captures":captures,"limitations":"Native scene integration relocates the faun between discoveries. Squirrel movement runs through real journey ticks. Musical phrases use physical keyboard events where stated. These checks do not establish first-time navigation, hardware frame rate, or musical enjoyment."}
	var file := FileAccess.open("res://docs/woodland-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report,"  "))
	for tween in get_processed_tweens(): tween.kill()
	game.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
