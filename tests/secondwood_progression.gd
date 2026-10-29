extends SceneTree
## A continuous chapter-two journey using the actual player controller and input.
## No player relocation or direct quest mutation is used in the playable journey.
const Scene = preload("res://secondwood.tscn")
const Start = preload("res://start.tscn")
const State = preload("res://scripts/secondwood_state.gd")
const Layout = preload("res://scripts/secondwood_layout.gd")
const STEP: float = 0.05
const SPEED: float = 3.2
const SECOND_SAVE := "user://secondwood-progression-isolated.json"
const VALLEY_SAVE := "user://secondwood-valley-isolated.json"
var checks: Array[String] = []
var failures: Array[String] = []
var walked: float = 0.0
var controller_steps: int = 0
var game: Node
var menu: Node
var journeys: Array[Dictionary] = []
var real_save_bytes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(label: String, condition: bool) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func position2() -> Vector2:
	return Vector2(float(game.state.player.x),float(game.state.player.z))

func cleanup_save(path: String) -> void:
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func key(code: int, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func tap(code: int) -> void:
	await key(code,true)
	await key(code,false)

func walk_to(target: Vector2, expect_arrival: bool = true) -> Dictionary:
	var start: Vector2 = position2()
	var allowance: int = ceili(start.distance_to(target)/(SPEED*STEP))+65
	var distance_walked: float = 0.0
	var stalls: int = 0
	var bad_steps: int = 0
	for frame in allowance:
		var before: Vector2 = position2()
		var difference: Vector2 = target-before
		if difference.length()<0.06: break
		game.touch_move = difference.limit_length(SPEED*STEP)/(SPEED*STEP)
		game._physics_process(STEP)
		controller_steps += 1
		var after: Vector2 = position2()
		var moved: float = before.distance_to(after)
		walked += moved
		distance_walked += moved
		stalls = stalls+1 if moved<0.00001 else 0
		if moved>SPEED*STEP+0.002 or not game.map.is_clear(after.x,after.y,game.state.healed): bad_steps += 1
		if stalls>=10: break
	game.touch_move = Vector2.ZERO
	var error: float = position2().distance_to(target)
	if expect_arrival and (error>=0.25 or bad_steps>0):
		check("Continuous controller reaches "+str(target),false)
	return {"start":str(start),"target":str(target),"walked_distance":distance_walked,"endpoint_error":error,"bad_steps":bad_steps,"consecutive_stalls":stalls}

func route(id: String, backwards: bool = false) -> Array:
	for definition: Dictionary in Layout.all_routes():
		if str(definition.id)==id:
			var points: Array = definition.points.duplicate()
			if backwards: points.reverse()
			return points
	assert(false,"Unknown test route "+id)
	return []

func walk_route(id: String, backwards: bool = false) -> void:
	var points: Array = route(id,backwards)
	var success: bool = position2().distance_to(points[0])<0.25
	var distance_walked: float = 0.0
	var bad_steps: int = 0
	for i in range(1,points.size()):
		var leg: Dictionary = walk_to(points[i])
		distance_walked += float(leg.walked_distance)
		bad_steps += int(leg.bad_steps)
		success = success and float(leg.endpoint_error)<0.25
		if float(leg.endpoint_error)>=0.25: break
	var label: String = id+(" return" if backwards else " outward")
	check("Controller walks "+label+" continuously",success and bad_steps==0)
	journeys.append({"route":id,"direction":"return" if backwards else "outward","distance":distance_walked,"arrived":success,"bad_steps":bad_steps})

func isolated_menu() -> Node:
	var selected: Node = Start.instantiate()
	selected.save_paths = {"valley":VALLEY_SAVE,"secondwood":SECOND_SAVE}
	root.add_child(selected)
	current_scene = selected
	return selected

func run() -> void:
	for path in ["user://journey.json","user://secondwood.json"]:
		real_save_bytes[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	cleanup_save(SECOND_SAVE)
	cleanup_save(VALLEY_SAVE)
	write_json(VALLEY_SAVE,{"version":2,"player":{"x":0,"z":4},"healed":[],"elapsed":23,"collected":["seed_00"]})
	var valley_sentinel: PackedByteArray = FileAccess.get_file_as_bytes(VALLEY_SAVE)
	menu = isolated_menu()
	await process_frame
	check("Root project starts at level selection",str(ProjectSettings.get_setting("application/run/main_scene"))=="res://start.tscn")
	check("Startup offers both journeys with independent begin actions",menu.new_buttons.has("valley") and menu.new_buttons.has("secondwood") and menu.save_paths.valley!=menu.save_paths.secondwood)
	menu.new_buttons.secondwood.pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	game.set_physics_process(false)
	game.set_process(false)
	game.music.muted = true
	game.music.stop()
	game.camera_yaw = 0.0
	check("Choosing journey two opens its native scene and isolated save",game.get_script().resource_path=="res://scripts/secondwood_game.gd" and game.started and game.save_path==SECOND_SAVE and game.state.inventory.is_empty())
	check("Level two retains the native faun and full MBean instrument",game.faun.joints.size()==7 and game.music.tones.size()==61)
	check("Begin chapter two preserves the other journey file",FileAccess.get_file_as_bytes(VALLEY_SAVE)==valley_sentinel)
	check("All three wounds initially show damaged soil without regrowth",game.map.damaged_nodes.source.visible and game.map.damaged_nodes.hollow.visible and game.map.damaged_nodes.ash.visible and not game.map.site_nodes.source.visible and not game.map.site_nodes.hollow.visible and not game.map.site_nodes.ash.visible)
	var start: Vector2 = position2()
	await key(KEY_D)
	game._physics_process(0.25)
	await key(KEY_D,false)
	check("Physical walking input moves the chapter-two faun",position2().distance_to(start)>0.3)
	walk_to(Layout.ENTRY)
	await tap(KEY_TAB)
	check("Tab opens the chapter-two instrument",game.playing and game.music_panel.visible)
	var before_music: Vector2 = position2()
	game.touch_move = Vector2.RIGHT
	game._physics_process(0.1)
	game.touch_move = Vector2.ZERO
	await key(KEY_E)
	await key(KEY_J)
	check("Instrument E and J play held notes without talking or opening journal",game.held_keys.size()==2 and not game.paused and game.state.healed.is_empty() and position2().distance_to(before_music)<0.001)
	await tap(KEY_ESCAPE)
	await key(KEY_E,false)
	await key(KEY_J,false)
	check("Pause releases held instrument voices",game.paused and game.held_keys.is_empty() and game.music.held.is_empty())
	game.resume_game()
	game.set_pipes(false)
	await tap(KEY_J)
	check("Journal opens chapter-two map and current quest",game.paused and game.overview!=null and game.overview.name=="BranchingOverview")
	game.resume_game()
	walk_route("arrival")
	await tap(KEY_E)
	check("Keeper explains the current healing objective",game.toast_label.text.begins_with("Keeper:") and game.toast_label.text.contains("Spring Vessel"))
	for site_id: String in ["source","hollow","ash"]:
		walk_route(site_id+"-approach")
		await tap(KEY_E)
		check("Visiting "+site_id+" early names its specific missing tool",game.state.healed.is_empty() and game.toast_label.text.contains(str(Layout.ITEMS[str(Layout.SITES[site_id].item)].name)))
		if site_id=="ash":
			var blocked_walk: Dictionary = walk_to(route("northern-spiral")[1],false)
			check("Actual controller cannot enter the sealed northern branch early",float(blocked_walk.endpoint_error)>5.0 and not game.state.inventory.has("spindle"))
			walk_to(Layout.SITES.ash.position)
		walk_route(site_id+"-approach",true)
	game.set_pipes(true)
	for pitch: int in State.FINAL_PHRASE: game.play_midi(pitch)
	check("Knowing the ending melody cannot complete an unhealed wood",not game.state.won)
	game.set_pipes(false)
	walk_route("western-curl")
	check("Long western branch physically reaches and collects the Spring Vessel",game.state.inventory==["vessel"] and not game.items.vessel.visible)
	walk_route("western-curl",true)
	walk_route("source-approach")
	await tap(KEY_E)
	check("Returning with the matching vessel heals the source and opens its routes",game.state.healed==["source"] and game.state.inventory.has("vessel") and not game.map.gates["source-cut"].visible and not game.map.gates["northern-spiral"].visible and game.map.site_nodes.source.visible)
	check("Opened shortcuts also hide their closed-root signs",game.map.gates["source-cut"].find_children("*","Label3D",true,false).size()==1 and not game.map.gates["source-cut"].visible)
	check("Source healing replaces damaged soil with animated water and new growth",not game.map.damaged_nodes.source.visible and game.map.site_nodes.source.visible and game.map.growth_tweens.has("source") and game.map.site_nodes.source.position.y<0.0)
	await create_timer(1.6).timeout
	check("Source regrowth animation actually reaches its resting height",absf(game.map.site_nodes.source.position.y)<0.001)
	walk_route("source-cut")
	var west: Array = route("western-curl")
	walk_to(west[west.size()-2])
	walk_to(west.back())
	check("Revisiting a tool does not duplicate it or consume it after use",game.state.inventory==["vessel"])
	walk_to(west[west.size()-2])
	walk_to(west[west.size()-3])
	walk_route("source-cut",true)
	walk_route("source-approach",true)
	walk_route("eastern-curl")
	check("Eastern coil physically reaches and collects the Living Spore",game.state.inventory.has("spore") and not game.items.spore.visible)
	walk_route("eastern-curl",true)
	walk_route("ash-approach")
	await tap(KEY_E)
	check("Owning other tools cannot heal the ash scar without its Spindle",not game.state.healed.has("ash") and game.toast_label.text.contains("Rootheart Spindle"))
	walk_route("ash-approach",true)
	walk_route("hollow-approach")
	await tap(KEY_E)
	check("Living Spore heals its own wound and permanently opens the hollow cut",game.state.healed.has("hollow") and game.state.inventory.has("spore") and not game.map.gates["hollow-cut"].visible and game.map.site_nodes.hollow.visible)
	check("Spore healing clears the hollow soil and raises returning vegetation",not game.map.damaged_nodes.hollow.visible and game.map.site_nodes.hollow.visible and game.map.growth_tweens.has("hollow"))
	walk_route("hollow-cut")
	walk_route("hollow-cut",true)
	walk_route("hollow-approach",true)
	walk_route("ash-approach")
	walk_route("northern-spiral")
	check("Source restoration permits actual spiral travel to the Rootheart Spindle",game.state.inventory.has("spindle") and not game.items.spindle.visible)
	walk_route("northern-spiral",true)
	await tap(KEY_E)
	check("Revisiting the ash scar with Spindle restores the third land",game.state.healed.size()==3 and game.state.inventory.size()==3 and not game.map.gates["ash-cut"].visible and not game.map.gates["final-curl"].visible)
	check("Spindle healing clears ash soil and raises new root growth",not game.map.damaged_nodes.ash.visible and game.map.site_nodes.ash.visible and game.map.growth_tweens.has("ash"))
	walk_route("ash-cut")
	walk_route("ash-cut",true)
	game.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SECOND_SAVE))
	check("On-disk save records all tools and healed shortcuts without claiming the ending",saved.version==1 and saved.inventory.size()==3 and saved.healed.size()==3 and not saved.won)
	var saved_position: Vector2 = position2()
	game.start_level(true)
	game.camera_yaw = 0.0
	check("Continue restores the exact position, inventory and open land",position2().distance_to(saved_position)<0.001 and game.state.healed.size()==3 and game.state.inventory.size()==3 and not game.map.gates["source-cut"].visible and not game.map.gates["hollow-cut"].visible and not game.map.gates["ash-cut"].visible)
	check("Continue restores healed land at its finished animation height",not game.map.damaged_nodes.source.visible and not game.map.damaged_nodes.hollow.visible and not game.map.damaged_nodes.ash.visible and absf(game.map.site_nodes.source.position.y)<0.001 and absf(game.map.site_nodes.hollow.position.y)<0.001 and absf(game.map.site_nodes.ash.position.y)<0.001)
	walk_route("ash-approach",true)
	walk_route("hollow-approach")
	walk_route("final-curl")
	check("All healing objectives permit continuous travel to the final grove",position2().distance_to(Layout.FINAL)<0.25 and not game.state.won)
	await tap(KEY_E)
	check("Final grove offers the musical answer after land recovery",game.toast_label.text.contains("Q E U I U E Q"))
	await tap(KEY_TAB)
	await tap(KEY_W)
	await tap(KEY_W)
	check("Wrong final phrase keeps the final song unfinished",not game.state.won)
	for note_key: int in [KEY_Q,KEY_E,KEY_U,KEY_I,KEY_U,KEY_E,KEY_Q]: await tap(note_key)
	check("Physical MBean keys finish the final song and chapter",game.state.won and game.paused)
	check("Completion preserves all healing tools for further revisits",game.state.inventory.size()==3)
	game.start_level(true)
	check("Completed chapter reloads with completion and every shortcut",game.state.won and game.state.healed.size()==3 and not game.map.gates["final-curl"].visible)
	var malformed := State.new()
	malformed.restore({"player":{"x":INF,"z":"bad","yaw":100000000},"inventory":["spindle","spindle","fake"],"healed":["ash","source","fake"],"won":true,"elapsed":-100})
	check("Malformed save rejects unknown IDs, impossible Spindle and false completion",malformed.inventory.is_empty() and malformed.healed.is_empty() and not malformed.won and malformed.player.x==Layout.ENTRY.x and malformed.player.z==Layout.ENTRY.y and malformed.elapsed==0)
	check("Continuous quest walking keeps the visible faun aligned",Vector2(game.body.position.x,game.body.position.z).distance_to(position2())<0.001)
	game.return_to_select()
	await process_frame
	await process_frame
	menu = current_scene
	check("Level-two pause return reaches the real level selection scene",menu!=null and menu.get_script().resource_path=="res://scripts/start_menu.gd" and menu.new_buttons.size()==2)
	menu.queue_free()
	await process_frame
	menu = isolated_menu()
	await process_frame
	var continue_button: Button
	for candidate in menu.find_children("*","Button",true,false):
		if candidate.has_meta("level_id") and candidate.get_meta("level_id")=="secondwood" and candidate.get_meta("resume")==true: continue_button = candidate
	check("Startup offers Continue for a saved second journey",continue_button!=null)
	if continue_button!=null: continue_button.pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	game.set_physics_process(false)
	game.set_process(false)
	game.music.muted = true
	game.music.stop()
	check("Startup Continue actually loads completed chapter-two progress",game.state.won and game.state.inventory.size()==3 and game.save_path==SECOND_SAVE)
	check("Chapter-two actions leave first-journey save byte-for-byte unchanged",FileAccess.get_file_as_bytes(VALLEY_SAVE)==valley_sentinel)
	game.save_enabled = false
	game.queue_free()
	await process_frame
	var second_record: PackedByteArray = FileAccess.get_file_as_bytes(SECOND_SAVE)
	menu = isolated_menu()
	await process_frame
	var valley_continue: Button
	for candidate in menu.find_children("*","Button",true,false):
		if candidate.has_meta("level_id") and candidate.get_meta("level_id")=="valley" and candidate.get_meta("resume")==true: valley_continue = candidate
	check("Startup also offers Continue for the first valley",valley_continue!=null)
	if valley_continue!=null: valley_continue.pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	game.set_physics_process(false)
	game.set_process(false)
	game.music.muted = true
	game.music.stop()
	check("Valley selection loads its original scene and own saved discoveries",game.get_script().resource_path=="res://scripts/game.gd" and game.save_path==VALLEY_SAVE and game.state.collected==["seed_00"] and game.state.elapsed>=23.0)
	check("Selecting the valley does not change second-journey progress",FileAccess.get_file_as_bytes(SECOND_SAVE)==second_record)
	game.save_enabled = false
	game.return_to_level_select()
	await process_frame
	await process_frame
	menu = current_scene
	check("The original valley can also return to the real level selection",menu!=null and menu.get_script().resource_path=="res://scripts/start_menu.gd")
	menu.queue_free()
	await process_frame
	menu = isolated_menu()
	await process_frame
	var valley_before_reset: PackedByteArray = FileAccess.get_file_as_bytes(VALLEY_SAVE)
	menu.new_buttons.valley.pressed.emit()
	check("Beginning over first asks confirmation without writing either journey",menu.pending_new=="valley" and current_scene==menu and FileAccess.get_file_as_bytes(VALLEY_SAVE)==valley_before_reset and FileAccess.get_file_as_bytes(SECOND_SAVE)==second_record)
	menu.new_buttons.valley.pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	game.set_physics_process(false)
	game.set_process(false)
	game.music.stop()
	check("Confirmed new valley resets only the selected journey",game.state.collected.is_empty() and game.state.healed.is_empty() and FileAccess.get_file_as_bytes(SECOND_SAVE)==second_record)
	game.save_enabled = false
	game.queue_free()
	await process_frame
	for path: String in real_save_bytes:
		var actual: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		check("Test never changes the real player save "+path,actual==real_save_bytes[path])
	cleanup_save(SECOND_SAVE)
	cleanup_save(VALLEY_SAVE)
	var report: Dictionary = {"engine":Engine.get_version_info().string,"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"routes":journeys,"controller_steps":controller_steps,"walked_distance":walked,"simulated_seconds":controller_steps*STEP,"player_relocations":0,"scope":"The quest journey starts through the real selection button, then walks authored paths continuously using the real chapter-two controller, including three newly opened shortcuts and return visits. Healing and the final song use physical keyboard events. Save/Continue resets the scene from its own on-disk record. Separate scene reconstruction tests Continue for both chapters and a confirmed first-valley reset while retaining chapter two. No spatial relocation or direct quest mutation is used for gameplay progress. Fixed simulated steps are not a frame-rate or human wayfinding measurement."}
	var output := FileAccess.open("res://docs/secondwood-progression-verification.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	print(JSON.stringify(report,"  "))
	for tween in get_processed_tweens(): tween.kill()
	quit(0 if failures.is_empty() else 1)
