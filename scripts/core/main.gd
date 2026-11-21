extends Node3D

const Room = preload("res://scripts/core/room.gd")
const Evolin = preload("res://scripts/pet/evolin.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const Care = preload("res://scripts/needs/care.gd")
const Sounds = preload("res://scripts/core/sounds.gd")
const PET_LAYER := 2

@onready var room: Room = $Room
@onready var evolin: Evolin = $Evolin
@onready var hud: HUD = $HUD
const WardrobeArt = preload("res://scripts/inventory/wardrobe_art.gd")
var face_accessories: WardrobeArt
var care := Care.new()
var sounds := Sounds.new()
var was_sleeping := false
var next_dream := 0.0
var pointer_at := Vector2.ZERO
var last_sample := Vector2.ZERO
var sample_pending := false
var ready_at := 0
var read_motion_sensor := OS.get_name() in ["Android", "iOS"] and Input.has_method("get_accelerometer")
var last_acceleration := Vector3.ZERO
var shake_ready_at := 0

func _ready() -> void:
	add_child(care)
	add_child(sounds)
	hud.sound_requested.connect(sounds.play)
	hud.bind_care(care)
	var canvas: Control = hud.get_node("Interface")
	face_accessories = WardrobeArt.attach(canvas, care.wardrobe, Vector2.LEFT, Vector2.RIGHT)
	canvas.move_child(face_accessories, 0)
	face_accessories.hide()
	hud.home.evolin = evolin
	hud.feeding.evolin = evolin
	hud.activity_changed.connect(_activity_changed)
	_activity_changed(-1)
	hud.food_drop.connect(_food_drop)
	care.changed.connect(_refresh_rest)
	_refresh_rest()
	evolin.reacted.connect(hud.show_reaction)
	hud.pet_requested.connect(_pet)
	hud.ingredient_selected.connect(func() -> void:
		if not evolin.sleeping:
			evolin.inspect_ingredient()
	)
	hud.mixture_ready.connect(func() -> void:
		if not evolin.sleeping:
			evolin.discover()
			hud.spark(room.camera.unproject_position(evolin.heart_origin.global_position))
	)
	hud.play_pair.connect(func(final_pair: bool) -> void:
		if not evolin.sleeping:
			evolin.celebrate_pair(final_pair)
			if final_pair:
				hud.spark(hud.home.heart_point() if hud.home.visible else room.camera.unproject_position(evolin.heart_origin.global_position))
	)
	hud.food_eaten.connect(func() -> void:
		sounds.play(&"mordida")
		evolin.eat()
	)
	hud.jump_requested.connect(func() -> void:
		if care.rest_end == 0:
			if not evolin.reaction or not evolin.reaction.is_running():
				sounds.play(&"pulo")
			evolin.jump()
			if hud.home.visible:
				hud.home.jump()
	)
	hud.lamp_requested.connect(func() -> void:
		if care.rest_end == 0:
			hud.set_night(room.toggle_lamp())
	)

func _activity_changed(index: int) -> void:
	hud.home.release_grab()
	last_acceleration = Vector3.ZERO
	evolin.set_activity(index)
	room.set_feeding(index == 0)
	if index in [-1, 1, 2, 4]:
		room.camera.cull_mask = 0
	sample_pending = false

func _food_drop(food: String, at: Vector2) -> void:
	if hud.menu.mode == 0 and hud.feeding.accepts_drop(at):
		hud.feeding.serve(food, at)

func _refresh_rest() -> void:
	evolin.set_mood(care.needs, care.sick)
	var sleeping := care.rest_end > 0
	evolin.sleeping = sleeping
	hud.home.sleeping = sleeping
	hud.lamp_button.disabled = sleeping
	if sleeping:
		hud.home.release_grab()
		last_acceleration = Vector3.ZERO
	if sleeping != was_sleeping:
		next_dream = 0.0
		if room.night != sleeping:
			hud.set_night(room.toggle_lamp())
		was_sleeping = sleeping

func _process(delta: float) -> void:
	if hud.menu.mode == 5 and (care.wardrobe.equipped.has(care.wardrobe.HAT) or care.wardrobe.equipped.has(care.wardrobe.GLASSES)):
		var face := evolin.face
		var eye := Vector3(0.35, 0.478 + 0.248 * 0.35, 0.142)
		var first := room.camera.unproject_position(face.to_global(eye))
		eye.z = -eye.z
		var second := room.camera.unproject_position(face.to_global(eye))
		face_accessories.left_eye = (first if first.x < second.x else second) / face_accessories.size
		face_accessories.right_eye = (second if first.x < second.x else first) / face_accessories.size
		face_accessories.show()
		face_accessories.queue_redraw()
	else:
		face_accessories.hide()
	if not hud.home.visible:
		return
	if not evolin.sleeping:
		if read_motion_sensor:
			_sample_acceleration(Input.get_accelerometer())
		return
	next_dream -= delta
	if next_dream > 0.0:
		return
	next_dream = 1.26
	hud.dream(hud.home.heart_point())

func _sample_acceleration(value: Vector3) -> void:
	if not value.is_finite() or value.is_zero_approx():
		last_acceleration = Vector3.ZERO
		return
	if not last_acceleration.is_zero_approx() and value.distance_to(last_acceleration) > 13.0:
		_shake()
	last_acceleration = value

func _shake() -> void:
	var now := Time.get_ticks_msec()
	if now < shake_ready_at or hud.home.holding or evolin.sleeping or not hud.home.visible:
		return
	shake_ready_at = now + 1000
	hud.home.shake()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and is_instance_valid(hud.home):
		hud.home.release_grab()
		last_acceleration = Vector3.ZERO

func _input(event: InputEvent) -> void:
	if not is_instance_valid(hud) or not is_instance_valid(hud.home) or not hud.home.holding:
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		hud.home.drag_to(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not event.canceled:
			hud.home.drag_to(event.position)
			_pet()
		hud.home.release_grab()
	else:
		return
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if hud.wardrobe_screen.visible:
		return
	if hud.home.visible:
		if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
			_shake()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not evolin.sleeping and hud.home.hit_pet(event.position):
				hud.home.grab(event.position)
				get_viewport().set_input_as_handled()
		return
	if hud.menu.mode in [0, 1, 2]:
		return
	# Godot maps the primary Android touch to mouse events for both UI and the room.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_sample(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if event.position.distance_squared_to(last_sample) >= 34.0 * 34.0:
			_sample(event.position)

func _sample(at: Vector2) -> void:
	pointer_at = at
	last_sample = at
	sample_pending = true

func _physics_process(_delta: float) -> void:
	if not sample_pending:
		return
	sample_pending = false
	var camera: Camera3D = room.camera
	var origin := camera.project_ray_origin(pointer_at)
	var end := origin + camera.project_ray_normal(pointer_at) * 20.0
	var ray := PhysicsRayQueryParameters3D.create(origin, end, PET_LAYER)
	ray.collide_with_bodies = false
	ray.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		_pet()

func _pet() -> void:
	var now := Time.get_ticks_msec()
	if now < ready_at or care.rest_end > 0:
		return
	ready_at = now + 410
	sounds.play(&"carinho")
	care.affection()
	evolin.pet()
	if hud.home.visible:
		if not hud.home.dragging:
			hud.home.react()
		hud.heart(hud.home.heart_point())
	else:
		hud.heart(room.camera.unproject_position(evolin.heart_origin.global_position))
