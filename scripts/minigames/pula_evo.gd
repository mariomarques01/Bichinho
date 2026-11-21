extends Control

signal finished(height: int, score: int, reward: int)

const BOARD := Vector2(640, 500)
const START := Vector2(320, 440)
const PLATFORM_WIDTH := 122.0
const STEP := 96.0
const BOUNCE := -550.0
const GRAVITY := 1100.0

var avatar: Texture2D
var player := START
var speed_y := BOUNCE
var direction := 0
class Platform:
	var position: Vector2
	var origin_x: float
	var moving := false
	var fragile := false
	var coin := false
	var spring := false

	func _init(at: Vector2) -> void:
		position = at
		origin_x = at.x

var rng := RandomNumberGenerator.new()
var platforms: Array[Platform] = []
var last_platform: Vector2
var elapsed := 0.0
var collected := 0
var steered := false
var camera_y := 0.0
var height := 0
var running := true

func _ready() -> void:
	custom_minimum_size.y = BOARD.y
	clip_contents = true
	last_platform = START - Vector2(PLATFORM_WIDTH / 2.0, STEP)
	platforms.append(Platform.new(last_platform))
	_extend_platforms()

func _extend_platforms() -> void:
	while last_platform.y > camera_y - 125.0:
		var meters := (START.y - last_platform.y) / 10.0
		var difficulty := clampf((meters - STEP / 10.0) / 300.0, 0.0, 1.0)
		var reach := lerpf(145.0, 260.0, difficulty)
		last_platform.x = clampf(last_platform.x + rng.randf_range(-reach, reach), 0, BOARD.x - PLATFORM_WIDTH)
		last_platform.y -= lerpf(STEP, 125.0, difficulty)
		var ledge := Platform.new(last_platform)
		var altitude := (START.y - last_platform.y) / 10.0
		ledge.moving = altitude >= 150.0 and rng.randf() < 0.20
		ledge.fragile = altitude >= 300.0 and rng.randf() < 0.15
		ledge.coin = rng.randi_range(1, 6) == 1
		ledge.spring = not ledge.fragile and rng.randf() < 0.05
		platforms.append(ledge)

static func payout(meters: int, seconds: float, active: bool) -> int:
	if seconds + 1e-9 < 8.0 or not active:
		return 0
	return clampi(ceili(meters / 40.0), 0, 6)

func _gui_input(event: InputEvent) -> void:
	# The primary touch is also mapped to a mouse button on mobile and Web.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		direction = _side(event.position.x) if event.pressed else 0
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		direction = _side(event.position.x)
		accept_event()

func _side(x: float) -> int:
	return -1 if x < size.x * 0.5 else 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		direction = 0

func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	steered = steered or direction != 0
	var old_y := player.y
	player.x = clampf(player.x + direction * 365.0 * delta, 22, BOARD.x - 22)
	speed_y += GRAVITY * delta
	player.y += speed_y * delta
	last_platform.y -= 12.0 * delta
	var landed: Platform
	for ledge in platforms:
		var old_top := ledge.position.y
		ledge.position.y -= 12.0 * delta
		if ledge.moving:
			ledge.position.x = clampf(ledge.origin_x + sin(elapsed * 1.7 + ledge.origin_x) * 45.0, 0, BOARD.x - PLATFORM_WIDTH)
		var coin_at := ledge.position + Vector2(PLATFORM_WIDTH * 0.5, -37)
		if ledge.coin and (player - Vector2(0, 30)).distance_to(coin_at) < 32.0:
			ledge.coin = false
			collected += 1
		if landed or speed_y <= 0 or old_y > old_top or player.y < ledge.position.y:
			continue
		if player.x >= ledge.position.x - 10 and player.x <= ledge.position.x + PLATFORM_WIDTH + 10:
			landed = ledge
			if not ledge.fragile:
				player.y = ledge.position.y
				speed_y = BOUNCE * (1.6 if ledge.spring else 1.0)
	if landed:
		platforms.erase(landed)
	height = maxi(height, floori((START.y - player.y) / 10.0))
	camera_y = minf(camera_y, player.y - BOARD.y * 0.46)
	while not platforms.is_empty() and platforms.front().position.y > camera_y + BOARD.y:
		platforms.pop_front()
	_extend_platforms()
	queue_redraw()
	if player.y > camera_y + BOARD.y + 34:
		running = false
		set_physics_process(false)
		finished.emit(height, height + collected, payout(height, elapsed, steered))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / BOARD)
	draw_rect(Rect2(Vector2.ZERO, BOARD), Color("#252039"))
	for ledge in platforms:
		var at := ledge.position - Vector2(0, camera_y)
		draw_rect(Rect2(at, Vector2(PLATFORM_WIDTH, 13)), Color("#537b86"))
		draw_rect(Rect2(at, Vector2(PLATFORM_WIDTH, 5)), Color("#f49783") if ledge.fragile else (Color("#81baff") if ledge.moving else Color("#99efd4")))
		var middle := at + Vector2(PLATFORM_WIDTH * 0.5, 0)
		if ledge.coin:
			draw_circle(middle - Vector2(0, 37), 8, Color.GOLD)
		if ledge.spring:
			draw_polyline(PackedVector2Array([middle, middle + Vector2(8, -4), middle + Vector2(-8, -8), middle + Vector2(8, -12)]), Color.YELLOW_GREEN, 3)
	var feet := player - Vector2(0, camera_y)
	if avatar:
		draw_texture_rect(avatar, Rect2(feet - Vector2(28, 62), Vector2(56, 62)), false)
	draw_string(ThemeDB.fallback_font, Vector2(18, 34), "%d m  ·  %d pontos" % [height, height + collected], HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
