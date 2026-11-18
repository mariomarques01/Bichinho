extends Node3D

const FEEDING_BACKDROP = preload("res://assets/textures/feeding/quarto.jpg")
const Geo = preload("res://scripts/core/geometry.gd")

@onready var camera: Camera3D = $Camera
@onready var key: DirectionalLight3D = $Sun
@onready var world: WorldEnvironment = $Environment
var sky: StandardMaterial3D
var lamp: StandardMaterial3D
var night := false
var backdrop: CanvasLayer

func _ready() -> void:
	camera.look_at(Vector3(0, 1.54, -0.38))
	get_viewport().size_changed.connect(_frame_camera)
	_frame_camera()
	_build_room()
	backdrop = CanvasLayer.new()
	backdrop.layer = -1
	add_child(backdrop)
	var scenery := TextureRect.new()
	scenery.texture = FEEDING_BACKDROP
	scenery.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode = TextureRect.STRETCH_SCALE
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(scenery)
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.hide()

func set_feeding(enabled: bool) -> void:
	backdrop.visible = enabled
	world.environment.background_mode = Environment.BG_CANVAS if enabled else Environment.BG_CLEAR_COLOR
	world.environment.background_canvas_max_layer = -1
	camera.cull_mask = 0 if enabled else 1048575

func _frame_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	camera.size = maxf(6.8, 3.7 * size.y / size.x)

func toggle_lamp() -> bool:
	night = not night
	key.light_color = Color("#abafff") if night else Color("#ffdfb4")
	key.light_energy = 0.48 if night else 1.1
	world.environment.ambient_light_color = Color("#8178c3") if night else Color("#e5cefa")
	sky.albedo_color = Color("#424883") if night else Color("#7dc8e8")
	sky.emission = sky.albedo_color
	lamp.emission_energy_multiplier = 1.25 if night else 0.38
	$LampLight.light_energy = 1.15 if night else 0.25
	return night

func _build_room() -> void:
	var wall := Geo.material(Color("#9a709f"))
	var trim := Geo.material(Color("#c08dab"))
	var dark := Geo.material(Color("#805065"))
	var wood := Geo.material(Color("#ce8e65"))
	var cream := Geo.material(Color("#fff0d1"))
	var violet := Geo.material(Color("#a786da"))
	var rug := Geo.material(Color("#7555ad"))
	var blush := Geo.material(Color("#e8a7c1"))
	var brass := Geo.material(Color("#efb970"))
	Geo.box(self, Vector3(0, 3.1, -3.52), Vector3(12, 6.4, 0.23), wall)
	for i in range(-8, 9):
		Geo.box(self, Vector3(i * 0.62, 3.1, -3.39), Vector3(0.023, 6.4, 0.026), trim)
	Geo.box(self, Vector3(0, 0.16, -3.32), Vector3(12, 0.26, 0.15), dark)
	var floors: Array[StandardMaterial3D] = []
	for color: String in ["#bf886e", "#d89974", "#c78b66", "#d49b78"]:
		floors.append(Geo.material(Color(color)))
	for row in range(31):
		for column in range(4):
			var x := (column - 1.5) * 3.15 + (0.56 if row % 2 == 0 else -0.56)
			Geo.box(self, Vector3(x, -0.073, -3.36 + row * 0.46),
				Vector3(3.14, 0.14, 0.451), floors[(row * 3 + column) % floors.size()])
	Geo.disc(self, Vector3(0, 0.02, 0.28), 1.69, 0.05, rug)
	Geo.disc(self, Vector3(0, 0.044, 0.28), 1.53, 0.027, blush)
	Geo.disc(self, Vector3(0, 0.057, 0.28), 1.42, 0.025, violet)
	var shadow := Geo.material(Color("#8669b6"))
	Geo.orb(self, Vector3(0, 0.074, 0.31), Vector3(0.78, 0.007, 0.53), shadow)
	_window(wood, brass, cream)
	_shelf(dark, wood)
	_bed(wood, cream, violet, blush)
	_plant(Vector3(-1.83, 0, -0.35), 1.18, blush)
	_plant(Vector3(1.75, 0, 0.73), 0.76, cream)
	_lamp(brass)

func _window(wood: Material, brass: Material, cream: Material) -> void:
	var center := Vector3(0.37, 3.14, -3.24)
	var window := Geo.pivot(self, "Janela", center)
	window.rotation_degrees.x = 90
	Geo.disc(window, Vector3.ZERO, 1.07, 0.18, wood)
	sky = Geo.material(Color("#7dc8e8"), 0.28)
	Geo.disc(window, Vector3(0, 0.096, 0), 0.92, 0.032, sky)
	var cloud := Geo.material(Color("#cff2f1"), 0.20)
	Geo.orb(window, Vector3(-0.27, 0.121, -0.36), Vector3(0.28, 0.016, 0.082), cloud)
	Geo.orb(window, Vector3(-0.10, 0.12, -0.42), Vector3(0.24, 0.016, 0.087), cloud)
	Geo.disc(window, Vector3(0.42, 0.12, -0.42), 0.155, 0.019, brass)
	Geo.box(window, Vector3(0, 0.125, 0), Vector3(1.82, 0.112, 0.071), wood)
	Geo.box(window, Vector3(0, 0.125, 0), Vector3(0.074, 0.112, 1.82), wood)
	Geo.box(self, center + Vector3(0, -1.015, 0.11), Vector3(2.21, 0.115, 0.38), wood)
	var string_light := Geo.material(Color("#ffe2aa"), 0.8)
	for i in range(9):
		var x := -2.20 + 0.49 * i
		var y := 4.03 + x * x * 0.122
		Geo.orb(self, Vector3(x, y, -2.99), Vector3.ONE * 0.059, string_light)
		if i < 8:
			var next_x := x + 0.49
			Geo.link(self, Vector3(x, y, -3.0), Vector3(next_x, 4.03 + next_x * next_x * 0.122, -3.0), 0.014, cream)

func _shelf(dark: Material, wood: Material) -> void:
	var shelf := Geo.pivot(self, "Estante", Vector3(-1.64, 0, -2.91))
	Geo.box(shelf, Vector3(0, 1.06, -0.15), Vector3(1.09, 2.1, 0.12), dark)
	for side: float in [-1.0, 1.0]:
		Geo.box(shelf, Vector3(side * 0.52, 1.06, 0.06), Vector3(0.12, 2.1, 0.5), wood)
	for level in range(4):
		Geo.box(shelf, Vector3(0, 0.12 + 0.64 * level, 0.06), Vector3(1.14, 0.11, 0.53), wood)
	var colors := [Color("#efd591"), Color("#6ea59c"), Color("#b77baa"), Color("#8288c4")]
	for i in range(8):
		var book := Geo.box(shelf, Vector3(-0.36 + (i % 4) * 0.175, 0.98 + floori(i / 4.0) * 0.64, 0.14),
			Vector3(0.134, 0.30 + (i % 3) * 0.055, 0.26), Geo.material(colors[i % 4]))
		book.rotation_degrees.z = 8 if i % 4 == 3 else 0
	_plant(Vector3(-1.57, 2.1, -2.81), 0.55, wood)

func _bed(wood: Material, cream: Material, violet: Material, blush: Material) -> void:
	var bed := Geo.pivot(self, "Cama", Vector3(1.31, 0, -2.08))
	bed.rotation_degrees.y = -18
	Geo.orb(bed, Vector3(0, 0.27, 0), Vector3(0.87, 0.22, 0.77), wood)
	Geo.orb(bed, Vector3(0, 0.43, 0.02), Vector3(0.80, 0.21, 0.71), cream)
	Geo.orb(bed, Vector3(0, 0.59, -0.49), Vector3(0.81, 0.50, 0.25), violet)
	Geo.orb(bed, Vector3(0, 0.60, -0.24), Vector3(0.46, 0.18, 0.25), blush)
	Geo.orb(bed, Vector3(0, 0.51, 0.26), Vector3(0.72, 0.17, 0.46), violet)

func _plant(at: Vector3, size: float, pot: Material) -> void:
	var plant := Geo.pivot(self, "Planta", at)
	plant.scale = Vector3.ONE * size
	Geo.disc(plant, Vector3(0, 0.18, 0), 0.19, 0.36, pot, 0.245)
	Geo.disc(plant, Vector3(0, 0.355, 0), 0.257, 0.09, pot)
	var leaf := Geo.material(Color("#588d78"))
	var fresh := Geo.material(Color("#a4bd79"))
	for i in range(6):
		var angle := TAU * i / 6.0
		var stem := Geo.pivot(plant, "Folha", Vector3(0, 0.34, 0))
		stem.rotation.y = angle
		Geo.orb(stem, Vector3(0.19, 0.28 + 0.05 * (i % 3), 0),
			Vector3(0.12, 0.29, 0.07), leaf if i % 2 == 0 else fresh).rotation_degrees.z = -34

func _lamp(brass: Material) -> void:
	var stem := Geo.pivot(self, "Luminaria", Vector3(1.66, 0, -2.76))
	lamp = Geo.material(Color("#ffcd87"), 0.38)
	Geo.disc(stem, Vector3(0, 0.08, 0), 0.24, 0.13, brass)
	Geo.disc(stem, Vector3(0, 1.01, 0), 0.047, 1.9, brass)
	Geo.disc(stem, Vector3(0, 1.99, 0), 0.36, 0.43, lamp, 0.185)
	Geo.orb(stem, Vector3(0, 2.24, 0), Vector3.ONE * 0.061, brass)
