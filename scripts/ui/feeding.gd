extends MarginContainer

const Care = preload("res://scripts/needs/care.gd")
const SHEET = preload("res://assets/textures/feeding/sprites.jpg")
const PROFILE_ICON := Rect2(790, 18, 62, 66)
const HUNGER_ICON := Rect2(791, 101, 49, 49)
const FOOD_ART := {
	"Maçã": Rect2(29, 428, 79, 65),
	"Banana": Rect2(131, 432, 82, 63),
	"Frutas vermelhas": Rect2(440, 428, 82, 67),
}
const SANDWICH = preload("res://assets/textures/feeding/sandwich.png")
const COOKIE = preload("res://assets/textures/feeding/cookie.png")

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
var mouth_position := Vector2.ZERO

func setup(owner_hud: CanvasLayer, manager: Care) -> void:
	hud = owner_hud
	care = manager
	canvas = get_parent()
	for name in FOOD_ART:
		art[name] = _atlas(FOOD_ART[name])
	art["Sanduíche"] = SANDWICH
	art["Biscoito"] = COOKIE
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
	for key: String in care.needs:
		var frame: PanelContainer = hud._panel(needs, Color("#321d3ce6"), 13)
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var metric := VBoxContainer.new()
		metric.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(metric)
		var label := _label(metric, key, 29)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats[key] = [label, hud.meter(metric, Color("#91e52b"))]
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.y = 72
	column.add_child(gap)
	var title: PanelContainer = hud._panel(column, Color("#de6916"), 35)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_stylebox_override("panel", _plate(Color("#d96416"), Color("#ffe58b"), 49, 28))
	_label(title, "Alimentar", 65)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	var preview: PanelContainer = hud._panel(stage, Color("#3d234ae8"), 19)
	preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	preview.offset_left = -315
	preview.offset_top = 23
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
	for food: String in Care.FOODS:
		var tile := Button.new()
		tile.custom_minimum_size.y = 154
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = food
		tile.accessibility_name = food
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

func open() -> void:
	show()
	_select(selected)
	message.text = "Arraste o alimento até o Evolin."

func close() -> void:
	hide()
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
	food_detail.text = "%s  ·  +%d de fome" % [selected, Care.FOODS[selected]]
	action.text = "Comprar %s · 5 moedas" % selected if available == 0 else "Alimentar"
	action.disabled = animating or care.rest_end > 0 or (available > 0 and care.needs["Fome"] >= 99.0)
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
	var tile: Button = cards[selected]
	serve(selected, tile.get_global_rect().get_center(), true)

func serve(food: String, at: Vector2, allow_purchase := false) -> void:
	if not visible or animating or not cards.has(food):
		return
	if care.stock[food] == 0 and not allow_purchase:
		message.text = "Esse alimento acabou."
		return
	var before: int = care.stock[food]
	message.text = care.feed(food)
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
	flight.tween_property(bite, "position", mouth_position - bite.size / 2, 0.25).set_ease(Tween.EASE_OUT)
	flight.tween_callback(hud.food_eaten.emit)
	flight.tween_property(bite, "scale", Vector2.ONE * 0.05, 0.20)
	flight.parallel().tween_property(bite, "modulate:a", 0.0, 0.20)
	flight.tween_callback(bite.queue_free)
	flight.tween_callback(func() -> void:
		animating = false
		refresh()
	)

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
