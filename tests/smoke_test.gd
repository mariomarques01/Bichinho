extends SceneTree

const Main = preload("res://scenes/main/main.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Main.instantiate()
	game.care.save_path = "user://care-smoke-%s.cfg" % str(Time.get_ticks_usec())
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var evolin: Node3D = game.get_node("Evolin")
	var room: Node3D = game.get_node("Room")
	var hud: CanvasLayer = game.get_node("HUD")
	var pulse: float = hud.home.idle_clock
	await create_timer(0.12).timeout
	_expect(hud.home.idle_clock > pulse, "Evolin respira no quarto")
	hud.home.idle_clock = 3.735
	hud.home._process(0.0)
	_expect(float(hud.home.eyelids.get_shader_parameter("closure")) > 0.95, "Quarto pisca em repouso")
	hud.home.idle_clock = 0.0
	var head: Vector2 = hud.home.pet_point()
	_click(Vector2(4, 4))
	await physics_frame
	await process_frame
	_expect(hud.feedback.text.begins_with("Toque"), "Toque fora do Evolin preserva a instrução")
	_click(head)
	await physics_frame
	await process_frame
	_expect(hud.feedback.text.contains("carinho"), "Toque acerta o Evolin e atualiza a interface")
	_expect(_hearts(hud) == 1, "Toque cria um coração")
	_click(head)
	await physics_frame
	await process_frame
	_expect(_hearts(hud) == 1, "Intervalo mínimo limita os efeitos de toques repetidos")
	await create_timer(0.64).timeout
	_expect(_hearts(hud) == 0, "Coração é removido após a animação")
	_drag(head + Vector2(55, 0))
	await physics_frame
	await process_frame
	_expect(_hearts(hud) == 1, "Arraste sobre o Evolin dispara carinho")
	hud.lamp_button.pressed.emit()
	_expect(room.night and hud.lamp_button.text == "Amanhecer", "Botão alterna para noite")
	hud.lamp_button.pressed.emit()
	_expect(not room.night and hud.lamp_button.text == "Anoitecer", "Botão restaura o dia")
	hud.jump_requested.emit()
	await create_timer(0.27).timeout
	_expect(evolin.face.material_overlay == evolin.eyelids, "Carinho fecha os olhos")
	_expect(evolin.rig.position.y > 0.25, "Pulo eleva o personagem")
	await create_timer(0.32).timeout
	_expect(is_zero_approx(evolin.rig.position.y), "Pulo retorna ao tapete")
	evolin.delight = 0.0
	evolin.blink_elapsed = 3.86
	evolin._update_eyelids(0.12)
	_expect(evolin.face.material_overlay == evolin.eyelids, "Evolin pisca sozinho")
	evolin._update_eyelids(0.13)
	_expect(evolin.face.material_overlay == null, "Olhos reabrem após a piscada")
	evolin.time = 0.4
	evolin._process(0.0)
	_expect(evolin.tail_bone >= 0 and not evolin.skeleton.get_bone_pose_rotation(evolin.tail_bone).is_equal_approx(evolin.tail_rest), "O osso da cauda reage à animação")
	await _test_care(game, hud)
	_expect(game.sounds.players[&"mordida"].stream.get_length() > 0.0, "Áudio da mordida é carregado")
	game.hud.play_sound(&"toque")
	_expect(game.sounds.players[&"toque"].playing, "O HUD aciona o efeito de navegação")
	for player: AudioStreamPlayer in game.sounds.players.values():
		player.stop()
	DirAccess.remove_absolute(game.care.save_path)
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("EVO: 43 verificações passaram.")
	quit(1 if failures > 0 else 0)

func _test_care(game: Node3D, hud: CanvasLayer) -> void:
	var care = game.care
	care.needs["Fome"] = 50.0
	care.stock["Maçã"] = 2
	hud.home.action_buttons[0].pressed.emit()
	_expect(hud.home.action_buttons[0].choosing and hud.home.visible, "Toque anima o botão antes de abrir a atividade")
	await hud.home.action_buttons[0].chosen
	hud.feeding.idle_clock = 3.735
	hud.feeding._process(0.0)
	_expect(float(hud.feeding.eyelids.get_shader_parameter("closure")) > 0.95, "Alimentar pisca antes de receber comida")
	var drop: Vector2 = hud.feeding.character.get_global_rect().get_center()
	hud.request_food_drop("Maçã", drop)
	await process_frame
	_expect(care.stock["Maçã"] == 1 and hud.feeding.stats["Fome"][1].value == 65, "Alimentação consome um item e atualiza o HUD")
	await create_timer(0.50).timeout
	_expect(hud.feeding.character.texture == hud.feeding.eating_pose, "Soltar o alimento inicia a animação de comer")
	await create_timer(0.62).timeout
	hud.request_food_drop("Maçã", Vector2(4, 4))
	await physics_frame
	await process_frame
	_expect(care.stock["Maçã"] == 1, "Soltar alimento fora do Evolin preserva o estoque")
	hud.request_food_drop("Maçã", drop)
	await physics_frame
	await process_frame
	_expect(care.stock["Maçã"] == 0, "Soltar alimento sobre o Evolin consome uma unidade")
	hud._open(0)
	_expect(not hud.feeding.animating and hud.feeding.character.texture == hud.feeding.idle_pose, "Sair de Alimentar encerra a mastigação")
	hud.home.action_buttons[1].pressed.emit()
	await hud.home.action_buttons[1].chosen
	hud.bath.idle_clock = 3.735
	hud.bath._process(0.0)
	_expect(float(hud.bath.movement.get_shader_parameter("opening")) < 0.05, "Higienizar pisca enquanto espera")
	care.needs["Higiene"] = 40.0
	_expect(hud.bath.visible and not hud.safe.visible, "Higienizar abre a tela ilustrada dedicada")
	hud.bath.scrub(Vector2(20, 10))
	_expect(hud.bath.progress == 0, "Movimentos fora da banheira não contam")
	hud.bath._select(3)
	hud.bath.scrub(Vector2(350, 500))
	_expect(hud.bath.progress == 0 and care.needs["Higiene"] == 40.0, "Toalha não ensaboa")
	hud.bath._select(0)
	for stroke in 10:
		hud.bath.scrub(Vector2(350, 500))
	_expect(care.needs["Higiene"] == 72.0 and hud.bath.readings[1].text == "72%", "Banho recupera higiene e atualiza o HUD após dez movimentos")
	_expect(float(hud.bath.movement.get_shader_parameter("response")) > 0.0, "Ensaboar faz o Evolin se mexer na banheira")
	hud.tabs[2].pressed.emit()
	_expect(hud.rest.visible and not hud.safe.visible, "Descansar abre o quarto noturno ilustrado")
	hud.rest._choose_item(4)
	_expect(hud.rest.prop.visible and hud.rest.selected == 4, "Escolher um acessório exibe o item à beira da cama")
	hud.rest._toggle_duration()
	_expect(hud.rest.panel.visible, "Tocar na cama abre as durações")
	hud.rest.duration_buttons[0].pressed.emit()
	_expect(care.rest_end > care.now() and game.evolin.sleeping, "Descanso ativa o estado de sono")
	await create_timer(0.32).timeout
	_expect(float(hud.rest.motion.get_shader_parameter("sleeping")) > 0.4, "Evolin se encolhe para dormir")
	care.needs["Energia"] = 40.0
	care.advance(care.rest_end)
	_expect(care.needs["Energia"] > 60.0 and not game.evolin.sleeping, "Descanso recupera energia e termina")
	hud.tabs[4].pressed.emit()
	hud.activity.get_child(2).get_child(1).pressed.emit()
	await process_frame
	var balance: int = care.coins
	for value in ["Sol", "Lua", "Flor"]:
		var first: int = hud.menu.cards.find(value)
		var second: int = hud.menu.cards.rfind(value)
		hud.menu.card_buttons[first].pressed.emit()
		hud.menu.card_buttons[second].pressed.emit()
	_expect(care.coins == balance + 8, "Concluir o jogo da memória concede moedas")
	_expect(game.evolin.reaction.is_running(), "O último par aciona a comemoração")
	await process_frame
	hud.tabs[5].pressed.emit()
	var ingredients: GridContainer = hud.activity.get_child(2)
	ingredients.get_child(0).button_pressed = true
	ingredients.get_child(1).button_pressed = true
	_expect(game.evolin.curious > 0.0, "Evolin se inclina ao escolher ingrediente")
	hud.activity.get_child(3).pressed.emit()
	await process_frame
	_expect(game.evolin.surprise > 0.0, "Misturar aciona a reação de surpresa")
	_expect("Cristal+Folha" in care.discoveries, "A receita é descoberta pelo menu")
	_expect(care.coins == balance + 14, "A primeira descoberta concede moedas")
	var save := ConfigFile.new()
	_expect(save.load(care.save_path) == OK and save.get_value("care", "coins", -1) == care.coins, "Ações salvam o progresso local")

func _click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _drag(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func _hearts(hud: CanvasLayer) -> int:
	var count := 0
	for child in hud.get_node("Interface").get_children():
		if child is Label and child.text == "♥":
			count += 1
	return count

func _expect(condition: bool, check: String) -> void:
	if not condition:
		failures += 1
		push_error(check)
