extends Control

signal finished(height: int)

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
var platforms: Array[Vector2] = []
var camera_y := 0.0
var height := 0
var running := true

func _ready() -> void:
	custom_minimum_size.y = BOARD.y
	clip_contents = true
	platforms.append(START - Vector2(PLATFORM_WIDTH / 2.0, STEP))
	_extend_platforms()

func _extend_platforms() -> void:
	while platforms.back().y > camera_y - STEP:
		var previous: Vector2 = platforms.back()
		var x := clampf(previous.x + randf_range(-145.0, 145.0), 0, BOARD.x - PLATFORM_WIDTH)
		platforms.append(Vector2(x, previous.y - STEP))

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
	var old_y := player.y
	player.x = clampf(player.x + direction * 365.0 * delta, 22, BOARD.x - 22)
	speed_y += GRAVITY * delta
	player.y += speed_y * delta
	for i in platforms.size():
		var ledge := platforms[i]
		platforms[i].y -= 12.0 * delta
		if speed_y > 0 and old_y <= ledge.y and player.y >= platforms[i].y:
			if player.x >= ledge.x - 10 and player.x <= ledge.x + PLATFORM_WIDTH + 10:
				player.y = platforms[i].y
				speed_y = BOUNCE
				platforms.remove_at(i)
				break
	height = maxi(height, floori((START.y - player.y) / 10.0))
	camera_y = minf(camera_y, player.y - BOARD.y * 0.46)
	while platforms.size() > 1 and platforms.front().y > camera_y + BOARD.y:
		platforms.pop_front()
	_extend_platforms()
	queue_redraw()
	if player.y > camera_y + BOARD.y + 34:
		running = false
		set_physics_process(false)
		finished.emit(height)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / BOARD)
	draw_rect(Rect2(Vector2.ZERO, BOARD), Color("#252039"))
	for ledge in platforms:
		var at := ledge - Vector2(0, camera_y)
		draw_rect(Rect2(at, Vector2(PLATFORM_WIDTH, 13)), Color("#537b86"))
		draw_rect(Rect2(at, Vector2(PLATFORM_WIDTH, 5)), Color("#99efd4"))
	var feet := player - Vector2(0, camera_y)
	if avatar:
		draw_texture_rect(avatar, Rect2(feet - Vector2(28, 62), Vector2(56, 62)), false)
	draw_string(ThemeDB.fallback_font, Vector2(18, 34), "Altura: %d m" % height, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
