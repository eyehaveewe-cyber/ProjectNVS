extends SceneTree
## Integration fixtures: interact through the level's real methods, using
## explicit player positions and quest states. Not a continuous journey test.
const Scene = preload("res://secondwood.tscn")
const Layout = preload("res://scripts/secondwood_layout.gd")
var checks: Array[String] = []
var failures: Array[String] = []
var game: Node
func _initialize() -> void:
	call_deferred("run")
func check(label: String, condition: bool) -> void:
	if condition: checks.append(label)
	else:
		failures.append(label)
		push_error(label)
func move_fixture(p: Vector2) -> void:
	game.state.player.x = p.x
	game.state.player.z = p.y
	game._sync_position()
	game.update_hud()
func run() -> void:
	game = Scene.instantiate()
	game.save_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.ambience.set_process(false)
	game.start_level(false)
	game.music.stop()
	check("The frog band stands on initially walkable wetland floor",Layout.is_walkable(game.FROG_BAND_POSITION,[]))
	check("Band contains three distinct performers with individual instruments",game.frog_band.players.size()==3 and game.frog_band.find_children("*Banjo*","",true,false).size()>=3)
	check("Five squirrels and five distinct regional particle pools exist",game.ambience.squirrels.size()==5 and game.ambience.fields.size()==5)
	check("Artemis has a moonlit aura and 22 motes",game.moon_aura!=null and game.moon_motes.size()==22)
	move_fixture(Layout.ARTEMIS)
	game.interact()
	check("First audience accepts quest and gives the Spring Vessel lead",game.state.artemis_accepted and game.toast_label.text.begins_with("Artemis:") and game.toast_label.text.contains("Spring Vessel"))
	check("Interaction starts Artemis bow",game.artemis_bow>0.0)
	game._physics_process(0.4)
	check("Bow advances and remains finite",game.artemis_bow<1.6 and is_finite(game.artemis.get_node("Head").rotation.x))
	game.state.inventory.assign(["vessel","spore","spindle","lens","spool"])
	game.state.healed.assign(["source","hollow","ash"])
	game.interact()
	check("Artemis responds to healed land and severed ridge crossings",game.toast_label.text.contains("ridge paths are severed"))
	game.state.acorn_state="carried"
	game.interact()
	check("Artemis gives an acorn carrying instruction",game.toast_label.text.contains("Crown Clearing"))
	game.state.acorn_state="planted"
	game.interact()
	check("Planted acorn prompts the finale phrase",game.toast_label.text.contains("Q E U I U E Q"))
	game.state.artemis_finale_done=true
	game.interact()
	check("After finale Artemis acknowledges the returning wood",game.toast_label.text.contains("room for song"))
	move_fixture(game.FROG_BAND_POSITION)
	check("Band offers an E interaction prompt",game.context_label.text.contains("Listen to the frog band"))
	game.interact()
	check("E starts banjo song and changes prompt",game.frog_song.is_playing() and game.context_label.text.contains("Stop the frog band"))
	var performer: Dictionary = game.frog_band.players[0]
	var hand: Node3D = performer.strum
	var before := hand.rotation
	game._physics_process(0.15)
	check("Banjo song animates the frog's strumming arm",hand.rotation.distance_to(before)>0.001)
	game.interact()
	check("Second E stops the music",not game.frog_song.is_playing())
	game.interact()
	game.show_pause()
	check("Pause stops performance",game.paused and not game.frog_song.is_playing())
	game.resume_game()
	game.interact()
	game.toggle_sound()
	check("Muting stops performance and prevents a silent restart",not game.frog_song.is_playing() and game.music.muted)
	game.interact()
	check("Muted E explains how to hear frogs",not game.frog_song.is_playing() and game.toast_label.text.contains("Turn sound on"))
	game.toggle_sound()
	game.interact()
	game.set_pipes(true)
	check("Raising pipes stops the band",not game.frog_song.is_playing() and game.playing)
	game.set_pipes(false)
	game.interact()
	move_fixture(game.FROG_BAND_POSITION+Vector2(19,0))
	game._physics_process(0.01)
	check("Leaving the band area stops its song",not game.frog_song.is_playing())
	move_fixture(Layout.HUB)
	game.ambience._process(0.2)
	check("Glade wildlife appears near the player",game.ambience.squirrels[0].visible and game.ambience.fields[0].node.visible)
	check("Distant wildlife and fireflies are culled",not game.ambience.squirrels[4].visible and not game.ambience.fields[2].node.visible)
	var ambience_clock: float = game.ambience.clock
	game.paused=true
	game.ambience._process(1.0)
	check("Pause freezes environmental animation",game.ambience.clock==ambience_clock)
	game.paused=false
	move_fixture(Layout.LENS)
	game.ambience._process(0.2)
	check("Wetland fireflies appear near the player",game.ambience.fields[2].node.visible and not game.ambience.fields[0].node.visible)
	game._process(0.1)
	check("Artemis aura culls when the player is distant",not game.moon_aura.visible)
	move_fixture(Layout.ARTEMIS)
	game._process(0.1)
	check("Artemis aura returns near the player",game.moon_aura.visible)
	var stream: AudioStreamWAV = game.frog_song.player.stream
	check("Playable banjo cue has audible duration and PCM data",stream!=null and stream.get_length()>20.0 and stream.data.size()>100000)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/frog-lantern-rag.mbean.json"))
	check("Editable MBean1 composition has distinct tracks and note events",parsed is Dictionary and parsed.get("tracks",[]).size()>=2 and parsed.tracks[0].notes.size()>20)
	var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"scope":"Explicit state and position fixtures exercise real second-level interaction methods, sound controls, local animations, regional distance culling and Artemis's dialogue; this is not a continuous quest or subjective art/listening review."}
	print(JSON.stringify(report,"  "))
	stream = null
	hand = null
	performer.clear()
	game.music.stop()
	game.queue_free()
	for tween in get_processed_tweens(): tween.kill()
	await process_frame
	game = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
