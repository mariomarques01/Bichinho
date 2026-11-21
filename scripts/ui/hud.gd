extends CanvasLayer

const WardrobeArt = preload("res://scripts/inventory/wardrobe_art.gd")
const Activities = preload("res://scripts/ui/activities.gd")
const Care = preload("res://scripts/needs/care.gd")

const Feeding = preload("res://scripts/ui/feeding.gd")
const Bath = preload("res://scripts/ui/bath.gd")
const Rest = preload("res://scripts/ui/rest.gd")
const Home = preload("res://scripts/ui/home.gd")

signal sound_requested(key: StringName)
signal play_pair(final_pair: bool)
signal ingredient_selected
signal mixture_ready
signal food_eaten
signal food_drop(food: String, at: Vector2)
signal activity_changed(index: int)
signal pet_requested
signal jump_requested
signal lamp_requested

@onready var safe: MarginContainer = $Interface/SafeArea
var wardrobe_screen := preload("res://scripts/ui/wardrobe_screen.gd").new()
var feeding: Feeding
var bath: Bath
var rest: Rest
var home: Home
var level_banner: PanelContainer
var sickness_icon: Label
var feedback: Label
var lamp_button: Button
var feedback_time: Timer
var activity: VBoxContainer
var activity_parent: Control
var room_games: VBoxContainer
var room_result: Label
var activity_card: PanelContainer
var menu := Activities.new()
var animation := preload("res://scripts/ui/hud_animation.gd").new()
var coin_icon: TextureRect
var profile: Label
var bars: Dictionary = {}
var values: Dictionary = {}
var tabs: Array[Button] = []

func bind_care(care: Node) -> void:
	menu.hud = self
	menu.care = care
	feeding = Feeding.new()
	$Interface.add_child(feeding)
	feeding.setup(self, care)
	coin_icon.texture = feeding.coin_icon.texture
	_update_safe_area()
	feeding.close()
	bath = Bath.new()
	$Interface.add_child(bath)
	bath.setup(self, care)
	rest = Rest.new()
	$Interface.add_child(rest)
	rest.setup(self, care)
	home = Home.new()
	$Interface.add_child(home)
	home.setup(self, care)
	room_games = VBoxContainer.new()
	room_games.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(room_games)
	room_games.position = Vector2(20, 925)
	room_games.size.x = 680
	room_games.minimum_size_changed.connect(func() -> void:
		room_games.size.y = room_games.get_combined_minimum_size().y
		room_games.position.y = 925 - room_games.size.y
	)
	room_result = _label(room_games, "", 26)
	room_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_result.add_theme_constant_override("outline_size", 6)
	room_result.hide()
	sickness_icon = _label($Interface, "✚ Doente", 32)
	sickness_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sickness_icon.add_theme_color_override("font_color", Color("#ffcbc8"))
	sickness_icon.add_theme_constant_override("outline_size", 6)
	sickness_icon.hide()
	WardrobeArt.attach(home.room_art, care.wardrobe)
	WardrobeArt.attach(home.character, care.wardrobe, Vector2(0.341,0.419), Vector2(0.652,0.419))
	WardrobeArt.attach(feeding.character, care.wardrobe, Vector2(0.486,0.419), Vector2(0.808,0.389))
	WardrobeArt.attach(bath.portrait, care.wardrobe, Vector2(300,468)/bath.DESIGN, Vector2(422,441)/bath.DESIGN)
	WardrobeArt.attach(rest.portrait, care.wardrobe, Vector2(273,508)/rest.DESIGN, Vector2(354,468)/rest.DESIGN)
	$Interface.add_child(wardrobe_screen)
	wardrobe_screen.setup(self, care)
	safe.hide()
	care.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var care := menu.care
	if sickness_icon.visible != care.sick:
		sickness_icon.visible = care.sick
		if menu.mode in [4, 5]:
			menu.enter(menu.mode)
	var previous_xp := int(animation.targets.get("xp", care.xp))
	var previous_coins := int(animation.targets.get("coins", care.coins))
	for key: String in bars:
		animation.update(self, key, care.needs[key], _draw_need.bind(key))
	animation.update(self, "xp", care.xp, _draw_profile)
	animation.update(self, "coins", care.coins, _draw_profile)
	var active: Control = safe
	for screen: Control in [home, feeding, bath, rest]:
		if screen.is_visible_in_tree():
			active = screen
			break
	var icon: Control = coin_icon if active == safe else active.coin_icon
	var anchor := icon.get_global_rect().get_center()
	var y := maxf(anchor.y + 100.0, 145.0)
	if care.xp > previous_xp:
		var level := Care.level_progress(care.xp).x
		if level > Care.level_progress(previous_xp).x:
			_show_level(level)
		_float_effect(Vector2(get_viewport().get_visible_rect().size.x * 0.24, y), "+%d XP" % (care.xp - previous_xp), Color("#ffb8ff"), 0.8, 36)
	if care.coins > previous_coins:
		animation.pop(icon)
		_float_effect(Vector2(anchor.x, y), "+%d moedas" % (care.coins - previous_coins), Color("#ffdf90"), 0.8, 36)
	feeding.refresh()
	bath.refresh()
	rest.refresh()
	home.refresh()

func _draw_need(key: String) -> void:
	var index := Home.STAT_KEYS.find(key)
	var value := float(animation.shown[key])
	for bar: ProgressBar in [bars[key], home.stat_bars[index], feeding.stats[key][1], bath.meters[index], rest.meters[index]]:
		bar.value = value
	values[key].text = "%s  %d%%" % [key, roundi(menu.care.needs[key])]

func _draw_profile() -> void:
	var shown_xp := float(animation.shown.get("xp", menu.care.xp))
	var xp := floori(shown_xp)
	var coins := roundi(animation.shown.get("coins", menu.care.coins))
	var state := Care.level_progress(xp)
	var level := "Nível %d" % state.x
	var progress := "%d/%d XP" % [state.y, state.z]
	profile.text = "%s  ·  %s  ·  %d moedas" % [level, progress, coins]
	feeding.profile.text = "%s   ·   %s" % [level, progress]
	home.xp_reading.text = progress
	for label: Label in [home.level, bath.level, rest.level]:
		label.text = level
	for bar: ProgressBar in [home.xp_bar, bath.xp, rest.xp]:
		bar.value = 100.0 * (state.y + shown_xp - xp) / state.z
	for label: Label in [home.coins, feeding.wallet, bath.coins, rest.coins]:
		label.text = str(coins)

func open_wardrobe() -> void:
	if menu.mode != -1:
		_open(menu.mode)
	home.release_grab()
	wardrobe_screen.message.text = ""
	wardrobe_screen.show()

func play_sound(key: StringName) -> void:
	sound_requested.emit(key)

func _open(index: int) -> void:
	play_sound(&"toque")
	var next := -1 if index == 3 or menu.mode == index else index
	var parent := room_games as Control if next == 4 else activity_parent
	if activity_card.get_parent() != parent:
		activity_card.reparent(parent, false)
		if parent == activity_parent:
			parent.move_child(activity_card, parent.get_child_count() - 2)
	activity_card.visible = next in [4, 5]
	room_games.visible = next == 4
	room_result.hide()
	menu.enter(next)
	safe.visible = next == 5
	home.visible = next in [-1, 4]
	if next == 0:
		feeding.open()
	else:
		feeding.close()
	if next == 1:
		bath.open()
	else:
		bath.close()
	if next == 2:
		rest.open()
	else:
		rest.close()
	activity_changed.emit(next)
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == next)
	feedback_time.stop()
	feedback.text = "Toque ou deslize sobre o Evolin" if next < 0 else ""
	if index == 3:
		pet_requested.emit()


func _ready() -> void:
	safe.theme = _theme()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	_build()

func _update_safe_area() -> void:
	var left := 44
	var right := 44
	var top := 48
	var bottom := 54
	if OS.has_feature("mobile"):
		var usable := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.window_get_size()
		if usable.has_area() and screen.x > 0 and screen.y > 0:
			var scale_factor := get_viewport().get_visible_rect().size / Vector2(screen)
			left += roundi(maxi(0, usable.position.x) * scale_factor.x)
			top += roundi(maxi(0, usable.position.y) * scale_factor.y)
			right += roundi(maxi(0, screen.x - usable.end.x) * scale_factor.x)
			bottom += roundi(maxi(0, screen.y - usable.end.y) * scale_factor.y)
	if is_instance_valid(feeding):
		var margins := {"left": left, "right": right, "top": top, "bottom": bottom}
		for edge: String in margins:
			feeding.add_theme_constant_override("margin_" + edge, margins[edge])
	safe.add_theme_constant_override("margin_left", left)
	safe.add_theme_constant_override("margin_right", right)
	safe.add_theme_constant_override("margin_top", top)
	safe.add_theme_constant_override("margin_bottom", bottom)

func _build() -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var title_card := _panel(header, Color("#36284e"))
	title_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.add_child(identity)
	_label(identity, "EVO  /  Evolin", 46).add_theme_color_override("font_color", Color("#91efce"))
	var account := HBoxContainer.new()
	identity.add_child(account)
	coin_icon = TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(36, 36)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	account.add_child(coin_icon)
	profile = _label(account, "", 32)
	lamp_button = _button(header, "Anoitecer", Color("#594678"))
	lamp_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	lamp_button.pressed.connect(func() -> void:
		play_sound(&"toque")
		lamp_requested.emit()
	)
	var needs_row := HBoxContainer.new()
	needs_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(needs_row)
	var need_colors := [Color("#ffb666"), Color("#65d6ff"), Color("#b396ff"), Color("#ff8fbd")]
	for key: String in ["Fome", "Higiene", "Energia", "Felicidade"]:
		var need_card := _panel(needs_row, Color("#39294fe8"), 12)
		need_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stat := VBoxContainer.new()
		stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		need_card.add_child(stat)
		values[key] = _label(stat, key, 29)
		bars[key] = meter(stat, need_colors[bars.size()])
	var free_space := Control.new()
	free_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	free_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(free_space)
	activity_parent = column
	activity_card = _panel(column, Color("#302143f5"))
	activity_card.hide()
	activity = VBoxContainer.new()
	activity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	activity_card.add_child(activity)
	var card := _panel(column, Color("#36284ef7"), 15)
	var controls := VBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(controls)
	feedback = _label(controls, "Toque ou deslize sobre o Evolin", 32)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := GridContainer.new()
	actions.columns = 3
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	controls.add_child(actions)
	for index in Activities.TITLES.size():
		var tab := _button(actions, Activities.TITLES[index], Color(Activities.COLORS[index]))
		tab.toggle_mode = true
		tab.pressed.connect(_open.bind(index))
		tabs.append(tab)
	feedback_time = Timer.new()
	feedback_time.one_shot = true
	feedback_time.timeout.connect(func() -> void: feedback.text = "Toque ou deslize sobre o Evolin" if menu.mode < 0 else "")
	feedback_time.timeout.connect(func() -> void: room_result.hide())
	add_child(feedback_time)

func request_food_drop(food: String, at: Vector2) -> void:
	food_drop.emit(food, at)

func show_reaction(message: String) -> void:
	if menu.mode == 4:
		room_result.text = message
		room_result.show()
	feedback.text = message
	feedback_time.start(2.0)

func set_night(night: bool) -> void:
	home.set_night(night)
	lamp_button.text = "Amanhecer" if night else "Anoitecer"

func heart(at: Vector2) -> void:
	_float_effect(at, "♥", Color("#ff9bcc"))

func dream(at: Vector2) -> void:
	_float_effect(at, "Z", Color("#a4dfff"))

func spark(at: Vector2) -> void:
	_float_effect(at, "✦", Color("#ffdf90"))

func _show_level(level: int) -> void:
	if is_instance_valid(level_banner):
		level_banner.hide()
		level_banner.queue_free()
	level_banner = _panel($Interface, Color("#503568"))
	var banner := level_banner
	banner.z_index = 20
	_label(banner, "Nível %d!" % level, 56)
	banner.reset_size()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2.ONE * 0.7
	var sparks := GPUParticles2D.new()
	sparks.emitting = false
	sparks.amount = 24
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.lifetime = 0.85
	sparks.position = banner.pivot_offset
	var burst := ParticleProcessMaterial.new()
	burst.particle_flag_disable_z = true
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 290.0
	burst.gravity = Vector3(0, 220, 0)
	burst.scale_min = 3.0
	burst.scale_max = 7.0
	burst.color = Color("#ffdf90")
	sparks.process_material = burst
	banner.add_child(sparks)
	sparks.emitting = true
	var tween := banner.create_tween()
	tween.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.8)
	tween.tween_property(banner, "modulate:a", 0.0, 0.25)
	tween.tween_callback(banner.queue_free)

func _float_effect(at: Vector2, symbol: String, color: Color, duration := 0.58, font_size := 84) -> void:
	var mark := _label($Interface, symbol, font_size)
	mark.add_theme_color_override("font_color", color)
	mark.add_theme_color_override("font_outline_color", Color("#70385f"))
	mark.add_theme_constant_override("outline_size", 8)
	mark.position = at - Vector2(31, 63)
	var flight := mark.create_tween().set_parallel()
	flight.tween_property(mark, "position:y", mark.position.y - 132.0, duration).set_ease(Tween.EASE_OUT)
	flight.tween_property(mark, "modulate:a", 0.0, duration - 0.21).set_delay(0.21)
	flight.chain().tween_callback(mark.queue_free)

func _label(parent: Node, words: String, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = words
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _panel(parent: Control, color: Color, padding: int = 25) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, 27, padding, Color("#aa86c6")))
	parent.add_child(panel)
	return panel

func _button(parent: Control, caption: String, color: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _style(color, 22, 13, color.lightened(0.35)))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.11), 22, 13, color.lightened(0.46)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.22), 22, 13, Color("#ffe39f")))
	parent.add_child(button)
	return button

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 35
	result.set_color("font_color", "Label", Color("#fff5ff"))
	result.set_color("font_color", "Button", Color("#fff5ff"))
	var focus := _style(Color.TRANSPARENT, 27, 24, Color("#ffe39f"))
	result.set_stylebox("focus", "Button", focus)
	return result

func _style(fill: Color, radius: int, padding: int, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.55
	style.content_margin_bottom = padding * 0.55
	style.shadow_color = Color(0.12, 0.07, 0.18, 0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 6)
	return style

func meter(parent: Control, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size.y = 17
	bar.add_theme_stylebox_override("background", _style(Color("#201930"), 8, 0, Color("#574369")))
	bar.add_theme_stylebox_override("fill", _style(color, 8, 0, color.lightened(0.2)))
	parent.add_child(bar)
	return bar
