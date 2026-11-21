extends ColorRect

const Wardrobe = preload("res://scripts/inventory/wardrobe.gd")
const Art = preload("res://scripts/inventory/wardrobe_art.gd")
const HudAnimation = preload("res://scripts/ui/hud_animation.gd")
var buttons := {}
var balance: Label
var message: Label
var preview := TextureRect.new()
var animation := HudAnimation.new()
var care: Node

func setup(hud: CanvasLayer, profile: Node) -> void:
	care = profile
	color = Color("#291e3b")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	hud._button(header, "‹ Voltar", Color("#594678")).pressed.connect(hide)
	hud._label(header, "Guarda-roupa", 44)
	balance = hud._label(column, "", 30)
	var stage := Control.new()
	stage.custom_minimum_size.y = 270
	column.add_child(stage)
	stage.clip_contents = true
	Art.attach(stage, care.wardrobe)
	stage.add_child(preview)
	preview.texture = hud.home.character.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(196, 238)
	preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	Art.attach(preview, care.wardrobe, Vector2(0.341,0.419), Vector2(0.652,0.419))
	message = hud._label(column, "", 28)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for category in [Wardrobe.HAT, Wardrobe.GLASSES, Wardrobe.WALL]:
		hud._label(list, category, 36)
		for item: String in Wardrobe.ITEMS:
			if Wardrobe.ITEMS[item][0] == category:
				var button: Button = hud._button(list, "", Color("#534268"))
				button.pressed.connect(_select.bind(item))
				buttons[item] = button
	care.changed.connect(refresh)
	visibility_changed.connect(refresh)
	hide()

func refresh() -> void:
	if not visible:
		return
	balance.text = "%d moedas" % care.coins
	for item: String in buttons:
		var spec: Array = Wardrobe.ITEMS[item]
		var action := "%d moedas" % spec[1]
		if item in care.wardrobe.owned:
			action = "Equipado · retirar" if care.wardrobe.equipped.get(spec[0]) == item else "Equipar"
		buttons[item].text = "%s  ·  %s" % [item, action]

func _select(item: String) -> void:
	message.text = care.wardrobe.select(item, care)
	if message.text.is_empty() and care.wardrobe.equipped.get(Wardrobe.ITEMS[item][0]) == item:
		animation.pop(preview)
