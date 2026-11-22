extends Control

const Care = preload("res://scripts/needs/care.gd")
const MOTION = preload("res://scripts/pet/pose_motion.gdshader")
const State = preload("res://scripts/pet/evolin_state.gd")
const PoseMap = preload("res://scripts/pet/evolin_pose_map.gd")
const FADE_DURATION := 0.20

@export var pose_map: PoseMap
@export var left_eye := Vector2(0.397, 0.462)
@export var right_eye := Vector2(0.601, 0.462)
var care: Care
var state := State.new()
var body := Node2D.new()
var layers: Dictionary[Texture2D, Sprite2D] = {}
var front: Sprite2D
var lids: Array[Polygon2D] = []
var phase := 0.0
var next_blink := randf_range(3.0, 5.0)
var blink_age := 1.0
var jump_age := 0.0
var jumps := 0
var fade: Tween
var growth_factor := 1.0
var pop := 1.0
var sleep_weight := 0.0

func setup(profile: Care) -> void:
	care = profile
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(body)
	for center in [left_eye, right_eye]:
		var lid := Polygon2D.new()
		var points := PackedVector2Array()
		for index in 48:
			points.append(Vector2.from_angle(TAU * index / 48.0) * Vector2(63, 70))
		lid.polygon = points
		lid.color = Color("#40d5de")
		body.add_child(lid)
		lid.position = Vector2(center) * 1024 - Vector2(512, 960)
		lids.append(lid)
	var outfit := preload("res://scripts/inventory/wardrobe_art.gd").attach(self, care.wardrobe, left_eye, right_eye)
	outfit.reparent(body, false)
	outfit.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
	outfit.position = Vector2(-512, -960)
	outfit.size = Vector2(1024, 1024)
	add_child(state)
	state.setup(care)
	_show_pose(State.IDLE, state.current)
	state.state_changed.connect(_show_pose)
	_process(0)

func _show_pose(_previous: StringName, target: StringName) -> void:
	for lid in lids:
		lid.hide()
	if target == State.SLEEPING:
		jumps = 0
	var texture := pose_map.texture_for(target)
	if not texture:
		return
	var next: Sprite2D = layers.get(texture)
	if not next:
		next = Sprite2D.new()
		next.texture = texture
		next.centered = false
		next.position = Vector2(-512, -960)
		next.modulate.a = 0.0
		var motion := ShaderMaterial.new()
		motion.shader = MOTION
		next.material = motion
		body.add_child(next)
		body.move_child(next, 0)
		layers[texture] = next
	next.material.set_shader_parameter("idle", target == State.IDLE)
	var initial := front == null
	front = next
	if initial:
		front.modulate.a = 1.0
		sleep_weight = 1.0 if target == State.SLEEPING else 0.0
		return
	if fade:
		fade.kill()
	fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for layer in layers.values():
		if layer == front or layer.modulate.a > 0.0:
			fade.tween_property(layer, "modulate:a", 1.0 if layer == front else 0.0, FADE_DURATION)
	fade.tween_property(self, "sleep_weight", 1.0 if target == State.SLEEPING else 0.0, FADE_DURATION)
	fade.tween_property(self, "pop", 1.04, FADE_DURATION / 2)
	fade.tween_property(self, "pop", 1.0, FADE_DURATION / 2).set_delay(FADE_DURATION / 2).from(1.04)

func react(target: StringName, seconds: float, count: int) -> void:
	if state.react(target, seconds):
		jump_age = 0
		jumps = count

func cancel_reaction() -> void:
	jumps = 0
	state.cancel()

func _process(delta: float) -> void:
	if not care: return
	state.advance(delta)
	if not is_visible_in_tree(): return
	phase += delta
	next_blink -= delta
	blink_age += delta
	if next_blink <= 0:
		blink_age = 0
		next_blink = randf_range(3.0, 5.0)
	var closure := maxf(0, 1.0 - absf(blink_age - 0.06) / 0.06)
	for lid in lids:
		lid.visible = state.current == State.IDLE and closure > 0
		lid.scale.y = closure
	jump_age += delta
	var arc := 0.0
	var squash := 0.0
	if state.current != State.SLEEPING and jump_age < jumps * 0.48:
		var t := fmod(jump_age, 0.48) / 0.48
		arc = sin(PI * t)
		squash = -cos(TAU * t) * 0.11
	var unit := minf(size.x, size.y) / 1024
	body.position = Vector2(size.x * 0.5, size.y * 0.9375 - unit * 105 * arc)
	var breath := 0.015 * (1 - cos(phase * 2.6)) if state.current == State.IDLE else 0.0
	breath += sleep_weight * (-0.045 + 0.012 * (1 - cos(phase * 1.6)))
	body.scale = unit * growth_factor * pop * Vector2(1 - squash, 1 + squash + breath)
