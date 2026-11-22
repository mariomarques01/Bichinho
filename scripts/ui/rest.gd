extends "res://scripts/ui/portrait_activity.gd"
const PoseView = preload("res://scripts/pet/evolin_poses.gd")
const PoseScene = preload("res://scenes/pet/evolin_poses.tscn")

const REFERENCE = preload("res://assets/textures/rest/descansar.jpg")
const ATLAS = preload("res://assets/textures/rest/atlas.jpg")
const MOTION = preload("res://scripts/ui/rest_motion.gdshader")
const DURATIONS := [30, 60, 180]
const ITEMS := ["Almofada", "Pijama", "Touca", "Máscara", "Ursinho"]
const ITEM_TILES := [
	Rect2(63, 790, 118, 107), Rect2(186, 790, 114, 107),
	Rect2(303, 790, 115, 107), Rect2(424, 790, 115, 107),
	Rect2(544, 790, 113, 107),
]
const ITEM_ART := [
	Rect2i(687, 497, 112, 82), Rect2i(805, 490, 106, 91),
	Rect2i(916, 495, 110, 84), Rect2i(1027, 502, 119, 77),
	Rect2i(1147, 488, 90, 92),
]
const BEDSIDE_POSITIONS := [
	Rect2(76, 596, 127, 94), Rect2(532, 582, 131, 113),
	Rect2(529, 335, 115, 91), Rect2(266, 451, 125, 78),
	Rect2(552, 584, 115, 118),
]

var poses: PoseView
var motion := ShaderMaterial.new()
var selected := 0
var item_textures: Array[Texture2D] = []
var prop: TextureRect
var selected_outline: Panel
var plain_pillow: Panel
var panel: Panel
var countdown: Label
var countdown_second := 0
var timer_label: Label
var duration_buttons: Array[Button] = []
var wake_button: Button
var resting := false
var rest_transition: Tween

func setup(owner_hud: CanvasLayer, profile: Care) -> void:
	_setup_portrait(owner_hud, profile, REFERENCE)
	motion.shader = MOTION
	motion.set_shader_parameter("sleeping", 0.0)
	portrait.material = motion
	_texture(self, preload("res://assets/textures/rest/stage_patch.png"), Rect2(94, 308, 367, 333))
	var frame := Control.new()
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.position = Vector2(123, 278)
	frame.size = Vector2(430, 430)
	poses = PoseScene.instantiate()
	frame.add_child(poses)
	poses.setup(care)

	for region: Rect2i in ITEM_ART:
		item_textures.append(_cutout(ATLAS, region))
	prop = _texture(self, item_textures[0], BEDSIDE_POSITIONS[0])
	_hit("Cama · duração do descanso", Rect2(85, 323, 565, 451)).pressed.connect(_toggle_duration)
	_build_shelf()
	_build_navigation(2, 928)
	timer_label = _text(self, "", Rect2(96, 900, 528, 28), 20)
	timer_label.add_theme_constant_override("outline_size", 6)
	_build_duration()
	_select(0)
	close()

func _build_shelf() -> void:
	plain_pillow = Panel.new()
	plain_pillow.mouse_filter = MOUSE_FILTER_IGNORE
	plain_pillow.position = ITEM_TILES[0].position
	plain_pillow.size = ITEM_TILES[0].size
	plain_pillow.add_theme_stylebox_override("panel", _box(Color("#49355f"), Color("#b588d3"), 24, 3))
	add_child(plain_pillow)
	_texture(plain_pillow, item_textures[0], Rect2(12, 11, 94, 83))
	selected_outline = Panel.new()
	selected_outline.mouse_filter = MOUSE_FILTER_IGNORE
	selected_outline.add_theme_stylebox_override("panel", _box(Color(0.68, 0.39, 0.89, 0.08), Color("#e5ff93"), 24, 4))
	add_child(selected_outline)
	for index in ITEM_TILES.size():
		_hit(ITEMS[index], ITEM_TILES[index]).pressed.connect(_choose_item.bind(index))
	_hit("Acessório anterior", Rect2(12, 790, 46, 107)).pressed.connect(func() -> void: _choose_item(posmod(selected - 1, ITEMS.size())))
	_hit("Próximo acessório", Rect2(659, 790, 48, 107)).pressed.connect(func() -> void: _choose_item(posmod(selected + 1, ITEMS.size())))

func _build_duration() -> void:
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _box(Color("#29143df7"), Color("#d08cf0"), 25, 3))
	add_child(panel)
	panel.position = Vector2(76, 670)
	panel.size = Vector2(568, 105)
	countdown = _text(panel, "", Rect2(0, 5, 568, 34), 23)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	panel.add_child(row)
	row.position = Vector2(14, 44)
	row.size = Vector2(540, 49)
	for index in DURATIONS.size():
		var button := _button(row, ["30 min", "1 hora", "3 horas"][index])
		button.pressed.connect(_start.bind(DURATIONS[index]))
		duration_buttons.append(button)
	wake_button = _button(row, "Acordar")
	wake_button.pressed.connect(func() -> void:
		care.wake()
		hud.play_sound(&"toque")
		panel.hide()
	)
	panel.hide()

func _button(parent: Control, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_stylebox_override("normal", _box(Color("#7440ac"), Color("#cc94ed"), 19, 2))
	button.add_theme_stylebox_override("hover", _box(Color("#9855d0"), Color("#efc9ff"), 19, 2))
	button.add_theme_stylebox_override("pressed", _box(Color("#4d297d"), Color("#ffeafc"), 19, 2))
	parent.add_child(button)
	return button

func open() -> void:
	show()
	panel.hide()
	refresh()

func close() -> void:
	hide()
	panel.hide()

func _toggle_duration() -> void:
	hud.play_sound(&"toque")
	panel.visible = not panel.visible
	refresh()

func _start(minutes: int) -> void:
	if care.rest(minutes):
		hud.play_sound(&"descanso")
		panel.hide()

func refresh() -> void:
	super.refresh()
	var active := care.rest_end > 0
	_refresh_countdown(active)
	for button in duration_buttons:
		button.visible = not active
	wake_button.visible = active
	if resting != active:
		resting = active
		if rest_transition and rest_transition.is_running():
			rest_transition.kill()
		rest_transition = create_tween().set_trans(Tween.TRANS_SINE)
		var previous: float = motion.get_shader_parameter("sleeping")
		rest_transition.tween_method(_set_sleeping, previous, 1.0 if active else 0.0, 0.55)

func _process(_delta: float) -> void:
	if is_visible_in_tree() and resting and care.now() != countdown_second:
		_refresh_countdown(true)

func _refresh_countdown(active: bool) -> void:
	countdown_second = care.now()
	var remaining := maxi(0, care.rest_end - countdown_second)
	var duration := "%02d:%02d:%02d" % [remaining / 3600, remaining / 60 % 60, remaining % 60]
	countdown.text = "Acorda em " + duration if active else "Quanto tempo o Evolin vai descansar?"
	timer_label.text = "Descansando · " + duration if active else ""

func _set_sleeping(amount: float) -> void:
	motion.set_shader_parameter("sleeping", amount)
	poses.pivot_offset = poses.size * Vector2(0.5, 0.94)
	poses.scale.y = 1.0 - 0.08 * amount

func _choose_item(index: int) -> void:
	hud.play_sound(&"toque")
	_select(index)

func _select(index: int) -> void:
	selected = index
	plain_pillow.visible = index != 0
	selected_outline.visible = index != 0
	selected_outline.position = ITEM_TILES[index].position
	selected_outline.size = ITEM_TILES[index].size
	prop.visible = index != 0
	prop.texture = item_textures[index]
	prop.position = BEDSIDE_POSITIONS[index].position
	prop.size = BEDSIDE_POSITIONS[index].size
