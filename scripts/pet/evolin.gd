extends Node3D

signal reacted(message: String)

@onready var rig: Node3D = $Rig
@onready var pose: Node3D = $Rig/Pose
@onready var heart_origin: Marker3D = $Rig/HeartOrigin

var time := 0.0
var delight := 0.0
var reaction: Tween

func _process(delta: float) -> void:
	time += delta
	delight = maxf(0.0, delight - delta)
	var sway := sin(time * 2.2) * 0.026
	var wiggle := sin(delight * 19.0) * sin(delight * PI / 0.82) * 0.13
	pose.rotation.z = sway + wiggle
	pose.scale.y = 1.0 + sin(time * 2.2) * 0.022

func pet() -> void:
	delight = 0.82
	reacted.emit("Evolin adorou o carinho!")

func jump() -> void:
	if reaction and reaction.is_running():
		return
	reaction = create_tween().set_trans(Tween.TRANS_QUAD)
	reaction.tween_property(rig, "position:y", 0.55, 0.24).set_ease(Tween.EASE_OUT)
	reaction.tween_property(rig, "position:y", 0.0, 0.30).set_ease(Tween.EASE_IN)
	reacted.emit("Evolin deu um pulinho!")
