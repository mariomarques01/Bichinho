extends RefCounted

const Care = preload("res://scripts/needs/care.gd")
const TITLES := ["Alimentar", "Higienizar", "Descansar", "Carinho", "Brincar", "Experimentar"]
const COLORS := ["#a95320", "#22688e", "#644397", "#963c73", "#5054a0", "#267458"]
var hud: CanvasLayer
var care: Care
var mode := -1
var rest_status: Label
var wake_button: Button
var rest_buttons: Array[Button] = []
var cards: Array[String] = []
var card_buttons: Array[Button] = []
var first := -1
var pairs := 0
var locked := false
var selection: Array[String] = []

func enter(next: int) -> void:
	mode = next
	selection.clear()
	cards.clear()
	paint()

func paint() -> void:
	rest_status = null
	wake_button = null
	rest_buttons.clear()
	for node in hud.activity.get_children():
		hud.activity.remove_child(node)
		node.queue_free()
	hud.activity.visible = mode > 1
	if mode <= 1:
		return
	var title: Label = hud._label(hud.activity, TITLES[mode], 39)
	title.add_theme_color_override("font_color", Color("#ffe3bb"))
	match mode:
		2: _rest()
		3:
			hud._label(hud.activity, "Toque ou deslize sobre o Evolin.", 30)
			hud._button(hud.activity, "Fazer carinho", Color(COLORS[3])).pressed.connect(hud.pet_requested.emit)
		4: _memory()
		5: _experiment()

func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.activity.add_child(grid)
	return grid

func _rest() -> void:
	rest_status = hud._label(hud.activity, "", 30)
	var grid := _grid(3)
	var captions := ["30 min", "1 hora", "3 horas"]
	for i in 3:
		var minutes: int = [30, 60, 180][i]
		var button: Button = hud._button(grid, captions[i], Color(COLORS[2]))
		rest_buttons.append(button)
		button.pressed.connect(func() -> void:
			if care.rest(minutes):
				hud.play_sound(&"descanso")
				hud.show_reaction("Boa noite, Evolin!")
		)
	wake_button = hud._button(hud.activity, "Acordar", Color(COLORS[2]))
	wake_button.pressed.connect(func() -> void:
		hud.play_sound(&"toque")
		care.wake()
	)
	refresh()

func refresh() -> void:
	if not is_instance_valid(rest_status):
		return
	var remaining := maxi(0, care.rest_end - care.now())
	var sleeping := care.rest_end > 0
	rest_status.text = "Descansando · %02d:%02d:%02d" % [remaining / 3600, remaining / 60 % 60, remaining % 60] if sleeping else "Escolha quanto tempo Evolin vai descansar."
	for button in rest_buttons:
		button.disabled = sleeping
	wake_button.visible = sleeping

func _memory() -> void:
	hud._label(hud.activity, "Memória Mágica · encontre os pares.", 30)
	if cards.is_empty():
		var options := _grid(2)
		hud._button(options, "Pular", Color(COLORS[4])).pressed.connect(hud.jump_requested.emit)
		hud._button(options, "Jogar memória", Color(COLORS[4])).pressed.connect(func() -> void:
			hud.play_sound(&"toque")
			cards.assign(["Sol", "Lua", "Flor", "Sol", "Lua", "Flor"])
			cards.shuffle()
			first = -1
			pairs = 0
			locked = false
			paint.call_deferred()
		)
		return
	card_buttons.clear()
	var grid := _grid(3)
	for i in cards.size():
		var button: Button = hud._button(grid, "?", Color(COLORS[4]))
		card_buttons.append(button)
		button.pressed.connect(_reveal.bind(i))

func _reveal(index: int) -> void:
	if locked or first == index:
		return
	hud.play_sound(&"toque")
	card_buttons[index].text = cards[index]
	if first < 0:
		first = index
		return
	var previous := first
	first = -1
	if cards[previous] == cards[index]:
		card_buttons[previous].disabled = true
		card_buttons[index].disabled = true
		pairs += 1
		if pairs == 3:
			hud.play_sound(&"recompensa")
			care.played()
			hud.show_reaction("Todos os pares! +8 moedas")
			cards.clear()
			paint.call_deferred()
	else:
		locked = true
		var left := card_buttons[previous]
		var right := card_buttons[index]
		await hud.get_tree().create_timer(0.65).timeout
		if is_instance_valid(left) and is_instance_valid(right):
			left.text = "?"
			right.text = "?"
			locked = false

func _experiment() -> void:
	hud._label(hud.activity, "Escolha dois ingredientes para misturar.", 30)
	var grid := _grid(3)
	for ingredient: String in ["Folha", "Cristal", "Fruta"]:
		var button: Button = hud._button(grid, ingredient, Color(COLORS[5]))
		button.toggle_mode = true
		button.toggled.connect(func(on: bool) -> void:
			if on and selection.size() < 2:
				selection.append(ingredient)
			elif on:
				button.set_pressed_no_signal(false)
			else:
				selection.erase(ingredient)
		)
	hud._button(hud.activity, "Misturar · %d/3 descobertas" % care.discoveries.size(), Color(COLORS[5])).pressed.connect(func() -> void:
		var previous: int = care.discoveries.size()
		hud.show_reaction(care.mix(selection))
		hud.play_sound(&"recompensa" if care.discoveries.size() > previous else &"toque")
		selection.clear()
		paint.call_deferred()
	)
