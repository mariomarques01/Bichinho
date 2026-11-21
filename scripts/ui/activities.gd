extends RefCounted

const Care = preload("res://scripts/needs/care.gd")
const PulaEvo = preload("res://scripts/minigames/pula_evo.gd")
const SYMBOLS := ["Sol", "Lua", "Flor", "Mar", "Luz", "Céu"]
const TITLES := ["Alimentar", "Higienizar", "Descansar", "Carinho", "Brincar", "Experimentar"]
const COLORS := ["#a95320", "#22688e", "#644397", "#963c73", "#5054a0", "#267458"]
var hud: CanvasLayer
var care: Care
var mode := -1
var cards: Array[String] = []
var card_buttons: Array[Button] = []
var first := -1
var streak := 0
var combo_bonus := 0
var memory_status: Label
var jumping := false
var mistakes := 0
var pairs := 0
var locked := false
var selection: Array[String] = []

func enter(next: int) -> void:
	jumping = false
	mode = next
	selection.clear()
	cards.clear()
	paint()

func paint() -> void:
	for node in hud.activity.get_children():
		hud.activity.remove_child(node)
		node.queue_free()
	hud.activity.visible = mode > 2
	if mode <= 2:
		return
	var title: Label = hud._label(hud.activity, TITLES[mode], 39)
	title.add_theme_color_override("font_color", Color("#ffe3bb"))
	if care.sick and mode in [4, 5]:
		hud._label(hud.activity, Care.SICK_MESSAGE, 30).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	match mode:
		4:
			if jumping:
				_pula_evo()
			else:
				_memory()
		5: _experiment()

func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.activity.add_child(grid)
	return grid

func _memory() -> void:
	memory_status = hud._label(hud.activity, "Memória Mágica · encontre os pares.", 30)
	if cards.is_empty():
		var options := _grid(2)
		hud._button(options, "Pular", Color(COLORS[4])).pressed.connect(hud.jump_requested.emit)
		hud._button(options, "Jogar memória", Color(COLORS[4])).pressed.connect(func() -> void:
			hud.play_sound(&"toque")
			var level := Care.level_progress(care.xp).x
			var count := 6 if level >= 5 else (4 if level >= 3 else 3)
			cards.assign(SYMBOLS.slice(0, count))
			cards.append_array(SYMBOLS.slice(0, count))
			streak = 0
			combo_bonus = 0
			cards.shuffle()
			first = -1
			mistakes = 0
			pairs = 0
			locked = false
			paint.call_deferred()
		)
		hud._button(options, "Pula EVO", Color(COLORS[4])).pressed.connect(func() -> void:
			jumping = true
			paint.call_deferred()
		)
		return
	card_buttons.clear()
	var grid := _grid(3 if cards.size() == 6 else 4)
	for i in cards.size():
		var button: Button = hud._button(grid, "?", Color(COLORS[4]))
		card_buttons.append(button)
		button.pressed.connect(_reveal.bind(i))

func _reveal(index: int) -> void:
	if locked or first == index or index >= cards.size() or card_buttons[index].disabled:
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
		streak += 1
		combo_bonus += streak - 1
		var goal := cards.size() / 2
		memory_status.text = "%d/%d pares · sequência %d · bônus +%d" % [pairs, goal, streak, combo_bonus]
		hud.play_pair.emit(pairs == goal)
		if pairs == goal:
			hud.play_sound(&"recompensa")
			var score := maxi(1, pairs * 2 + combo_bonus - mistakes)
			var perfect := goal * 2 + goal * (goal - 1) / 2
			var reward := care.played(clampi(roundi(6.0 * score / perfect), 1, 6))
			hud.show_reaction("%d pontos! +%d moedas" % [score, reward])
			cards.clear()
			paint.call_deferred()
	else:
		streak = 0
		memory_status.text = "%d/%d pares" % [pairs, cards.size() / 2]
		mistakes += 1
		locked = true
		var left := card_buttons[previous]
		var right := card_buttons[index]
		await hud.get_tree().create_timer(0.65).timeout
		if is_instance_valid(left) and is_instance_valid(right):
			left.text = "?"
			right.text = "?"
			locked = false

func _pula_evo() -> void:
	hud._label(hud.activity, "Pula EVO · segure à esquerda ou à direita", 30)
	var game := PulaEvo.new()
	game.avatar = hud.home.character.texture
	hud.activity.add_child(game)
	game.finished.connect(func(height: int) -> void:
		if not jumping or mode != 4 or care.sick:
			return
		jumping = false
		var reward := care.played(clampi(ceili(height / 15.0), 0, 6))
		if reward > 0:
			hud.play_sound(&"recompensa")
		hud.show_reaction("Pula EVO · %d m · +%d moedas" % [height, reward])
		paint.call_deferred()
	, CONNECT_ONE_SHOT)

func _experiment() -> void:
	hud._label(hud.activity, "Escolha dois ingredientes para misturar.", 30)
	var grid := _grid(3)
	for ingredient: String in ["Folha", "Cristal", "Fruta"]:
		var button: Button = hud._button(grid, ingredient, Color(COLORS[5]))
		button.toggle_mode = true
		button.toggled.connect(func(on: bool) -> void:
			if on and selection.size() < 2:
				selection.append(ingredient)
				hud.ingredient_selected.emit()
			elif on:
				button.set_pressed_no_signal(false)
			else:
				selection.erase(ingredient)
		)
	hud._button(hud.activity, "Misturar · %d/3 descobertas" % care.discoveries.size(), Color(COLORS[5])).pressed.connect(func() -> void:
		var previous: int = care.discoveries.size()
		hud.show_reaction(care.mix(selection))
		if selection.size() == 2:
			hud.mixture_ready.emit()
		hud.play_sound(&"recompensa" if care.discoveries.size() > previous else &"toque")
		selection.clear()
		paint.call_deferred()
	)
