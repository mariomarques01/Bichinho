extends Control

const Care = preload("res://scripts/needs/care.gd")
const MOTION = preload("res://scripts/pet/pose_motion.gdshader")
const ART := {
	"idle": preload("res://assets/poses/pose_idle.png"),
	"happy": preload("res://assets/poses/pose_happy.png"),
	"sad": preload("res://assets/poses/pose_sad.png"),
	"sleepy": preload("res://assets/poses/pose_sleepy.png"),
	"hungry": preload("res://assets/poses/pose_hungry.png"),
	"dirty": preload("res://assets/poses/pose_dirty.png"),
	"angry": preload("res://assets/poses/pose_angry.png"),
	"celebrate": preload("res://assets/poses/pose_celebrate.png"),
}

@export var left_eye := Vector2(0.397, 0.462)
@export var right_eye := Vector2(0.601, 0.462)
var care: Care
var pose := ""
var body := Node2D.new()
var front := Sprite2D.new()
var back := Sprite2D.new()
var lids: Array[Polygon2D] = []
var phase := 0.0
var next_blink := randf_range(3.0, 5.0)
var blink_age := 1.0
var override_pose := ""
var hold := 0.0
var jump_age := 0.0
var jumps := 0
var fade: Tween
var growth_factor := 1.0
var pop := 1.0

static func mood(needs: Dictionary, resting: bool) -> String:
	if needs.Higiene <= 35: return "dirty"
	if needs.Fome <= 35: return "hungry"
	if resting or needs.Energia <= 35: return "sleepy"
	if needs.Felicidade <= 35: return "sad"
	if needs.Felicidade >= 80: return "happy"
	return "idle"

func setup(profile: Care) -> void:
	care = profile
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(body)
	for sprite in [back, front]:
		body.add_child(sprite)
		sprite.centered = false
		sprite.position = Vector2(-512, -960)
	var motion := ShaderMaterial.new()
	motion.shader = MOTION
	front.material = motion
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
	refresh()
	care.changed.connect(refresh)
	_process(0)

func refresh() -> void:
	var target := override_pose if hold > 0 else mood(care.needs, care.rest_end > 0)
	if target == pose: return
	if fade: fade.kill()
	back.texture = front.texture
	front.texture = ART[target]
	front.material.set_shader_parameter("idle", target == "idle")
	if pose != "":
		back.modulate.a = 1
		front.modulate.a = 0
		fade = create_tween().set_parallel()
		fade.tween_property(back, "modulate:a", 0.0, 0.15)
		fade.tween_property(front, "modulate:a", 1.0, 0.15)
		fade.tween_property(self, "pop", 1.12, 0.075)
		fade.tween_property(self, "pop", 1.0, 0.075).set_delay(0.075)
	pose = target
	for lid in lids: lid.hide()

func react(target: String, seconds: float, count: int) -> void:
	if hold > 0 and override_pose == "celebrate" and target != "celebrate": return
	override_pose = target
	hold = seconds
	jump_age = 0
	jumps = count
	refresh()

func _process(delta: float) -> void:
	if not care: return
	if hold > 0:
		hold -= delta
		if hold <= 0: refresh()
	if not is_visible_in_tree(): return
	phase += delta
	next_blink -= delta
	blink_age += delta
	if next_blink <= 0:
		blink_age = 0
		next_blink = randf_range(3.0, 5.0)
	var closure := maxf(0, 1.0 - absf(blink_age - 0.06) / 0.06)
	for lid in lids:
		lid.visible = pose == "idle" and closure > 0
		lid.scale.y = closure
	jump_age += delta
	var arc := 0.0
	var squash := 0.0
	if jump_age < jumps * 0.48:
		var t := fmod(jump_age, 0.48) / 0.48
		arc = sin(PI * t)
		squash = -cos(TAU * t) * 0.11
	var unit := minf(size.x, size.y) / 1024
	body.position = Vector2(size.x * 0.5, size.y * 0.9375 - unit * 105 * arc)
	var breath := 0.015 * (1 - cos(phase * 2.6)) if pose == "idle" else 0.0
	body.scale = unit * growth_factor * pop * Vector2(1 - squash, 1 + squash + breath)
