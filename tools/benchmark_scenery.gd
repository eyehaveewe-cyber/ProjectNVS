extends SceneTree
## Run on a native display with --rendering-method gl_compatibility and
## --resolution 960x600. Repeat in the baseline checkout and compare.
## Reports local process-frame durations, not isolated CPU or GPU time.
const Scene = preload("res://secondwood.tscn")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = Scene.instantiate()
	game.save_enabled = false
	root.add_child(game)
	game.start_level(false)
	game.music.muted = true
	game.music.stop()
	game.state.player.x = -50
	game.state.player.z = 57
	game._sync_position()
	game._update_camera(1.0)
	for i in 10: await process_frame
	var durations: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i in 60:
		await process_frame
		var now: int = Time.get_ticks_usec()
		durations.append((now-last)/1000.0)
		last = now
	durations.sort()
	var total: float = 0
	for value in durations: total += value
	print("SCENERY_BENCH ",JSON.stringify({"frames":durations.size(),"mean_ms":total/durations.size(),"median_ms":durations[30],"p95_ms":durations[57],"resolution":"960x600","renderer":"GL compatibility / llvmpipe software","scope":"60 frames after 10 warmup at western path; not target hardware or GPU/CPU separation"}))
	game.save_enabled = false
	game.music.stop()
	game.frog_song.stop_song()
	game.queue_free()
	for i in 3: await process_frame
	quit()
