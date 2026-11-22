extends "res://scripts/ui/portrait_activity.gd"
const PoseView = preload("res://scripts/pet/evolin_poses.gd")
const PoseScene = preload("res://scenes/pet/evolin_poses.tscn")

const Blink = preload("res://scripts/pet/blink.gd")
const MOTION = preload("res://scripts/ui/bath_motion.gdshader")
const REFERENCE = preload("res://assets/textures/bath/banho.jpg")
const ATLAS = preload("res://assets/textures/bath/atlas.jpg")
const AREA := Rect2(125, 319, 473, 419)
const TOOLS := ["Esponja", "Sabonete", "Xampu", "Toalha"]
const TILE_RECTS := [
	Rect2(107, 796, 118, 101), Rect2(238, 796, 116, 101),
	Rect2(368, 796, 116, 101), Rect2(496, 796, 116, 101),
]
const TOOL_SPRITES := [
	Rect2i(860, 595, 101, 84), Rect2i(966, 598, 100, 81),
	Rect2i(1077, 591, 79, 89), Rect2i(1162, 593, 99, 85),
]
const BUBBLE := Rect2i(1074, 411, 42, 44)
const FOAM := Rect2i(848, 407, 121, 70)

var poses: PoseView
var movement := ShaderMaterial.new()
var reaction: Tween
var idle_clock := 0.0
var assets: Array[Texture2D] = []
var bubble_art: Texture2D
var foam_art: Texture2D
var selected := 0
var selected_outline: Panel
var inactive_sponge: Panel
var warning: Label
var warning_timer: Timer
var progress := 0
var dragging := false
var drag_origin := Vector2.ZERO
var last_sample := Vector2.ZERO
var ghost: TextureRect
var effects: Control

func setup(owner_hud: CanvasLayer, profile: Care) -> void:
	_setup_portrait(owner_hud, profile, REFERENCE)
	movement.shader = MOTION
	movement.set_shader_parameter("atlas_art", ATLAS)
	portrait.material = movement
	_texture(self, preload("res://assets/textures/bath/stage_patch.png"), Rect2(126, 298, 371, 283))
	var frame := Control.new()
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.position = Vector2(117, 218)
	frame.size = Vector2(460, 395)
	poses = PoseScene.instantiate()
	frame.add_child(poses)
	poses.setup(care)
	var foam_edge := AtlasTexture.new()
	foam_edge.atlas = REFERENCE
	foam_edge.region = Rect2(95, 578, 515, 100)
	_texture(self, foam_edge, foam_edge.region)

	for region: Rect2i in TOOL_SPRITES:
		assets.append(_cutout(ATLAS, region))
	bubble_art = _cutout(ATLAS, BUBBLE)
	foam_art = _cutout(ATLAS, FOAM)
	_build_tools()
	_build_navigation(1, 951)
	effects = Control.new()
	effects.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(effects)
	warning = _text(self, "", Rect2(106, 909, 508, 34), 20)
	warning.add_theme_constant_override("outline_size", 7)
	warning_timer = Timer.new()
	warning_timer.one_shot = true
	warning_timer.timeout.connect(warning.hide)
	add_child(warning_timer)
	close()

func _process(delta: float) -> void:
	if not visible:
		return
	idle_clock += delta
	movement.set_shader_parameter("opening", 1.0 - Blink.closure(idle_clock))

func _build_tools() -> void:
	inactive_sponge = Panel.new()
	inactive_sponge.mouse_filter = MOUSE_FILTER_IGNORE
	inactive_sponge.position = TILE_RECTS[0].position
	inactive_sponge.size = TILE_RECTS[0].size
	inactive_sponge.add_theme_stylebox_override("panel", _box(Color("#382e72"), Color("#a29cd9"), 21, 3))
	add_child(inactive_sponge)
	_texture(inactive_sponge, assets[0], Rect2(13, 8, 92, 84))
	selected_outline = Panel.new()
	selected_outline.mouse_filter = MOUSE_FILTER_IGNORE
	selected_outline.add_theme_stylebox_override("panel", _box(Color(0.44, 0.85, 0.18, 0.1), Color("#ecff82"), 23, 4))
	add_child(selected_outline)
	for index in TILE_RECTS.size():
		var tile := _hit(TOOLS[index], TILE_RECTS[index])
		tile.pressed.connect(func() -> void: _select(index, true))
		tile.gui_input.connect(_tool_input.bind(index))
	_hit("Ferramenta anterior", Rect2(52, 795, 50, 102)).pressed.connect(func() -> void: _select(posmod(selected - 1, TOOLS.size()), true))
	_hit("Próxima ferramenta", Rect2(618, 795, 50, 102)).pressed.connect(func() -> void: _select(posmod(selected + 1, TOOLS.size()), true))

func open() -> void:
	progress = 0
	show()
	warning.hide()
	_select(0)
	refresh()

func close() -> void:
	hide()
	if reaction and reaction.is_running():
		reaction.kill()
	movement.set_shader_parameter("response", 0.0)
	_end_drag()
	warning.hide()
	for effect in effects.get_children():
		effect.queue_free()

func _select(index: int, announce := false) -> void:
	selected = index
	inactive_sponge.visible = index != 0
	selected_outline.visible = index != 0
	selected_outline.position = TILE_RECTS[index].position
	selected_outline.size = TILE_RECTS[index].size
	if announce:
		hud.play_sound(&"toque")

func _tool_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select(index)
		_begin_drag(_local(get_viewport().get_mouse_position()))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _local(event.position)
		if event.pressed and AREA.has_point(at) and not dragging:
			_begin_drag(at)
		elif not event.pressed and dragging:
			_end_drag()
	if event is InputEventMouseMotion and dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var at := _local(event.position)
		if not is_instance_valid(ghost) and at.distance_to(drag_origin) >= 14:
			ghost = _texture(effects, assets[selected], Rect2(at - Vector2(45, 40), Vector2(90, 80)))
			ghost.z_index = 3
		if is_instance_valid(ghost):
			ghost.position = at - ghost.size * 0.5
			if AREA.has_point(at) and at.distance_to(last_sample) >= 23.0:
				last_sample = at
				scrub(at)
			get_viewport().set_input_as_handled()

func _local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

func _begin_drag(at: Vector2) -> void:
	dragging = true
	drag_origin = at
	last_sample = at

func _end_drag() -> void:
	dragging = false
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_drag()

func scrub(at: Vector2) -> void:
	if not visible or not AREA.has_point(at):
		return
	if care.rest_end > 0:
		_notice("Evolin está descansando.")
		return
	if selected == 3:
		for effect in effects.get_children():
			if effect != ghost:
				effect.queue_free()
		_splash(0.30)
		_notice("Toalha · espuma removida.")
		return
	if care.needs["Higiene"] >= 99.0:
		_notice("Evolin já está limpinho!")
		return
	progress += 1
	_splash(1.0 if progress == 10 else 0.60)
	hud.particles(effects, at, Color("#b7edff"), 5)
	_spawn(at)
	hud.play_sound(&"bolha")
	if progress == 10:
		progress = 0
		care.wash()
		hud.play_sound(&"recompensa")
		_notice("Banho completo! Evolin está limpinho.")
	else:
		_notice("Banho · %d%%" % (progress * 10))

func _splash(amount: float) -> void:
	if reaction and reaction.is_running():
		reaction.kill()
	movement.set_shader_parameter("response", amount)
	poses.pivot_offset = poses.size * Vector2(0.5, 0.94)
	poses.scale = Vector2(1.0 + 0.05 * amount, 1.0 - 0.08 * amount)
	reaction = create_tween()
	reaction.parallel().tween_property(poses, "scale", Vector2.ONE, 0.40)
	reaction.parallel().tween_property(movement, "shader_parameter/response", 0.0, 0.40).set_ease(Tween.EASE_OUT)

func _spawn(at: Vector2) -> void:
	var art := foam_art if selected == 1 else bubble_art
	var extent := Vector2(82, 47) if selected == 1 else Vector2(35, 37)
	var count := 2 if selected == 2 else 1
	for index in count:
		var drift := Vector2(randf_range(-42, 42), -randf_range(55, 95))
		var particle := _texture(effects, art, Rect2(at - extent * 0.5 + Vector2(24 * index, 0), extent))
		var float_up := particle.create_tween().set_parallel()
		float_up.tween_property(particle, "position", particle.position + drift, 0.69)
		float_up.tween_property(particle, "modulate:a", 0.0, 0.40).set_delay(0.29)
		float_up.chain().tween_callback(particle.queue_free)

func _notice(text: String) -> void:
	warning.text = text
	warning.show()
	warning_timer.start(1.45)
