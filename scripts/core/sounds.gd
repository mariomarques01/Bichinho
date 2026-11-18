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

func _ready() -> void:
	for key: StringName in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[key]
		player.volume_db = -7.0
		add_child(player)
		players[key] = player

func play(key: StringName) -> void:
	var player: AudioStreamPlayer = players.get(key)
	if player == null:
		return
	if key == &"bolha" and player.playing:
		return
	player.play()
