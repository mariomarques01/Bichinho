extends CanvasLayer

const Activities = preload("res://scripts/ui/activities.gd")

const Feeding = preload("res://scripts/ui/feeding.gd")

signal food_eaten
signal food_drop(food: String, at: Vector2)
signal activity_changed(index: int)
signal pet_requested
signal jump_requested
signal lamp_requested

@onready var safe: MarginContainer = $Interface/SafeArea
var feeding: Feeding
var feedback: Label
var lamp_button: Button
var feedback_time: Timer
var activity: VBoxContainer
var activity_card: PanelContainer
var menu := Activities.new()
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
	_update_safe_area()
	feeding.close()
	care.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var care := menu.care
	profile.text = "Nível %d  ·  %d/50 XP  ·  %d moedas" % [1 + care.xp / 50, care.xp % 50, care.coins]
	for key: String in bars:
		bars[key].value = care.needs[key]
		values[key].text = "%s  %d%%" % [key, roundi(care.needs[key])]
	menu.refresh()
	feeding.refresh()

func _open(index: int) -> void:
	var next := -1 if menu.mode == index else index
	menu.enter(next)
	activity_card.visible = next > 0
	safe.visible = next != 0
	if next == 0:
		feeding.open()
	else:
		feeding.close()
	activity_changed.emit(next)
	for i in tabs.size():
		tabs[i].set_pressed_no_signal(i == next)
	feedback_time.stop()
	feedback.text = "Toque ou deslize sobre o Evolin" if next < 0 else ""


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
	profile = _label(identity, "", 32)
	lamp_button = _button(header, "Anoitecer", Color("#594678"))
	lamp_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	lamp_button.pressed.connect(func() -> void: lamp_requested.emit())
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
	add_child(feedback_time)

func request_food_drop(food: String, at: Vector2) -> void:
	food_drop.emit(food, at)

func show_reaction(message: String) -> void:
	feedback.text = message
	feedback_time.start(2.0)

func set_night(night: bool) -> void:
	lamp_button.text = "Amanhecer" if night else "Anoitecer"

func heart(at: Vector2) -> void:
	_float_effect(at, "♥", Color("#ff9bcc"))

func bubble(at: Vector2) -> void:
	_float_effect(at, "○", Color("#b2f5ff"))

func _float_effect(at: Vector2, symbol: String, color: Color) -> void:
	var mark := _label($Interface, symbol, 84)
	mark.add_theme_color_override("font_color", color)
	mark.add_theme_color_override("font_outline_color", Color("#70385f"))
	mark.add_theme_constant_override("outline_size", 8)
	mark.position = at - Vector2(31, 63)
	var flight := mark.create_tween().set_parallel()
	flight.tween_property(mark, "position:y", mark.position.y - 132.0, 0.58).set_ease(Tween.EASE_OUT)
	flight.tween_property(mark, "modulate:a", 0.0, 0.37).set_delay(0.21)
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
