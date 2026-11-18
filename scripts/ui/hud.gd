extends CanvasLayer

signal pet_requested
signal jump_requested
signal lamp_requested

@onready var safe: MarginContainer = $Interface/SafeArea
var feedback: Label
var lamp_button: Button
var feedback_time: Timer

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
	var identity := VBoxContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_theme_constant_override("separation", 2)
	title_card.add_child(identity)
	var brand := _label(identity, "EVO", 30)
	brand.add_theme_color_override("font_color", Color("#91efce"))
	_label(identity, "Quarto do Evolin", 48)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var room_card := _panel(header, Color("#493356"))
	lamp_button = _button(room_card, "Anoitecer", Color("#594678"))
	lamp_button.pressed.connect(func() -> void: lamp_requested.emit())
	var free_space := Control.new()
	free_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	free_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(free_space)
	var card := _panel(column, Color("#36284e"))
	var controls := VBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_constant_override("separation", 18)
	card.add_child(controls)
	feedback = _label(controls, "Toque ou deslize sobre o Evolin", 32)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 74
	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 18)
	controls.add_child(actions)
	var pet_button := _button(actions, "Fazer carinho", Color("#963c73"))
	pet_button.pressed.connect(func() -> void: pet_requested.emit())
	var jump_button := _button(actions, "Pular", Color("#306561"))
	jump_button.pressed.connect(func() -> void: jump_requested.emit())
	feedback_time = Timer.new()
	feedback_time.one_shot = true
	feedback_time.timeout.connect(func() -> void: feedback.text = "Toque ou deslize sobre o Evolin")
	add_child(feedback_time)

func show_reaction(message: String) -> void:
	feedback.text = message
	feedback_time.start(2.0)

func set_night(night: bool) -> void:
	lamp_button.text = "Amanhecer" if night else "Anoitecer"

func heart(at: Vector2) -> void:
	var mark := _label($Interface, "♥", 84)
	mark.add_theme_color_override("font_color", Color("#ff9bcc"))
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

func _panel(parent: Control, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, 34, 25, Color("#aa86c6")))
	parent.add_child(panel)
	return panel

func _button(parent: Control, caption: String, color: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 99)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _style(color, 27, 24, color.lightened(0.35)))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.11), 27, 24, color.lightened(0.46)))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.22), 27, 24, color.lightened(0.25)))
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
