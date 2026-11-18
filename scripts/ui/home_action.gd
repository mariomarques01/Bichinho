extends Button

signal chosen

const PLATE = preload("res://scripts/ui/home_action.gdshader")
const LIGHT := [Color("#ffcf32"), Color("#42ddff"), Color("#c074ff"), Color("#ff6aba"), Color("#a56aff"), Color("#3ce896")]
const DEEP := [Color("#ff7404"), Color("#0082e7"), Color("#7322e4"), Color("#df006c"), Color("#5e1cda"), Color("#00884b")]
var visual: Control
var motion: Tween
var choosing := false

func setup(caption: String, icon_index: int) -> void:
	accessibility_name = caption
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("#fff1b5")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(28)
	add_theme_stylebox_override("focus", focus)
	visual = Control.new()
	visual.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var plate := ColorRect.new()
	plate.mouse_filter = MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PLATE
	material.set_shader_parameter("light", LIGHT[icon_index])
	material.set_shader_parameter("deep", DEEP[icon_index])
	plate.material = material
	visual.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon := Pictogram.new()
	icon.kind = icon_index
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	visual.add_child(icon)
	icon.position = Vector2(87, 5)
	icon.size = Vector2(44, 44)
	icon.scale = Vector2.ONE * 1.13

	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = MOUSE_FILTER_IGNORE
	var type := FontVariation.new()
	type.base_font = ThemeDB.fallback_font
	type.variation_embolden = 0.65
	label.add_theme_font_override("font", type)
	label.add_theme_font_size_override("font_size", 27)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("#3d174cd0"))
	label.add_theme_color_override("font_color", Color("#fff7ff"))
	visual.add_child(label)
	label.position = Vector2(4, 52)
	label.size = Vector2(216, 34)
	resized.connect(_pivot)
	_pivot()
	button_down.connect(func() -> void:
		if not choosing:
			_move(Vector2(0.94, 0.91), 0.08)
	)
	button_up.connect(func() -> void:
		if not choosing:
			_move(Vector2.ONE, 0.12)
	)
	pressed.connect(_choose)

func _pivot() -> void:
	visual.pivot_offset = size * 0.5

func _move(target: Vector2, duration: float) -> Tween:
	if motion and motion.is_running():
		motion.kill()
	motion = create_tween()
	motion.tween_property(visual, "scale", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return motion

func _choose() -> void:
	if choosing:
		return
	choosing = true
	await _move(Vector2(1.025, 1.025), 0.10).finished
	visual.scale = Vector2.ONE
	choosing = false
	if is_visible_in_tree():
		chosen.emit()

class Pictogram extends Control:
	var kind := 0
	const INK := Color("#fff9ff")
	const SHADE := Color("#32183c9c")

	func _draw() -> void:
		_paint(Vector2(0, 2), SHADE)
		_paint(Vector2.ZERO, INK)

	func _paint(at: Vector2, color: Color) -> void:
		match kind:
			0:
				for x in [7, 12, 17]:
					_line([Vector2(x, 5), Vector2(x, 15), Vector2(12, 18)], at, color, 3.0)
				_line([Vector2(12, 17), Vector2(12, 39)], at, color, 5.0)
				for y in [11, 15, 19]:
					draw_circle(at + Vector2(31, y), 6.1, color, true, -1, true)
				_line([Vector2(31, 21), Vector2(31, 39)], at, color, 5.0)
			1:
				_line([Vector2(6, 32), Vector2(6, 13), Vector2(12, 7), Vector2(21, 7), Vector2(25, 12)], at, color, 4.0)
				draw_arc(at + Vector2(26, 23), 10, PI, TAU, 20, color, 4.0, true)
				_line([Vector2(16, 24), Vector2(36, 24)], at, color, 3.5)
				for x in [17, 26, 35]:
					for y in [31, 38]:
						draw_circle(at + Vector2(x, y), 1.8, color, true, -1, true)
			2:
				_line([Vector2(4, 36), Vector2(4, 11), Vector2(9, 11)], at, color, 4.5)
				_line([Vector2(40, 36), Vector2(40, 25), Vector2(5, 25)], at, color, 4.5)
				_line([Vector2(9, 19), Vector2(36, 19), Vector2(39, 22)], at, color, 6.0)
				_line([Vector2(5, 30), Vector2(39, 30)], at, color, 4.0)
			3:
				var outline := PackedVector2Array()
				for i in 48:
					var t := TAU * float(i) / 48.0
					var x := 16.0 * pow(sin(t), 3.0)
					var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
					outline.append(at + Vector2(22 + x, 22 - y))
				draw_colored_polygon(outline, color)
				draw_polyline(outline + PackedVector2Array([outline[0]]), color, 1.0, true)
			4:
				_line([Vector2(6, 31), Vector2(11, 17), Vector2(15, 14), Vector2(28, 14), Vector2(34, 17), Vector2(39, 31), Vector2(35, 34), Vector2(28, 28), Vector2(16, 28), Vector2(9, 34), Vector2(6, 31)], at, color, 3.5)
				_line([Vector2(15, 18), Vector2(15, 25)], at, color, 2.5)
				_line([Vector2(11, 22), Vector2(19, 22)], at, color, 2.5)
				for point in [Vector2(29, 21), Vector2(34, 24)]:
					draw_circle(at + point, 1.8, color, true, -1, true)
			5:
				_line([Vector2(16, 6), Vector2(28, 6)], at, color, 3.6)
				_line([Vector2(18, 7), Vector2(18, 17), Vector2(8, 34), Vector2(10, 38), Vector2(34, 38), Vector2(36, 34), Vector2(26, 17), Vector2(26, 7)], at, color, 3.3)
				_line([Vector2(13, 29), Vector2(31, 29)], at, color, 2.4)
				draw_circle(at + Vector2(23, 24), 1.9, color, true, -1, true)

	func _line(points: Array[Vector2], offset: Vector2, color: Color, width: float) -> void:
		var path := PackedVector2Array()
		for point in points:
			path.append(point + offset)
		draw_polyline(path, color, width, true)
