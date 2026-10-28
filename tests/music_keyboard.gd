extends SceneTree
const Keyboard = preload("res://scripts/keyboard.gd")
const Music = preload("res://scripts/music.gd")
var failures: Array[String] = []
var checks: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(label: String, passed: bool) -> void:
	if passed: checks.append(label)
	else:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var music := Music.new()
	root.add_child(music)
	check("Exact MBean upper row maps Q W E R U I O to C4 through B4",[KEY_Q,KEY_W,KEY_E,KEY_R,KEY_U,KEY_I,KEY_O].map(func(k: int) -> int: return Keyboard.pitch_for_key(k))==[60,62,64,65,67,69,71])
	check("MBean current, lower and outer octaves retain their source pitches",Keyboard.pitch_for_key(KEY_A)==48 and Keyboard.pitch_for_key(KEY_Z)==36 and Keyboard.pitch_for_key(KEY_T)==72 and Keyboard.pitch_for_key(KEY_B)==24)
	check("Space modifier sharpens only notes with a black key above",Keyboard.pitch_for_key(KEY_Q,3,true)==61 and Keyboard.pitch_for_key(KEY_R,3,true)==66 and Keyboard.pitch_for_key(KEY_E,3,true)==64 and Keyboard.pitch_for_key(KEY_O,3,true)==71)
	check("Source octave holds distinguish left and right modifiers",Keyboard.octave_for_modifier(KEY_CTRL,2)==1 and Keyboard.octave_for_modifier(KEY_CTRL,1)==4 and Keyboard.octave_for_modifier(KEY_SHIFT,2)==2 and Keyboard.octave_for_modifier(KEY_SHIFT,1)==5 and Keyboard.octave_for_modifier(KEY_CAPSLOCK)==6)
	check("MIDI boundaries silence out of range keys",Keyboard.pitch_for_key(KEY_B,0)==-1 and Keyboard.pitch_for_key(KEY_Y,8)==-1)
	check("Labels identify source positions and sharp combinations",Keyboard.label_for_pitch(67)=="U" and Keyboard.label_for_pitch(61)=="Space+Q" and Keyboard.note_name(36)=="C2")
	check("Full native chromatic bank contains every MIDI36 through96",music.tones.size()==61 and music.sustain_tones.size()==61)
	for pitch in range(36,97):
		check("Finite PCM and seamless sustain exist for MIDI%d"%pitch,music.tones[pitch].data.size()>1000 and music.sustain_tones[pitch].loop_end>0)
	music.note_on(60)
	music.note_on(64)
	music.note_on(67)
	music.note_on(60)
	check("Three simultaneous held keys make three voices; repeat does not retrigger",music.held.size()==3 and music.voices.size()==3)
	await create_timer(0.8).timeout
	check("Held chord sustains beyond the finite note duration",music.held.size()==3 and music.voices.size()==3 and music.held[60].playing)
	music.note_off(60)
	check("Releasing one note preserves the other held notes",not music.held.has(60) and music.held.has(64) and music.held.has(67))
	await create_timer(0.2).timeout
	check("Released voice finishes its envelope and is cleaned",music.voices.size()==2)
	music.note_on(0)
	music.note_on(127)
	check("MBean octave extremes sound through tuned boundary samples",music.held.has(0) and music.held.has(127))
	music.stop()
	check("Pause or lowering pipes clears all held and released voices",music.held.is_empty() and music.voices.is_empty() and music.envelopes.is_empty())
	for pitch in range(36,68):
		music.note_on(pitch,1.0)
	music.note_on(80)
	check("Polyphony cap bounds active chords",music.voices.size()==32 and not music.held.has(80))
	var bus: int = AudioServer.get_bus_index(music.mix_bus)
	var live_gain: float = db_to_linear(AudioServer.get_bus_volume_db(bus))
	check("Chord bus gain preserves worst-case PCM headroom",live_gain*32.0*0.18<1.0 and live_gain>0.1)
	music.stop()
	music.note_on(60)
	music.note_off(60)
	music.stop()
	await create_timer(0.2).timeout
	check("Stopping during release leaves no delayed envelope callbacks or voices",music.voices.is_empty() and music.envelopes.is_empty())
	music.melody([60,62,64],0.1)
	music.stop()
	await create_timer(0.25).timeout
	check("Pause invalidates pending melody notes",music.voices.is_empty())
	check("Regional phrase groups distinguish damaged habitats and outer walking paths",Music.region_key("THE LONG WOOD")=="wood" and Music.region_key("REEDWATER TRAIL")=="marsh" and Music.region_key("BURNED ORCHARD")=="orchard" and Music.region_key("MOON MEADOW")=="outer")
	music.region = "THE LONG WOOD"
	music.tick(2.0)
	check("Entering a region begins its stable phrase",music.current_region=="wood" and music.step==1)
	music.tick(0.01)
	check("Staying in a region preserves phrase progress",music.step==1)
	music.stop()
	music.muted = true
	music.note_on(60)
	music.play_note(60)
	check("Mute blocks both held notes and finite preview notes",music.voices.is_empty())
	await create_timer(0.15).timeout
	var bus_name: StringName = music.mix_bus
	music.queue_free()
	await process_frame
	check("Removing the music node cleans its private audio bus",AudioServer.get_bus_index(bus_name)==-1)
	var report := {"status":"passed" if failures.is_empty() else "failed","checks":checks,"failures":failures,"source":"MBean1-Astra piano-performance.js inspected 2026-10-23"}
	var file := FileAccess.open("res://docs/music-keyboard-verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
