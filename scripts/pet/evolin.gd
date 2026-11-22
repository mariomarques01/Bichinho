extends Node3D

signal reacted(message: String)

const State = preload("res://scripts/pet/evolin_state.gd")
const EYELID_SHADER = preload("res://scripts/pet/eyelids.gdshader")
const BLINK_INTERVAL := 4.1
const BLINK_DURATION := 0.24
const AFFECTION_DURATION := 0.82

@onready var rig: Node3D = $Rig
@onready var pose: Node3D = $Rig/Pose
@onready var heart_origin: Marker3D = $Rig/HeartOrigin

enum Mood { NEUTRO, FAMINTO, SUJO, SONOLENTO, FELIZ, DOENTE, TRISTE }

var state := State.new()
var care: Node
var mood_blend: Tween
var expression := Vector3.ZERO
var sprite_factor := 1.0
var mood := Mood.NEUTRO
var idle_wait := randf_range(6.0, 12.0)
var idle_elapsed := 2.0
var stretching := false
var look_direction := 1.0
var look := 0.0
var stretch := 0.0
var yawn := 0.0
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
	add_child(state)
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

func bind_care(profile: Node) -> void:
	care = profile
	state.setup(care)
	state.state_changed.connect(func(_previous: StringName, _current: StringName) -> void:
		_refresh_expression()
	)
	care.changed.connect(_refresh_expression)
	_refresh_expression()

func _refresh_expression() -> void:
	var target := Mood.NEUTRO
	if care.sick:
		target = Mood.DOENTE
	else:
		match state.current:
			State.TIRED: target = Mood.SONOLENTO
			State.HUNGRY: target = Mood.FAMINTO
			State.DIRTY: target = Mood.SUJO
			State.SAD: target = Mood.TRISTE
			State.HAPPY, State.BATHING, State.PLAYING, State.CELEBRATING: target = Mood.FELIZ
	sleeping = state.current == State.SLEEPING
	if target == mood:
		return
	mood = target
	var base := Vector3.ZERO
	match mood:
		Mood.DOENTE: base = Vector3(0.72, 0.14, 0.0)
		Mood.FAMINTO: base.x = 0.52
		Mood.SUJO: base = Vector3(0.32, -0.10, 0.0)
		Mood.SONOLENTO: base.x = 0.45
		Mood.TRISTE: base = Vector3(0.55, 0.08, 0.0)
		Mood.FELIZ: base.z = 1.0
	if mood_blend:
		mood_blend.kill()
	mood_blend = create_tween().set_trans(Tween.TRANS_SINE)
	mood_blend.tween_property(self, "expression", base, 0.20)

func _update_idle(delta: float) -> void:
	look = 0.0
	stretch = 0.0
	yawn = 0.0
	if sleeping or delight > 0.0 or chew > 0.0 or curious > 0.0 or surprise > 0.0 or (reaction and reaction.is_running()):
		idle_elapsed = 2.0
		return
	idle_wait -= delta
	if idle_wait <= 0.0:
		idle_wait = randf_range(6.0, 12.0)
		idle_elapsed = 0.0
		stretching = randf() < 0.5
		look_direction = -1.0 if randf() < 0.5 else 1.0
	idle_elapsed = minf(idle_elapsed + delta, 2.0)
	var phase := idle_elapsed * 0.5
	var weight := pow(sin(phase * PI), 2.0)
	if stretching:
		stretch = weight
	else:
		look = look_direction * weight * cos(phase * PI) * 2.0
	if mood == Mood.SONOLENTO:
		yawn = pow(maxf(0.0, cos(time * TAU / 5.0)), 4.0)

func _mood_closure() -> float:
	return expression.x + yawn * 0.5

func _tilt() -> float:
	return expression.y + (sin(time * 16.0) * 0.019 if mood == Mood.DOENTE else 0.0)

func pose_sprite(sprite: TextureRect, blink: float, breath: Vector2, sway: float) -> void:
	var lids := sprite.material as ShaderMaterial
	lids.set_shader_parameter("closure", 1.0 if sleeping else maxf(blink, _mood_closure()))
	lids.set_shader_parameter("mouth_shape", 0.0 if sleeping else (-1.0 if mood == Mood.FELIZ else yawn))
	sprite.rotation = sway + look * 0.11 + (_tilt() if not sleeping else 0.0)
	sprite.scale = (breath + Vector2(-0.04, 0.10) * stretch) * sprite_factor

func _process(delta: float) -> void:
	if care:
		state.advance(delta)
	time += delta
	delight = maxf(0.0, delight - delta)
	rest_weight = move_toward(rest_weight, 1.0 if sleeping else 0.0, delta / 0.20)
	curious = move_toward(curious, 0.0, delta * 1.6)
	surprise = move_toward(surprise, 0.0, delta * 1.5)
	_update_idle(delta)
	var sway := sin(time * 2.2) * 0.026
	var wiggle := sin(delight * 19.0) * sin(delight * PI / AFFECTION_DURATION) * 0.13
	var ready_to_play := sin(time * 5.6) * 0.055 if activity == 4 else 0.0
	var studying := sin(time * 2.7) * 0.10 if activity == 5 else 0.0
	var awake := 1.0 - rest_weight
	pose.rotation.z = (sway + wiggle + ready_to_play + _tilt()) * awake - rest_weight * 0.35
	pose.rotation.y = (studying + curious * 0.32 + look * 0.35) * awake
	pose.rotation.x = rest_weight * 0.25 - (surprise * 0.11 + yawn * 0.15) * awake
	if tail_bone >= 0:
		var wag := lerpf(0.10 * sin(time * 3.6) + wiggle * 2.0, 0.018 * sin(time * 1.8), rest_weight)
		skeleton.set_bone_pose_rotation(tail_bone, tail_rest * Quaternion(tail_axis, wag))
	chew = maxf(0.0, chew - delta)
	var breath := sin(time * lerpf(2.2, 1.6, rest_weight)) * 0.025
	var chewing := absf(sin(chew * 17.0)) * minf(chew, 0.08)
	pose.scale.y = 1.0 + breath - chewing - rest_weight * 0.26 + (surprise * 0.11 + stretch * 0.12) * awake

	_update_eyelids(delta)

func _update_eyelids(delta: float) -> void:
	blink_elapsed = fmod(blink_elapsed + delta, BLINK_INTERVAL)
	var blink_phase := clampf((blink_elapsed - BLINK_INTERVAL + BLINK_DURATION) / BLINK_DURATION, 0.0, 1.0)
	var blink := sin(blink_phase * PI)
	var affection := smoothstep(0.0, 0.15, delight) * (1.0 - smoothstep(0.67, AFFECTION_DURATION, delight))
	var closure := lerpf(maxf(maxf(blink, affection), _mood_closure()), 1.0, rest_weight)
	var smile := expression.z * (1.0 - rest_weight) if chew <= 0.0 else 0.0
	eyelids.set_shader_parameter("smile", smile)
	eyelids.set_shader_parameter("yawn", yawn)
	eyelids.set_shader_parameter("closure", closure)
	if closure > 0.001 or smile > 0.001:
		face.material_overlay = eyelids
	elif face.material_overlay:
		face.material_overlay = null

func pet() -> void:
	state.react(State.HAPPY, AFFECTION_DURATION)
	delight = AFFECTION_DURATION
	reacted.emit("Evolin adorou o carinho!")

func eat() -> void:
	state.react(State.EATING, 0.64)
	chew = 0.64
	delight = AFFECTION_DURATION

func set_activity(index: int) -> void:
	if care and activity != index and state.current in [State.EATING, State.PLAYING]:
		state.cancel()
	activity = index
	curious = 0.0
	surprise = 0.0
	if reaction and reaction.is_running():
		reaction.kill()
	rig.position.y = 0.0

func inspect_ingredient() -> void:
	curious = 0.85

func discover() -> void:
	state.react(State.CELEBRATING, 0.9)
	curious = 0.0
	surprise = 0.9
	_hop(0.23, 1)

func celebrate_pair(final_pair: bool) -> void:
	state.react(State.CELEBRATING if final_pair else State.PLAYING, 1.08 if final_pair else 0.54)
	delight = 0.65 if final_pair else 0.36
	_hop(0.38 if final_pair else 0.16, 2 if final_pair else 1)

func jump() -> void:
	if reaction and reaction.is_running():
		return
	state.react(State.PLAYING, 0.54)
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
