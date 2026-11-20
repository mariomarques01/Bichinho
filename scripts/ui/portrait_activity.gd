extends Control

const Care = preload("res://scripts/needs/care.gd")
const DESIGN := Vector2(720, 1280)
const STAT_X := [83, 254, 426, 596]
const STAT_NAMES := ["Fome", "Higiene", "Energia", "Felicidade"]

var hud: CanvasLayer
var care: Care
var portrait: TextureRect
var xp: ProgressBar
var coin_icon: TextureRect
var coins: Label
var level: Label
var readings: Array[Label] = []
var meters: Array[ProgressBar] = []

func _setup_portrait(owner_hud: CanvasLayer, profile: Care, art: Texture2D) -> void:
	hud = owner_hud
	care = profile
	mouse_filter = MOUSE_FILTER_IGNORE
	size = DESIGN
	theme = hud.safe.theme
	portrait = _texture(self, art, Rect2(Vector2.ZERO, DESIGN))
	_build_profile()
	get_parent().resized.connect(_frame)
	_frame()

func _frame() -> void:
	scale = get_parent().size / DESIGN

func _build_navigation(current: int, menu_top: float) -> void:
	var captions := ["Alimentar", "Higienizar", "Descansar", "Fazer carinho", "Brincar"]
	for index in captions.size():
		if index != current:
			_hit(captions[index], Rect2(17 + 137 * index, menu_top, 135, 148)).pressed.connect(hud._open.bind(index))
	_hit("Quarto", Rect2(281, 1089, 150, 167)).pressed.connect(hud._open.bind(current))
	_hit("Inventário", Rect2(146, 1110, 131, 124)).pressed.connect(hud._open.bind(0))
	_hit("Loja", Rect2(555, 1110, 142, 124)).pressed.connect(_open_store)
	_hit("Loja de alimentos", Rect2(465, 10, 45, 49)).pressed.connect(_open_store)

func _build_profile() -> void:
	var deep := Color("#171531")
	level = _value(Rect2(109, 42, 130, 24), 18, deep)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coin_icon = _texture(self, hud.feeding.coin_icon.texture, Rect2(340, 15, 40, 40))
	coins = _value(Rect2(383, 20, 78, 34), 24, deep)
	_value(Rect2(584, 20, 68, 34), 24, deep).text = "0"
	xp = _bar(Rect2(113, 68, 184, 15), Color("#c541ea"), Color("#14465a"))
	for index in STAT_X.size():
		var x: int = STAT_X[index]
		readings.append(_value(Rect2(x + 3, 137, 90, 25), 19, Color("#251c39")))
		meters.append(_bar(Rect2(x - 2, 162, 94, 17), Color("#95e825"), Color("#153d2c")))

func refresh() -> void:
	for index in STAT_NAMES.size():
		var value: float = care.needs[STAT_NAMES[index]]
		readings[index].text = "%d%%" % roundi(value)

func _open_store() -> void:
	hud._open(0)
	hud.feeding.shopping = true
	hud.feeding.refresh()
	hud.feeding.message.text = "Loja · toque em um alimento para comprar por 5 moedas."

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

func _cutout(atlas: Texture2D, region: Rect2i) -> ImageTexture:
	var image := atlas.get_image().get_region(region)
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
