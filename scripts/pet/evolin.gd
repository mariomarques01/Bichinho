extends Node3D

signal reacted(message: String)

const EYELID_SHADER = preload("res://scripts/pet/eyelids.gdshader")
const BLINK_INTERVAL := 4.1
const BLINK_DURATION := 0.24
const AFFECTION_DURATION := 0.82

@onready var rig: Node3D = $Rig
@onready var pose: Node3D = $Rig/Pose
@onready var heart_origin: Marker3D = $Rig/HeartOrigin

var time := 0.0
var delight := 0.0
var reaction: Tween
var sleeping := false
var chew := 0.0
var face: MeshInstance3D
var eyelids := ShaderMaterial.new()
var blink_elapsed := 0.0

func _ready() -> void:
	face = $Rig/Pose/Model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	eyelids.shader = EYELID_SHADER

func _process(delta: float) -> void:
	time += delta
	delight = maxf(0.0, delight - delta)
	var sway := sin(time * 2.2) * 0.026
	var wiggle := sin(delight * 19.0) * sin(delight * PI / AFFECTION_DURATION) * 0.13
	pose.rotation.z = sway + wiggle
	chew = maxf(0.0, chew - delta)
	pose.scale.y = 1.0 + sin(time * 2.2) * 0.022 - absf(sin(chew * 17.0)) * minf(chew, 0.08)

	_update_eyelids(delta)

func _update_eyelids(delta: float) -> void:
	blink_elapsed = fmod(blink_elapsed + delta, BLINK_INTERVAL)
	var blink_phase := clampf((blink_elapsed - BLINK_INTERVAL + BLINK_DURATION) / BLINK_DURATION, 0.0, 1.0)
	var blink := sin(blink_phase * PI)
	var affection := smoothstep(0.0, 0.15, delight) * (1.0 - smoothstep(0.67, AFFECTION_DURATION, delight))
	var closure := 1.0 if sleeping else maxf(blink, affection)
	if closure > 0.001:
		eyelids.set_shader_parameter("closure", closure)
		face.material_overlay = eyelids
	elif face.material_overlay:
		face.material_overlay = null

func pet() -> void:
	delight = AFFECTION_DURATION
	reacted.emit("Evolin adorou o carinho!")

func eat() -> void:
	chew = 0.64

func jump() -> void:
	if reaction and reaction.is_running():
		return
	reaction = create_tween().set_trans(Tween.TRANS_QUAD)
	reaction.tween_property(rig, "position:y", 0.55, 0.24).set_ease(Tween.EASE_OUT)
	reaction.tween_property(rig, "position:y", 0.0, 0.30).set_ease(Tween.EASE_IN)
	reacted.emit("Evolin deu um pulinho!")
