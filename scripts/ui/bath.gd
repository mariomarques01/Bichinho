extends Control

const Care = preload("res://scripts/needs/care.gd")
const REFERENCE = preload("res://assets/textures/bath/banho.jpg")
const ATLAS = preload("res://assets/textures/bath/atlas.jpg")
const DESIGN := Vector2(720, 1280)
const AREA := Rect2(125, 319, 473, 419)
const TOOLS := ["Esponja", "Sabonete", "Xampu", "Toalha"]
const TILE_RECTS := [
	Rect2(107, 796, 118, 101), Rect2(238, 796, 116, 101),
	Rect2(368, 796, 116, 101), Rect2(496, 796, 116, 101),
]
const TOOL_SPRITES := [
	Rect2i(860, 595, 101, 84), Rect2i(966, 598, 100, 81),
	Rect2i(1077, 591, 79, 89), Rect2i(1162, 593, 99, 85),
]
const BUBBLE := Rect2i(1074, 411, 42, 44)
const FOAM := Rect2i(848, 407, 121, 70)
const STAT_X := [83, 254, 426, 596]
const STAT_NAMES := ["Fome", "Higiene", "Energia", "Felicidade"]

var hud: CanvasLayer
var care: Care
var portrait: TextureRect
var xp: ProgressBar
var coins: Label
var level: Label
var readings: Array[Label] = []
var meters: Array[ProgressBar] = []
var assets: Array[Texture2D] = []
var bubble_art: Texture2D
var foam_art: Texture2D
var selected := 0
var selected_outline: Panel
var inactive_sponge: Panel
var warning: Label
var warning_timer: Timer
var progress := 0
var dragging := false
var drag_origin := Vector2.ZERO
var last_sample := Vector2.ZERO
var ghost: TextureRect
var effects: Control

func setup(owner_hud: CanvasLayer, profile: Care) -> void:
	hud = owner_hud
	care = profile
	mouse_filter = MOUSE_FILTER_IGNORE
	size = DESIGN
	theme = hud.safe.theme
	portrait = _texture(self, REFERENCE, Rect2(Vector2.ZERO, DESIGN))
	for region: Rect2i in TOOL_SPRITES:
		assets.append(_cutout(region))
	bubble_art = _cutout(BUBBLE)
	foam_art = _cutout(FOAM)
	_build_profile()
	_build_tools()
	_build_navigation()
	effects = Control.new()
	effects.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(effects)
	warning = _text(self, "", Rect2(106, 909, 508, 34), 20)
	warning.add_theme_constant_override("outline_size", 7)
	warning_timer = Timer.new()
	warning_timer.one_shot = true
	warning_timer.timeout.connect(warning.hide)
	add_child(warning_timer)
	get_parent().resized.connect(_frame)
	_frame()
	close()

func _frame() -> void:
	scale = get_parent().size / DESIGN

func _build_profile() -> void:
	var deep := Color("#171531")
	level = _value(Rect2(109, 42, 130, 24), 18, deep)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coins = _value(Rect2(383, 20, 78, 34), 24, deep)
	_value(Rect2(584, 20, 68, 34), 24, deep).text = "0"
	xp = _bar(Rect2(113, 68, 184, 15), Color("#c541ea"), Color("#14465a"))
	for index in STAT_X.size():
		var x: int = STAT_X[index]
		readings.append(_value(Rect2(x + 3, 137, 90, 25), 19, Color("#251c39")))
		meters.append(_bar(Rect2(x - 2, 162, 94, 17), Color("#95e825"), Color("#153d2c")))

func _build_tools() -> void:
	inactive_sponge = Panel.new()
	inactive_sponge.mouse_filter = MOUSE_FILTER_IGNORE
	inactive_sponge.position = TILE_RECTS[0].position
	inactive_sponge.size = TILE_RECTS[0].size
	inactive_sponge.add_theme_stylebox_override("panel", _box(Color("#382e72"), Color("#a29cd9"), 21, 3))
	add_child(inactive_sponge)
	_texture(inactive_sponge, assets[0], Rect2(13, 8, 92, 84))
	selected_outline = Panel.new()
	selected_outline.mouse_filter = MOUSE_FILTER_IGNORE
	selected_outline.add_theme_stylebox_override("panel", _box(Color(0.44, 0.85, 0.18, 0.1), Color("#ecff82"), 23, 4))
	add_child(selected_outline)
	for index in TILE_RECTS.size():
		var tile := _hit(TOOLS[index], TILE_RECTS[index])
		tile.pressed.connect(func() -> void: _select(index, true))
		tile.gui_input.connect(_tool_input.bind(index))
	_hit("Ferramenta anterior", Rect2(52, 795, 50, 102)).pressed.connect(func() -> void: _select(posmod(selected - 1, TOOLS.size()), true))
	_hit("Próxima ferramenta", Rect2(618, 795, 50, 102)).pressed.connect(func() -> void: _select(posmod(selected + 1, TOOLS.size()), true))

func _build_navigation() -> void:
	var captions := ["Alimentar", "Higienizar", "Descansar", "Fazer carinho", "Brincar"]
	for index in captions.size():
		var tab := _hit(captions[index], Rect2(17 + 137 * index, 951, 135, 148))
		if index != 1:
			tab.pressed.connect(hud._open.bind(index))
	_hit("Quarto", Rect2(281, 1104, 150, 153)).pressed.connect(func() -> void: hud._open(1))
	_hit("Inventário", Rect2(146, 1128, 131, 118)).pressed.connect(func() -> void: hud._open(0))
	_hit("Loja", Rect2(555, 1128, 142, 118)).pressed.connect(_open_store)
	_hit("Loja de alimentos", Rect2(465, 10, 45, 49)).pressed.connect(_open_store)

func _open_store() -> void:
	hud._open(0)
	hud.feeding.shopping = true
	hud.feeding.refresh()
	hud.feeding.message.text = "Loja · toque em um alimento para comprar por 5 moedas."

func open() -> void:
	progress = 0
	show()
	warning.hide()
	_select(0)
	refresh()

func close() -> void:
	hide()
	_end_drag()
	warning.hide()
	for effect in effects.get_children():
		effect.queue_free()

func refresh() -> void:
	level.text = "Nível %d" % (1 + care.xp / 50)
	coins.text = str(care.coins)
	xp.value = float(care.xp % 50) * 2
	for index in STAT_NAMES.size():
		var value: float = care.needs[STAT_NAMES[index]]
		readings[index].text = "%d%%" % roundi(value)
		meters[index].value = value

func _select(index: int, announce := false) -> void:
	selected = index
	inactive_sponge.visible = index != 0
	selected_outline.visible = index != 0
	selected_outline.position = TILE_RECTS[index].position
	selected_outline.size = TILE_RECTS[index].size
	if announce:
		hud.play_sound(&"toque")

func _tool_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select(index)
		_begin_drag(_local(get_viewport().get_mouse_position()))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _local(event.position)
		if event.pressed and AREA.has_point(at) and not dragging:
			_begin_drag(at)
		elif not event.pressed and dragging:
			_end_drag()
	if event is InputEventMouseMotion and dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var at := _local(event.position)
		if not is_instance_valid(ghost) and at.distance_to(drag_origin) >= 14:
			ghost = _texture(effects, assets[selected], Rect2(at - Vector2(45, 40), Vector2(90, 80)))
			ghost.z_index = 3
		if is_instance_valid(ghost):
			ghost.position = at - ghost.size * 0.5
			if AREA.has_point(at) and at.distance_to(last_sample) >= 23.0:
				last_sample = at
				scrub(at)
			get_viewport().set_input_as_handled()

func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin_drag(at: Vector2) -> void:
	dragging = true
	drag_origin = at
	last_sample = at

func _end_drag() -> void:
	dragging = false
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_drag()

func scrub(at: Vector2) -> void:
	if not visible or not AREA.has_point(at):
		return
	if care.rest_end > 0:
		_notice("Evolin está descansando.")
		return
	if selected == 3:
		for effect in effects.get_children():
			if effect != ghost:
				effect.queue_free()
		_notice("Toalha · espuma removida.")
		return
	if care.needs["Higiene"] >= 99.0:
		_notice("Evolin já está limpinho!")
		return
	progress += 1
	_spawn(at)
	hud.play_sound(&"bolha")
	if progress == 10:
		progress = 0
		care.wash()
		hud.play_sound(&"recompensa")
		_notice("Banho completo! Evolin está limpinho.")
	else:
		_notice("Banho · %d%%" % (progress * 10))

func _spawn(at: Vector2) -> void:
	var art := foam_art if selected == 1 else bubble_art
	var extent := Vector2(82, 47) if selected == 1 else Vector2(35, 37)
	var count := 2 if selected == 2 else 1
	for index in count:
		var drift := Vector2(randf_range(-42, 42), -randf_range(55, 95))
		var particle := _texture(effects, art, Rect2(at - extent * 0.5 + Vector2(24 * index, 0), extent))
		var float_up := particle.create_tween().set_parallel()
		float_up.tween_property(particle, "position", particle.position + drift, 0.69)
		float_up.tween_property(particle, "modulate:a", 0.0, 0.40).set_delay(0.29)
		float_up.chain().tween_callback(particle.queue_free)

func _notice(text: String) -> void:
	warning.text = text
	warning.show()
	warning_timer.start(1.45)

func _texture(parent: Control, art: Texture2D, rect: Rect2) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = art
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(sprite)
	sprite.position = rect.position
	sprite.size = rect.size
	return sprite

func _text(parent: Control, content: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color("#100e29"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label

func _value(rect: Rect2, font_size: int, background: Color) -> Label:
	var patch := Panel.new()
	patch.mouse_filter = MOUSE_FILTER_IGNORE
	patch.add_theme_stylebox_override("panel", _box(background, background, 5))
	add_child(patch)
	patch.position = rect.position
	patch.size = rect.size
	return _text(patch, "", Rect2(Vector2.ZERO, rect.size), font_size)

func _bar(rect: Rect2, fill: Color, track: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _box(track, track, 6))
	bar.add_theme_stylebox_override("fill", _box(fill, fill.lightened(0.32), 6, 1))
	add_child(bar)
	bar.position = rect.position
	bar.size = rect.size
	return bar

func _box(fill: Color, border: Color, radius: int, stroke := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.set_border_width_all(stroke)
	return box

func _hit(caption: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.flat = true
	button.accessibility_name = caption
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button

func _cutout(region: Rect2i) -> ImageTexture:
	var image := ATLAS.get_image().get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	var points: Array[Vector2i] = []
	for x in region.size.x:
		points.append(Vector2i(x, 0))
		points.append(Vector2i(x, region.size.y - 1))
	for y in region.size.y:
		points.append(Vector2i(0, y))
		points.append(Vector2i(region.size.x - 1, y))
	var bounds := Rect2i(Vector2i.ZERO, region.size)
	while not points.is_empty():
		var point: Vector2i = points.pop_back()
		if not bounds.has_point(point):
			continue
		var pixel := image.get_pixelv(point)
		if pixel.a == 0.0 or minf(pixel.r, minf(pixel.g, pixel.b)) < 0.89:
			continue
		image.set_pixelv(point, Color.TRANSPARENT)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			points.append(point + offset)
	return ImageTexture.create_from_image(image)
