extends Control

const Action = preload("res://scripts/ui/home_action.gd")
const SHARPEN = preload("res://scripts/ui/home_sharpen.gdshader")
const Care = preload("res://scripts/needs/care.gd")
const SHEET = preload("res://assets/textures/home/atlas.jpg")
const DESIGN := Vector2(720, 1280)
const PET_RECT := Rect2(110, 373, 365, 430)
const PET := Rect2i(29, 89, 305, 371)
const ROOM := Rect2(13, 508, 566, 515)
const PROFILE := Rect2(600, 94, 373, 101)
const WALLET := Rect2(983, 110, 172, 58)
const NAV := Rect2i(597, 620, 557, 120)
const STAT_KEYS := ["Fome", "Higiene", "Energia", "Felicidade"]
const STAT_RECTS := [
	Rect2(605, 246, 136, 73), Rect2(742, 246, 135, 73),
	Rect2(878, 246, 135, 73), Rect2(1015, 246, 140, 73),
]
const ACTION_NAMES := ["Alimentar", "Higienizar", "Descansar", "Carinho", "Brincar", "Experimentar"]

var hud: CanvasLayer
var care: Care
var character: TextureRect
var room_art: TextureRect
var stage_floor: TextureRect
var night_tint := Color.WHITE
var xp_bar: ProgressBar
var level: Label
var xp_reading: Label
var coins: Label
var stat_readings: Array[Label] = []
var stat_bars: Array[ProgressBar] = []
var action_buttons: Array[Action] = []
var sharpen := ShaderMaterial.new()
var reaction: Tween

func setup(owner_hud: CanvasLayer, profile: Care) -> void:
	hud = owner_hud
	care = profile
	size = DESIGN
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = hud.safe.theme
	sharpen.shader = SHARPEN
	_build_room()
	_build_profile()
	_build_navigation()
	get_parent().resized.connect(_frame)
	_frame()
	refresh()

func _frame() -> void:
	scale = get_parent().size / DESIGN

func _build_room() -> void:
	var background := ColorRect.new()
	background.color = Color("#291436")
	background.size = DESIGN
	background.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(background)
	room_art = _picture(_atlas(ROOM), Rect2(0, 241, 720, 688))
	stage_floor = _picture(_atlas(Rect2(18, 1002, 555, 13)), Rect2(0, 929, 720, 351))
	stage_floor.modulate = Color("#885d89")
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grade.colors = PackedColorArray([Color("#29143600"), Color("#291436db"), Color("#291436")])
	var tone := GradientTexture2D.new()
	tone.gradient = grade
	tone.fill_from = Vector2(0, 0)
	tone.fill_to = Vector2(0, 1)
	_picture(tone, Rect2(0, 908, 720, 372))
	var shade_texture := GradientTexture2D.new()
	var shade := Gradient.new()
	shade.colors = PackedColorArray([Color("#35112775"), Color("#35112700")])
	shade_texture.gradient = shade
	shade_texture.fill = GradientTexture2D.FILL_RADIAL
	shade_texture.fill_from = Vector2(0.5, 0.5)
	shade_texture.fill_to = Vector2(1.0, 0.5)
	_picture(shade_texture, Rect2(143, 765, 296, 63))
	character = _picture(_cutout(PET), PET_RECT)
	character.pivot_offset = PET_RECT.size * Vector2(0.5, 1.0)
	_hit("Luminária", Rect2(618, 399, 94, 240)).pressed.connect(_lamp)

func _build_profile() -> void:
	_sharp_picture(_atlas(PROFILE), Rect2(16, 21, 455, 123))
	_sharp_picture(_atlas(WALLET), Rect2(484, 47, 218, 74))
	_value(Rect2(142, 35, 151, 33), 28, HORIZONTAL_ALIGNMENT_LEFT).text = "Meu EVO"
	level = _value(Rect2(143, 69, 130, 32), 23, HORIZONTAL_ALIGNMENT_LEFT)
	xp_reading = _value(Rect2(309, 69, 139, 30), 22)
	xp_bar = _meter(Rect2(144, 101, 298, 22), Color("#ee38e7"), Color("#583575"))
	coins = _value(Rect2(552, 67, 79, 34), 27)
	_hit("Loja de alimentos", Rect2(638, 48, 61, 71)).pressed.connect(_open_store)
	for index in STAT_RECTS.size():
		var x := 18.0 + index * 172.0
		_sharp_picture(_atlas(STAT_RECTS[index]), Rect2(x, 151, 167, 90))
		_value(Rect2(x + 63, 160, 99, 25), 17).text = STAT_KEYS[index]
		stat_readings.append(_value(Rect2(x + 76, 185, 78, 23), 21))
		stat_bars.append(_meter(Rect2(x + 67, 209, 92, 19),
			Color("#77aaff") if index == 2 else Color("#9be92c"), Color("#3a2859")))

func _build_navigation() -> void:
	for index in ACTION_NAMES.size():
		var x := 18.0 + (index % 3) * 230.0
		var y := 939.0 + int(index / 3) * 96.0
		var button := Action.new()
		add_child(button)
		button.position = Vector2(x, y)
		button.size = Vector2(224, 96)
		button.setup(ACTION_NAMES[index], index)
		button.chosen.connect(hud._open.bind(index))
		action_buttons.append(button)

	_sharp_picture(_navigation_art(NAV), Rect2(17, 1144, 686, 123))
	_hit("Inventário", Rect2(156, 1160, 128, 92)).pressed.connect(func() -> void: hud._open(0))
	_hit("Quarto", Rect2(288, 1146, 144, 113)).pressed.connect(func() -> void: hud.play_sound(&"toque"))
	_hit("Loja", Rect2(560, 1161, 143, 90)).pressed.connect(_open_store)

func _open_store() -> void:
	hud._open(0)
	hud.feeding.shopping = true
	hud.feeding.refresh()
	hud.feeding.message.text = "Loja · toque em um alimento para comprar por 5 moedas."

func _lamp() -> void:
	hud.play_sound(&"toque")
	hud.lamp_requested.emit()

func set_night(night: bool) -> void:
	night_tint = Color("#7f82ca") if night else Color.WHITE
	room_art.modulate = night_tint
	character.modulate = night_tint

func refresh() -> void:
	level.text = "Nível %d" % (1 + care.xp / 50)
	xp_reading.text = "%d/50 XP" % (care.xp % 50)
	xp_bar.value = float(care.xp % 50) * 2.0
	coins.text = str(care.coins)
	for index in STAT_KEYS.size():
		var value: float = care.needs[STAT_KEYS[index]]
		stat_readings[index].text = "%d%%" % roundi(value)
		stat_bars[index].value = value

func hit_pet(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	var normalized := (local - PET_RECT.position) / PET_RECT.size
	return ((normalized - Vector2(0.50, 0.56)) / Vector2(0.43, 0.43)).length_squared() <= 1.0

func pet_point() -> Vector2:
	return get_global_transform_with_canvas() * (PET_RECT.position + PET_RECT.size * Vector2(0.55, 0.43))

func heart_point() -> Vector2:
	return get_global_transform_with_canvas() * (PET_RECT.position + PET_RECT.size * Vector2(0.76, 0.13))

func react() -> void:
	if reaction and reaction.is_running():
		reaction.kill()
	character.scale = Vector2.ONE
	reaction = create_tween()
	reaction.tween_property(character, "scale", Vector2(1.045, 0.96), 0.13)
	reaction.tween_property(character, "scale", Vector2.ONE, 0.31).set_trans(Tween.TRANS_BACK)

func _atlas(region: Rect2) -> AtlasTexture:
	var art := AtlasTexture.new()
	art.atlas = SHEET
	art.region = region
	art.filter_clip = true
	return art

func _picture(art: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = art
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

func _sharp_picture(art: Texture2D, rect: Rect2) -> TextureRect:
	var picture := _picture(art, rect)
	picture.material = sharpen
	return picture

func _hit(caption: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.flat = true
	button.add_theme_stylebox_override("pressed", _style(Color("#f6d1ff49"), 24))
	button.accessibility_name = caption
	add_child(button)
	button.position = rect.position
	button.size = rect.size
	return button

func _value(rect: Rect2, text_size: int, alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var patch := Panel.new()
	patch.mouse_filter = MOUSE_FILTER_IGNORE
	patch.add_theme_stylebox_override("panel", _style(Color("#271634"), 5))
	add_child(patch)
	patch.position = rect.position
	patch.size = rect.size
	var value := Label.new()
	value.mouse_filter = MOUSE_FILTER_IGNORE
	value.horizontal_alignment = alignment
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", text_size)
	value.add_theme_constant_override("outline_size", 3)
	value.add_theme_color_override("font_outline_color", Color("#210c2a"))
	patch.add_child(value)
	value.size = rect.size
	return value

func _meter(rect: Rect2, fill: Color, track: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(track, 7))
	bar.add_theme_stylebox_override("fill", _style(fill, 7))
	add_child(bar)
	bar.position = rect.position
	bar.size = rect.size
	return bar

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = color
	plate.set_corner_radius_all(radius)
	return plate

func _navigation_art(region: Rect2i) -> ImageTexture:
	var image := SHEET.get_image().get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	var size_px := Vector2(region.size)
	for y in region.size.y:
		for x in region.size.x:
			var uv := (Vector2(x, y) + Vector2(0.5, 0.5)) / size_px
			var center := (uv - Vector2(0.50, 0.50)) / Vector2(0.105, 0.52)
			var tray := ((uv - Vector2(0.50, 0.55)).abs() - Vector2(0.421, 0.29)).max(Vector2.ZERO).length()
			var mask := maxf(1.0 - smoothstep(0.065, 0.079, tray), 1.0 - smoothstep(0.95, 1.0, center.length()))
			var color := image.get_pixel(x, y)
			color.a = mask
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _cutout(region: Rect2i) -> ImageTexture:
	var image := SHEET.get_image().get_region(region)
	image.convert(Image.FORMAT_RGBA8)
	var fill: Array[Vector2i] = []
	for x in region.size.x:
		fill.append(Vector2i(x, 0))
		fill.append(Vector2i(x, region.size.y - 1))
	for y in region.size.y:
		fill.append(Vector2i(0, y))
		fill.append(Vector2i(region.size.x - 1, y))
	var bounds := Rect2i(Vector2i.ZERO, region.size)
	while not fill.is_empty():
		var pixel: Vector2i = fill.pop_back()
		if not bounds.has_point(pixel):
			continue
		var color := image.get_pixelv(pixel)
		if color.a == 0 or color.r > 0.37 or color.g > 0.28 or color.b > 0.51:
			continue
		image.set_pixelv(pixel, Color.TRANSPARENT)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			fill.append(pixel + offset)
	return ImageTexture.create_from_image(image)
