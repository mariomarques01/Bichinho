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
var activity := -1
var rest_weight := 0.0
var curious := 0.0
var surprise := 0.0
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
	rest_weight = move_toward(rest_weight, 1.0 if sleeping else 0.0, delta * 2.5)
	curious = move_toward(curious, 0.0, delta * 1.6)
	surprise = move_toward(surprise, 0.0, delta * 1.5)
	var sway := sin(time * 2.2) * 0.026
	var wiggle := sin(delight * 19.0) * sin(delight * PI / AFFECTION_DURATION) * 0.13
	var ready_to_play := sin(time * 5.6) * 0.055 if activity == 4 else 0.0
	var studying := sin(time * 2.7) * 0.10 if activity == 5 else 0.0
	var awake := 1.0 - rest_weight
	pose.rotation.z = (sway + wiggle + ready_to_play) * awake - rest_weight * 0.35
	pose.rotation.y = (studying + curious * 0.32) * awake
	pose.rotation.x = rest_weight * 0.25 - surprise * 0.11 * awake
	if tail_bone >= 0:
		var wag := lerpf(0.10 * sin(time * 3.6) + wiggle * 2.0, 0.018 * sin(time * 1.8), rest_weight)
		skeleton.set_bone_pose_rotation(tail_bone, tail_rest * Quaternion(tail_axis, wag))
	chew = maxf(0.0, chew - delta)
	var breath := sin(time * lerpf(2.2, 1.6, rest_weight)) * 0.025
	var chewing := absf(sin(chew * 17.0)) * minf(chew, 0.08)
	pose.scale.y = 1.0 + breath - chewing - rest_weight * 0.26 + surprise * 0.11 * awake

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

func set_activity(index: int) -> void:
	activity = index
	curious = 0.0
	surprise = 0.0
	if reaction and reaction.is_running():
		reaction.kill()
	rig.position.y = 0.0

func inspect_ingredient() -> void:
	curious = 0.85

func discover() -> void:
	curious = 0.0
	surprise = 0.9
	_hop(0.23, 1)

func celebrate_pair(final_pair: bool) -> void:
	delight = 0.65 if final_pair else 0.36
	_hop(0.38 if final_pair else 0.16, 2 if final_pair else 1)

func jump() -> void:
	if reaction and reaction.is_running():
		return
	_hop(0.55, 1)
	reacted.emit("Evolin deu um pulinho!")

func _hop(height: float, count: int) -> void:
	if reaction and reaction.is_running():
		reaction.kill()
	reaction = create_tween().set_trans(Tween.TRANS_QUAD)
	for index in count:
		var peak := height * (1.0 if index == 0 else 0.7)
		reaction.tween_property(rig, "position:y", peak, 0.24).set_ease(Tween.EASE_OUT)
		reaction.tween_property(rig, "position:y", 0.0, 0.30).set_ease(Tween.EASE_IN)
