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
var care := Care.new()
var sounds := Sounds.new()
var was_sleeping := false
var next_dream := 0.0
var pointer_at := Vector2.ZERO
var last_sample := Vector2.ZERO
var sample_pending := false
var ready_at := 0

func _ready() -> void:
	add_child(care)
	add_child(sounds)
	hud.sound_requested.connect(sounds.play)
	hud.bind_care(care)
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
				hud.spark(room.camera.unproject_position(evolin.heart_origin.global_position))
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
	)
	hud.lamp_requested.connect(func() -> void:
		if care.rest_end == 0:
			hud.set_night(room.toggle_lamp())
	)

func _activity_changed(index: int) -> void:
	evolin.set_activity(index)
	room.set_feeding(index == 0)
	if index in [-1, 1]:
		room.camera.cull_mask = 0
	sample_pending = false

func _food_drop(food: String, at: Vector2) -> void:
	if hud.menu.mode == 0 and hud.feeding.accepts_drop(at):
		hud.feeding.serve(food, at)

func _refresh_rest() -> void:
	var sleeping := care.rest_end > 0
	evolin.sleeping = sleeping
	hud.home.sleeping = sleeping
	hud.lamp_button.disabled = sleeping
	if sleeping != was_sleeping:
		next_dream = 0.0
		if room.night != sleeping:
			hud.set_night(room.toggle_lamp())
		was_sleeping = sleeping

func _process(delta: float) -> void:
	if not evolin.sleeping or hud.menu.mode not in [-1, 2]:
		return
	next_dream -= delta
	if next_dream > 0.0:
		return
	next_dream = 1.26
	var at := hud.home.heart_point() if hud.menu.mode == -1 else room.camera.unproject_position(evolin.heart_origin.global_position - Vector3(0, 0.35, 0))
	hud.dream(at)

func _unhandled_input(event: InputEvent) -> void:
	if hud.menu.mode in [0, 1]:
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
	if hud.menu.mode == -1:
		if hud.home.hit_pet(pointer_at):
			_pet()
		return
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
	if hud.menu.mode == -1:
		hud.home.react()
		hud.heart(hud.home.heart_point())
	else:
		hud.heart(room.camera.unproject_position(evolin.heart_origin.global_position))
