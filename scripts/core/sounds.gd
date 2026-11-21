extends Node

const STREAMS := {
	&"toque": preload("res://assets/audio/toque.wav"),
	&"comida": preload("res://assets/audio/comida.wav"),
	&"mordida": preload("res://assets/audio/mordida.wav"),
	&"carinho": preload("res://assets/audio/carinho.wav"),
	&"bolha": preload("res://assets/audio/bolha.wav"),
	&"pulo": preload("res://assets/audio/pulo.wav"),
	&"descanso": preload("res://assets/audio/descanso.wav"),
	&"recompensa": preload("res://assets/audio/recompensa.wav"),
}

var players: Dictionary[StringName, AudioStreamPlayer] = {}

var day: AudioStreamPlayer
var night: AudioStreamPlayer
var fade: Tween

func _ready() -> void:
	day = _loop(preload("res://assets/audio/melodia.wav"), 0.45)
	night = _loop(preload("res://assets/audio/noite.wav"), 0.0)
	for key: StringName in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[key]
		player.bus = &"Efeitos"
		player.volume_db = -7.0
		add_child(player)
		players[key] = player

func play(key: StringName) -> void:
	var player: AudioStreamPlayer = players.get(key)
	if player == null:
		return
	if key == &"bolha" and player.playing:
		return
	if key in [&"carinho", &"recompensa"]:
		vibrate()
	player.play()

func _loop(stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Música"
	player.volume_linear = volume
	add_child(player)
	player.play()
	return player

func set_night(active: bool) -> void:
	if fade:
		fade.kill()
	fade = create_tween().set_parallel()
	fade.tween_property(day, "volume_linear", 0.0 if active else 0.45, 0.8)
	fade.tween_property(night, "volume_linear", 0.7 if active else 0.0, 0.8)

static func vibrate() -> void:
	if DisplayServer.get_name() != "headless" and OS.get_name() in ["Android", "iOS", "Web"]:
		Input.vibrate_handheld(35)
