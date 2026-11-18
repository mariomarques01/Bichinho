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
var skeleton: Skeleton3D
var tail_bone := -1
var tail_rest := Quaternion.IDENTITY
var tail_axis := Vector3.UP

func _ready() -> void:
	face = $Rig/Pose/Model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	eyelids.shader = EYELID_SHADER
	var material := face.get_active_material(0).duplicate() as StandardMaterial3D
	material.metallic = 0.0
	material.roughness = 0.82
	material.roughness_texture = null
	material.normal_scale = 0.25
	material.emission_enabled = true
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission = Color.WHITE
	material.emission_texture = material.albedo_texture
	material.emission_energy_multiplier = 0.22
	face.set_surface_override_material(0, material)
	var bones := pose.find_children("*", "Skeleton3D", true, false)
	if not bones.is_empty():
		skeleton = bones[0] as Skeleton3D
		for index in skeleton.get_bone_count():
			if String(skeleton.get_bone_name(index)).ends_with("Tail_0"):
				tail_bone = index
				tail_rest = skeleton.get_bone_pose_rotation(index)
				tail_axis = (skeleton.get_bone_global_rest(index).basis.inverse() * Vector3.UP).normalized()
				break

func _process(delta: float) -> void:
	time += delta
	delight = maxf(0.0, delight - delta)
	var sway := sin(time * 2.2) * 0.026
	var wiggle := sin(delight * 19.0) * sin(delight * PI / AFFECTION_DURATION) * 0.13
	pose.rotation.z = sway + wiggle
	if tail_bone >= 0:
		var wag := 0.045 * sin(time * 2.8) if sleeping else 0.10 * sin(time * 3.6) + wiggle * 2.0
		skeleton.set_bone_pose_rotation(tail_bone, tail_rest * Quaternion(tail_axis, wag))
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
	delight = AFFECTION_DURATION

func jump() -> void:
	if reaction and reaction.is_running():
		return
	reaction = create_tween().set_trans(Tween.TRANS_QUAD)
	reaction.tween_property(rig, "position:y", 0.55, 0.24).set_ease(Tween.EASE_OUT)
	reaction.tween_property(rig, "position:y", 0.0, 0.30).set_ease(Tween.EASE_IN)
	reacted.emit("Evolin deu um pulinho!")
