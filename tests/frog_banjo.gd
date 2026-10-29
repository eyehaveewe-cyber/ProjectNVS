extends SceneTree
## Exercises actual Godot WAV import, one-shot lifecycle and mute behavior.
const Tune = preload("res://scripts/frog_banjo.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var tune := Tune.new()
	root.add_child(tune)
	assert(tune.player.stream is AudioStreamWAV)
	assert(tune.player.stream.get_length()>33.0 and tune.player.stream.get_length()<34.0)
	tune.play_song()
	assert(tune.is_playing())
	tune.set_muted(true)
	assert(not tune.is_playing())
	tune.play_song()
	assert(not tune.is_playing())
	tune.set_muted(false)
	tune.play_song()
	assert(tune.is_playing())
	tune.stop_song()
	assert(not tune.is_playing())
	print("Frog banjo native audio: imported WAV, duration, playback, mute and stop passed")
	tune.queue_free()
	await create_timer(0.2).timeout
	quit()
