extends MarginContainer

const Activities = preload("res://scripts/ui/activities.gd")
const Care = preload("res://scripts/needs/care.gd")
const REFERENCE = preload("res://assets/textures/feeding/referencia.jpg")
const SHEET = preload("res://assets/textures/feeding/sprites.jpg")
const PROFILE_ICON := Rect2(790, 18, 62, 66)
const HUNGER_ICON := Rect2(791, 101, 49, 49)
const NAVBAR := Rect2i(10, 700, 589, 134)
const TABS := [
	Rect2(16, 950, 144, 153), Rect2(160, 955, 136, 145),
	Rect2(295, 957, 135, 143), Rect2(430, 956, 135, 144),
	Rect2(565, 957, 138, 143),
]
const FOOD_NAMES := {"Sanduíche": "Carne", "Biscoito": "Cupcake"}
const IDLE := Rect2i(16, 13, 180, 187)
const EATING := Rect2i(391, 13, 175, 185)
const HAPPY := Rect2i(211, 13, 174, 182)
const TITLE := Rect2i(782, 170, 247, 70)
const FOOD_ART := {
	"Maçã": Rect2(29, 428, 79, 65),
	"Banana": Rect2(131, 432, 82, 63),
	"Sanduíche": Rect2(234, 426, 82, 69),
	"Biscoito": Rect2(341, 426, 82, 68),
	"Frutas vermelhas": Rect2(440, 428, 82, 67),
}

var hud: CanvasLayer
var care: Care
var selected := "Maçã"
var cards: Dictionary = {}
var counts: Dictionary = {}
var art: Dictionary = {}
var profile: Label
var wallet: Label
var stats: Dictionary = {}
var hunger: Label
var gauge: ProgressBar
var action: Button
var message: Label
var food_detail: Label
var canvas: Control
var press_position := Vector2.ZERO
var pointer_food := ""
var ghost: TextureRect
var animating := false
var shopping := false
var character: TextureRect
var idle_pose: Texture2D
var eating_pose: Texture2D
var happy_pose: Texture2D

func setup(owner_hud: CanvasLayer, manager: Care) -> void:
	hud = owner_hud
	care = manager
	canvas = get_parent()
	for name in FOOD_ART:
		art[name] = _atlas(FOOD_ART[name])
	idle_pose = _sprite(IDLE)
	eating_pose = _sprite(EATING)
	happy_pose = _sprite(HAPPY)
	character = _icon(canvas, idle_pose, Vector2.ZERO)
	character.z_index = -1
	canvas.resized.connect(_frame_character)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = hud.safe.theme
	_build()
	refresh()

func _build() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var back: Button = hud._button(header, "‹", Color("#235aa3"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(104, 103)
	back.add_theme_font_size_override("font_size", 66)
	back.accessibility_name = "Voltar ao quarto"
	back.pressed.connect(func() -> void: hud._open(0))
	var card: PanelContainer = hud._panel(header, Color("#2e193bdc"), 15)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var identity := HBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(identity)
	_icon(identity, _atlas(PROFILE_ICON), Vector2(88, 88))
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(info)
	_label(info, "Meu EVO", 37)
	profile = _label(info, "", 28)
	wallet = _label(hud._panel(header, Color("#38203fe8"), 16), "", 32)
	wallet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var needs := HBoxContainer.new()
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(needs)
	var stat_icons := [HUNGER_ICON, Rect2(911, 100, 52, 52), Rect2(1030, 101, 53, 53), Rect2(1149, 100, 53, 53)]
	for key: String in care.needs:
		var frame: PanelContainer = hud._panel(needs, Color("#321d3ce6"), 10)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(line)
		_icon(line, _atlas(stat_icons[stats.size()]), Vector2(51, 64))
		var metric := VBoxContainer.new()
		metric.mouse_filter = Control.MOUSE_FILTER_IGNORE
		metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(metric)
		var label := _label(metric, key, 26)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats[key] = [label, hud.meter(metric, Color("#91e52b"))]
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.y = 165
	column.add_child(gap)
	var title := _icon(column, _sprite(TITLE), Vector2(520, 146))
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	var preview: PanelContainer = hud._panel(stage, Color("#3d234ae8"), 19)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	preview.offset_left = -315
	preview.offset_top = 143
	preview.offset_right = 0
	var preview_body := VBoxContainer.new()
	preview_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(preview_body)
	var preview_head := HBoxContainer.new()
	preview_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_body.add_child(preview_head)
	_icon(preview_head, _atlas(HUNGER_ICON), Vector2(61, 61))
	var preview_text := VBoxContainer.new()
	preview_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_head.add_child(preview_text)
	_label(preview_text, "Fome", 29)
	hunger = _label(preview_text, "", 30)
	gauge = hud.meter(preview_body, Color("#8ceb29"))
	gauge.custom_minimum_size.y = 22

	food_detail = _label(column, "", 36)
	food_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tray := HBoxContainer.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_constant_override("separation", 10)
	column.add_child(tray)
	for food: String in FOOD_ART:
		var tile := Button.new()
		tile.custom_minimum_size.y = 154
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = FOOD_NAMES.get(food, food)
		tile.accessibility_name = tile.tooltip_text
		tile.toggle_mode = true
		tile.pressed.connect(_select.bind(food))
		tile.gui_input.connect(_tile_input.bind(food))
		tray.add_child(tile)
		cards[food] = tile
		var picture := _icon(tile, art[food], Vector2.ZERO)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 13
		picture.offset_top = 8
		picture.offset_right = -13
		picture.offset_bottom = -28
		var quantity := _label(tile, "", 31)
		quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		quantity.offset_top = -44
		quantity.offset_right = -11
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counts[food] = quantity

	action = hud._button(column, "Alimentar", Color("#4a9018"))
	action.custom_minimum_size.y = 109
	action.add_theme_font_size_override("font_size", 43)
	action.add_theme_stylebox_override("normal", _plate(Color("#539b18"), Color("#c8fe70"), 40, 15))
	action.add_theme_stylebox_override("hover", _plate(Color("#65ad20"), Color("#e0ff9e"), 40, 15))
	action.pressed.connect(_confirm)
	message = _label(column, "", 30)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size.y = 52
	_navigation(column)

func _navigation(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	for index in TABS.size():
		var tab := TextureButton.new()
		tab.texture_normal = _rounded_tab(TABS[index])
		tab.ignore_texture_size = true
		tab.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tab.custom_minimum_size.y = 166
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.accessibility_name = Activities.TITLES[index]
		if index != 0:
			tab.pressed.connect(hud._open.bind(index))
		row.add_child(tab)

	var bottom := _icon(parent, _sprite(NAVBAR), Vector2(0, 224))
	var captions := ["Evolução", "Inventário", "Quarto", "Missões", "Loja"]
	for index in captions.size():
		var hotspot := Button.new()
		hotspot.flat = true
		hotspot.accessibility_name = captions[index]
		hotspot.tooltip_text = captions[index]
		bottom.add_child(hotspot)
		hotspot.anchor_left = float(index) / captions.size()
		hotspot.anchor_right = float(index + 1) / captions.size()
		hotspot.anchor_bottom = 1.0
		match index:
			0, 3:
				hotspot.disabled = true
				hotspot.focus_mode = Control.FOCUS_NONE
			1:
				hotspot.pressed.connect(func() -> void:
					shopping = false
					refresh()
					message.text = "Inventário · selecione um alimento ou arraste."
					cards[selected].grab_focus()
				)
			2:
				hotspot.pressed.connect(func() -> void: hud._open(0))
			4:
				hotspot.pressed.connect(func() -> void:
					shopping = not shopping
					refresh()
					message.text = "Loja · escolha um alimento para repor." if shopping else "Arraste o alimento até o Evolin."
				)

func open() -> void:
	show()
	shopping = false
	character.show()
	_frame_character()
	_select(selected)
	message.text = "Arraste o alimento até o Evolin."

func close() -> void:
	hide()
	character.hide()
	_cancel_drag()

func refresh() -> void:
	profile.text = "Nível %d   ·   %d/50 XP" % [1 + care.xp / 50, care.xp % 50]
	wallet.text = "%d moedas" % care.coins
	for key: String in stats:
		stats[key][0].text = "%s %d%%" % [key, roundi(care.needs[key])]
		stats[key][1].value = care.needs[key]
	var current := roundi(care.needs["Fome"])
	var available: int = care.stock[selected]
	var preview := mini(100, current + Care.FOODS[selected]) if available > 0 else current
	hunger.text = "%d%%  →  %d%%" % [current, preview]
	gauge.value = preview
	food_detail.text = "%s  ·  +%d de fome" % [FOOD_NAMES.get(selected, selected), Care.FOODS[selected]]
	action.text = "Comprar %s · 5 moedas" % FOOD_NAMES.get(selected, selected) if available == 0 or shopping else "Alimentar"
	action.disabled = animating or care.rest_end > 0 or (not shopping and available > 0 and care.needs["Fome"] >= 99.0)
	for food: String in cards:
		counts[food].text = "×%d" % care.stock[food]

func _select(food: String) -> void:
	selected = food
	for name: String in cards:
		var tile: Button = cards[name]
		var active := name == food
		var face := Color("#bc6c22") if active else Color("#8b5268")
		var rim := Color("#ffe593") if active else Color("#e0a8a1")
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			tile.add_theme_stylebox_override(state, _plate(face, rim, 24, 0))
		tile.set_pressed_no_signal(active)
	refresh()

func _tile_input(event: InputEvent, food: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select(food)
		pointer_food = food
		press_position = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if not visible or pointer_food.is_empty():
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not is_instance_valid(ghost) and event.position.distance_to(press_position) > 28:
			ghost = _icon(canvas, art[pointer_food], Vector2.ZERO)
			ghost.size = Vector2(122, 122)
			ghost.z_index = 7
		if is_instance_valid(ghost):
			ghost.position = event.position - ghost.size / 2
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var dragged := is_instance_valid(ghost)
		var food := pointer_food
		_cancel_drag()
		if dragged:
			hud.request_food_drop(food, event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_drag()

func _cancel_drag() -> void:
	pointer_food = ""
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func _confirm() -> void:
	if shopping:
		message.text = _food_message(selected, care.buy(selected))
		return
	var tile: Button = cards[selected]
	serve(selected, tile.get_global_rect().get_center(), true)

func serve(food: String, at: Vector2, allow_purchase := false) -> void:
	if not visible or animating or not cards.has(food):
		return
	if care.stock[food] == 0 and not allow_purchase:
		message.text = "Esse alimento acabou."
		return
	var before: int = care.stock[food]
	message.text = _food_message(food, care.feed(food))
	if care.stock[food] >= before:
		return
	animating = true
	refresh()
	var bite := _icon(canvas, art[food], Vector2.ZERO)
	bite.size = Vector2(122, 122)
	bite.position = at - bite.size / 2
	bite.pivot_offset = bite.size / 2
	bite.z_index = 7
	var flight := create_tween().set_trans(Tween.TRANS_QUAD)
	flight.tween_property(bite, "position", _mouth_position() - bite.size / 2, 0.25).set_ease(Tween.EASE_OUT)
	flight.tween_callback(hud.food_eaten.emit)
	flight.tween_callback(func() -> void:
		character.texture = eating_pose if food == "Maçã" else happy_pose
		character.pivot_offset = character.size * Vector2(0.5, 1.0)
	)
	flight.parallel().tween_property(character, "scale", Vector2(1.04, 0.96), 0.13)
	flight.tween_property(bite, "scale", Vector2.ONE * 0.05, 0.20)
	flight.parallel().tween_property(bite, "modulate:a", 0.0, 0.20)
	flight.tween_callback(bite.queue_free)
	flight.tween_property(character, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	flight.tween_interval(0.22)
	flight.tween_callback(func() -> void: character.texture = idle_pose)
	flight.tween_callback(func() -> void:
		animating = false
		refresh()
	)

func _food_message(food: String, text: String) -> String:
	var label: String = FOOD_NAMES.get(food, food)
	return text.replace(food, label).replace(food.to_lower(), label.to_lower())

func _frame_character() -> void:
	var stage := canvas.size
	var height := minf(stage.x * 0.63, stage.y * 0.34)
	character.size = Vector2(height * 0.96, height)
	character.position = Vector2(stage.x * 0.46 - character.size.x * 0.5, stage.y * 0.60 - height)

func _mouth_position() -> Vector2:
	return character.position + character.size * Vector2(0.69, 0.58)

func accepts_drop(at: Vector2) -> bool:
	var normalized := (at - character.position) / character.size
	var body := (normalized - Vector2(0.56, 0.54)) / Vector2(0.43, 0.46)
	return body.length_squared() <= 1.0

func _sprite(region: Rect2i) -> ImageTexture:
	var image := SHEET.get_image().get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	# Clear only the pale backdrop connected to the square's perimeter.
	var queue: Array[Vector2i] = []
	for x in region.size.x:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, region.size.y - 1))
	for y in region.size.y:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(region.size.x - 1, y))
	var bounds := Rect2i(Vector2i.ZERO, region.size)
	var index := 0
	while index < queue.size():
		var pixel := queue[index]
		index += 1
		if not bounds.has_point(pixel):
			continue
		var color := image.get_pixelv(pixel)
		if color.a == 0 or minf(color.r, minf(color.g, color.b)) < 0.86:
			continue
		image.set_pixelv(pixel, Color.TRANSPARENT)
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			queue.append(pixel + direction)
	return ImageTexture.create_from_image(image)

func _rounded_tab(region: Rect2) -> ImageTexture:
	var image := REFERENCE.get_image().get_region(Rect2i(region))
	image.convert(Image.FORMAT_RGBA8)
	var dimensions := Vector2(image.get_size())
	for y in image.get_height():
		for x in image.get_width():
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / dimensions
			var distance := ((uv - Vector2(0.5, 0.5)).abs() - Vector2(0.29, 0.29)).max(Vector2.ZERO).length()
			var color := image.get_pixel(x, y)
			color.a = 1.0 - smoothstep(0.185, 0.215, distance)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SHEET
	texture.region = region
	texture.filter_clip = true
	return texture

func _icon(parent: Node, texture: Texture2D, minimum: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = minimum
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _label(parent: Node, caption: String, font_size: int) -> Label:
	var label: Label = hud._label(parent, caption, font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color("#331428"))
	return label

func _plate(fill: Color, rim: Color, radius: int, padding: int) -> StyleBoxFlat:
	var panel: StyleBoxFlat = hud._style(fill, radius, padding, rim)
	panel.set_border_width_all(5)
	panel.shadow_color = Color(0.27, 0.07, 0.13, 0.7)
	panel.shadow_size = 10
	return panel
