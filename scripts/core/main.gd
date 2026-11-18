extends Node3D

const Room = preload("res://scripts/core/room.gd")
const Evolin = preload("res://scripts/pet/evolin.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const PET_LAYER := 2

@onready var room: Room = $Room
@onready var evolin: Evolin = $Evolin
@onready var hud: HUD = $HUD
var pointer_at := Vector2.ZERO
var last_sample := Vector2.ZERO
var sample_pending := false
var ready_at := 0

func _ready() -> void:
	evolin.reacted.connect(hud.show_reaction)
	hud.pet_requested.connect(_pet)
	hud.jump_requested.connect(evolin.jump)
	hud.lamp_requested.connect(func() -> void: hud.set_night(room.toggle_lamp()))

func _unhandled_input(event: InputEvent) -> void:
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
	if now < ready_at:
		return
	ready_at = now + 410
	evolin.pet()
	hud.heart(room.camera.unproject_position(evolin.heart_origin.global_position))
