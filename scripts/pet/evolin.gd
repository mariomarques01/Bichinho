extends Node3D

signal reacted(message: String)

const Geo = preload("res://scripts/core/geometry.gd")

@onready var rig: Node3D = $Rig
@onready var player: AnimationPlayer = $AnimationPlayer
var head: Node3D
var tail: Node3D
var eyes: Array[Node3D] = []
var smiles: Array[Node3D] = []
var time := 0.0
var delight := 0.0
var reaction: Tween

func _ready() -> void:
	_build()
	_build_breathing()

func _build() -> void:
	var teal := Geo.material(Color("#42dbc3"))
	var mint := Geo.material(Color("#bff6b1"))
	var purple := Geo.material(Color("#8061db"))
	var lilac := Geo.material(Color("#cc8ef0"))
	var dark := Geo.material(Color("#281e43"))
	var white := Geo.material(Color("#fff7ff"))
	var pink := Geo.material(Color("#f695c2"))
	var gold := Geo.material(Color("#ffdc81"), 0.65)
	var body := Geo.pivot(rig, "Corpo", Vector3.ZERO)
	Geo.orb(body, Vector3(0, 0.60, 0), Vector3(0.68, 0.59, 0.50), teal)
	Geo.orb(body, Vector3(0, 0.63, 0.416), Vector3(0.37, 0.38, 0.12), mint)
	tail = Geo.pivot(rig, "Cauda", Vector3(0.45, 0.36, -0.23))
	Geo.orb(tail, Vector3(0.38, 0.04, 0), Vector3(0.43, 0.18, 0.19), teal).rotation_degrees.z = 28
	Geo.orb(tail, Vector3(0.68, 0.25, 0), Vector3(0.27, 0.13, 0.15), purple).rotation_degrees.z = 54
	head = Geo.pivot(rig, "Cabeca", Vector3(0, 1.42, 0.07))
	Geo.orb(head, Vector3.ZERO, Vector3(0.91, 0.72, 0.69), teal)
	Geo.orb(head, Vector3(0, -0.29, 0.514), Vector3(0.54, 0.30, 0.21), mint)
	for side: float in [-1.0, 1.0]:
		var paws := Geo.pivot(body, "Patas", Vector3(side * 0.39, 0, 0))
		Geo.orb(paws, Vector3(0, 0.23, 0.33), Vector3(0.29, 0.22, 0.32), purple)
		Geo.orb(paws, Vector3(-side * 0.033, 0.225, 0.60), Vector3(0.16, 0.11, 0.06), lilac)
		Geo.orb(paws, Vector3(side * 0.15, 0.62, 0.36), Vector3(0.18, 0.31, 0.19), teal).rotation_degrees.z = -side * 27.0
		var ear := Geo.pivot(head, "Orelha", Vector3(side * 0.81, 0.25, -0.04))
		ear.rotation_degrees.z = side * 48.0
		Geo.orb(ear, Vector3.ZERO, Vector3(0.24, 0.41, 0.19), purple)
		Geo.orb(ear, Vector3(0, 0.055, 0.13), Vector3(0.15, 0.28, 0.08), lilac)
		var eye := Geo.pivot(head, "Olho", Vector3(side * 0.345, 0.045, 0.590))
		eyes.append(eye)
		Geo.orb(eye, Vector3.ZERO, Vector3(0.246, 0.281, 0.125), dark)
		Geo.orb(eye, Vector3(0, 0.006, 0.041), Vector3(0.212, 0.242, 0.115), white)
		Geo.orb(eye, Vector3(-side * 0.018, -0.012, 0.131), Vector3(0.145, 0.173, 0.067), purple)
		Geo.orb(eye, Vector3(-side * 0.018, 0.003, 0.169), Vector3(0.105, 0.128, 0.049), dark)
		Geo.orb(eye, Vector3(-0.055, 0.081, 0.207), Vector3.ONE * 0.045, white)
		Geo.orb(eye, Vector3(0.057, -0.05, 0.211), Vector3.ONE * 0.019, white)
		var lid := Geo.pivot(head, "OlhoFechado", eye.position)
		Geo.link(lid, Vector3(-0.16, -0.025, 0.10), Vector3(0, 0.047, 0.15), 0.024, dark)
		Geo.link(lid, Vector3(0, 0.047, 0.15), Vector3(0.16, -0.025, 0.10), 0.024, dark)
		smiles.append(lid)
		Geo.orb(head, Vector3(side * 0.55, -0.245, 0.51), Vector3(0.145, 0.076, 0.075), pink)
		for i in range(3):
			Geo.orb(head, Vector3(side * (0.35 + 0.13 * i), 0.49 - 0.065 * i, 0.39 - 0.038 * i),
				Vector3(0.084 - 0.013 * i, 0.047, 0.044), purple)
		var root := Vector3(side * 0.29, 0.57, 0.21)
		var bend := Vector3(side * 0.41, 0.93, 0.19)
		var tip := Vector3(side * 0.65, 1.025, 0.19)
		Geo.link(head, root, bend, 0.050, teal)
		Geo.link(head, bend, tip, 0.046, lilac)
		Geo.orb(head, tip, Vector3.ONE * 0.127, gold)
	Geo.orb(head, Vector3(0, -0.23, 0.724), Vector3(0.087, 0.051, 0.05), purple)
	Geo.orb(head, Vector3(0, -0.37, 0.721), Vector3(0.115, 0.083, 0.048), dark)
	Geo.orb(head, Vector3(0, -0.403, 0.757), Vector3(0.065, 0.033, 0.015), pink)

func _build_breathing() -> void:
	var animation := Animation.new()
	animation.length = 2.8
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Rig/Corpo:scale"))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(track, 0.0, Vector3.ONE)
	animation.track_insert_key(track, 1.4, Vector3(1.025, 1.045, 1.025))
	animation.track_insert_key(track, 2.8, Vector3.ONE)
	var library := AnimationLibrary.new()
	library.add_animation(&"respirar", animation)
	player.add_animation_library(&"", library)
	player.play(&"respirar")

func _process(delta: float) -> void:
	time += delta
	delight = maxf(0.0, delight - delta)
	var closed := delight > 0.0 or fmod(time, 4.6) > 4.44
	for i in eyes.size():
		eyes[i].visible = not closed
		smiles[i].visible = closed
	head.rotation.z = sin(time * (4.0 if delight > 0.0 else 1.7)) * (0.12 if delight > 0.0 else 0.036)
	tail.rotation.y = sin(time * (6.0 if delight > 0.0 else 2.4)) * 0.25

func pet() -> void:
	delight = 0.82
	reacted.emit("Evolin adorou o carinho!")

func jump() -> void:
	if reaction and reaction.is_running():
		return
	delight = 0.4
	reaction = create_tween().set_trans(Tween.TRANS_QUAD)
	reaction.tween_property(rig, "position:y", 0.55, 0.24).set_ease(Tween.EASE_OUT)
	reaction.tween_property(rig, "position:y", 0.0, 0.30).set_ease(Tween.EASE_IN)
	reacted.emit("Evolin deu um pulinho!")
