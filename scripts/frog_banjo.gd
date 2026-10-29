extends Node
## Original MBean1-authored Frog Lantern Rag, rendered with a local plucked
## string model. The game owns when to play, stop or mute this one-shot cue.
signal song_finished
var player: AudioStreamPlayer
var muted: bool = false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "FrogLanternRag"
	player.stream = load("res://assets/frog-lantern-rag.wav")
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(func() -> void: song_finished.emit())

func play_song() -> void:
	if not muted and is_instance_valid(player): player.play()

func stop_song() -> void:
	if is_instance_valid(player): player.stop()

func set_muted(value: bool) -> void:
	muted = value
	if muted: stop_song()

func is_playing() -> bool:
	return is_instance_valid(player) and player.playing
