extends SceneTree

const Main = preload("res://scenes/main/main.tscn")
var failures := 0
var checks := 0

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
	var old_position: Vector2 = hud.home.character.position
	var before_drag_xp: int = game.care.xp
	_button_at(head, true)
	_drag(head + Vector2(55, 0))
	_expect(hud.home.dragging and hud.home.character.position.x > old_position.x, "Arraste move o Evolin no quarto")
	_button_at(head + Vector2(55, 0), false)
	_expect(not hud.home.holding and hud.home.reaction.is_running(), "Soltar inicia squash e stretch")
	_expect(game.care.xp == before_drag_xp, "Arrastar respeita o intervalo de carinho")
	hud.home.reaction.custom_step(0.10)
	_expect(hud.home.character.scale.x > 1.05 and hud.home.character.scale.y < 1.0, "O Evolin achata ao soltar")
	game._sample_acceleration(Vector3.ZERO)
	game._sample_acceleration(Vector3(0, 9.8, 0))
	_expect(game.shake_ready_at == 0, "Sensor ausente ou em repouso não dispara reação")
	game._sample_acceleration(Vector3(20, 9.8, 0))
	_expect(game.shake_ready_at > 0 and game.care.xp == before_drag_xp, "Chacoalhar reage sem conceder carinho")
	game.shake_ready_at = 0
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	_expect(game.shake_ready_at > 0, "Espaço aciona a reação sem acelerômetro")
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
	_expect(float(evolin.eyelids.get_shader_parameter("closure")) < 0.01, "Olhos reabrem após a piscada")
	evolin.time = 0.4
	evolin._process(0.0)
	_expect(evolin.tail_bone >= 0 and not evolin.skeleton.get_bone_pose_rotation(evolin.tail_bone).is_equal_approx(evolin.tail_rest), "O osso da cauda reage à animação")
	var original: Dictionary = game.care.needs.duplicate()
	for pair in [["Energia", evolin.Mood.SONOLENTO], ["Higiene", evolin.Mood.SUJO], ["Fome", evolin.Mood.FAMINTO]]:
		game.care.needs[pair[0]] = 18.0
		game.care.changed.emit()
		_expect(evolin.mood == pair[1], "A necessidade %s muda a expressão" % pair[0])
		game.care.needs[pair[0]] = original[pair[0]]
	game.care.changed.emit()
	_expect(evolin.mood == evolin.Mood.FELIZ, "Recuperar as necessidades restaura o sorriso")
	evolin.idle_wait = 0.0
	evolin._update_idle(0.4)
	_expect(evolin.idle_wait >= 6.0 and evolin.idle_wait <= 12.0 and absf(evolin.look) + evolin.stretch > 0.0, "Idle varia a pose e agenda outro gesto")
	await _test_care(game, hud)
	_test_sickness(game, hud)
	_test_rewards(game, hud)
	_test_local_day_and_sleep(game.care)
	_test_wardrobe(game, hud)
	await _test_minigames(game.care, hud)
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
		print("EVO: %d verificações passaram." % checks)
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
	await create_timer(0.32).timeout
	_expect(care.stock["Maçã"] == 1 and hud.feeding.stats["Fome"][1].value == 65, "Alimentação consome um item e atualiza o HUD")
	await create_timer(0.18).timeout
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
	_expect(roundi(care.needs["Higiene"]) == 72 and hud.bath.readings[1].text == "72%", "Banho recupera higiene e atualiza o HUD após dez movimentos")
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
	hud._open(3)
	_expect(hud.home.visible and not hud.safe.visible and hud.menu.mode == -1, "Carinho volta do descanso para o quarto ilustrado")
	hud.home.action_buttons[4].pressed.emit()
	await hud.home.action_buttons[4].chosen
	_expect(hud.home.visible and not hud.safe.visible and hud.activity_card.is_visible_in_tree(), "Brincar abre os jogos no próprio quarto")
	await process_frame
	_expect(hud.room_games.position.y > 240 and hud.room_games.get_rect().end.y <= 930, "Jogos deixam a navegação do quarto acessível")
	hud.activity.get_child(2).get_child(1).pressed.emit()
	await process_frame
	var balance: int = care.coins
	for value in ["Sol", "Lua", "Flor"]:
		var first: int = hud.menu.cards.find(value)
		var second: int = hud.menu.cards.rfind(value)
		hud.menu.card_buttons[first].pressed.emit()
		hud.menu.card_buttons[second].pressed.emit()
	_expect(hud.menu.combo_bonus == 3 and hud.menu.streak == 3, "Três pares seguidos somam três pontos de combo")
	_expect(care.coins == balance + 8, "Concluir o jogo da memória concede moedas")
	_expect(game.evolin.reaction.is_running(), "O último par aciona a comemoração")
	var rewards: Array[Label] = []
	for child in hud.get_node("Interface").get_children():
		if child is Label and child.text in ["+12 XP", "+8 moedas"]:
			rewards.append(child)
	_expect(rewards.size() == 2, "Ganhos simultâneos mostram XP e moedas")
	await create_timer(0.10).timeout
	_expect(hud.home.coin_icon.scale.x > 1.0 and int(hud.home.coins.text) < care.coins, "A moeda cresce enquanto o saldo sobe")
	await create_timer(0.75).timeout
	_expect(hud.home.coin_icon.scale.is_equal_approx(Vector2.ONE) and int(hud.home.coins.text) == care.coins, "Ícone e saldo terminam a animação")
	for reward in rewards:
		_expect(not is_instance_valid(reward), "O número flutuante desaparece")
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

func _test_sickness(game: Node3D, hud: CanvasLayer) -> void:
	var care = game.care
	var start: int = care.last_update
	care.needs["Fome"] = 15.12
	care.needs["Higiene"] = 90.0
	care.needs["Felicidade"] = 90.0
	care.advance(start + 1860)
	_expect(not care.sick, "Exatamente 30 minutos abaixo de 15 ainda não causam doença")
	care.advance(start + 1920)
	_expect(care.sick and is_equal_approx(care.needs["Felicidade"], 90.0 - 33.0 * 0.07), "Felicidade cai em dobro apenas após adoecer")
	_expect(hud.sickness_icon.visible and game.evolin.mood == game.evolin.Mood.DOENTE, "HUD e expressão indicam doença")
	var saved := ConfigFile.new()
	_expect(saved.load(care.save_path) == OK and saved.get_value("care", "sick", false), "A doença é salva ao começar")
	var loaded = care.get_script().new()
	loaded.save_path = care.save_path
	root.add_child(loaded)
	_expect(loaded.sick and is_equal_approx(loaded.low_seconds["Fome"], care.low_seconds["Fome"]), "Reabrir o save preserva doença e exposição")
	loaded.queue_free()
	var balance: int = care.coins
	care.played(6)
	var ingredients: Array[String] = ["Cristal", "Folha"]
	_expect(care.coins == balance and care.mix(ingredients) == care.SICK_MESSAGE, "Diversão bloqueada preserva as recompensas")
	for index in [4, 5]:
		hud._open(index)
		_expect(hud.activity.get_child(1).text == care.SICK_MESSAGE, "Atividade bloqueada explica como curar")
	hud._open(0)
	care.coins = 14
	hud.feeding.shopping = true
	hud.feeding.medicine.pressed.emit()
	_expect(care.stock[care.MEDICINE] == 0 and care.coins == 14, "Saldo insuficiente preserva o estoque")
	care.coins = 15
	hud.feeding.medicine.pressed.emit()
	_expect(care.stock[care.MEDICINE] == 1 and care.coins == 0 and care.sick, "Comprar remédio custa 15 moedas")
	hud.feeding.shopping = false
	hud.feeding.medicine.pressed.emit()
	_expect(not care.sick and not hud.sickness_icon.visible and care.stock[care.MEDICINE] == 0, "Usar a dose cura e remove o ícone")
	care.advance(care.last_update + 60)
	_expect(not care.sick, "A cura reinicia o tempo de exposição")
	care.needs["Fome"] = 80.0
	care.needs["Higiene"] = 12.0
	care.advance(care.last_update + 1700)
	care.wash()
	care.advance(care.last_update + 200)
	_expect(not care.sick, "Banho interrompe a exposição contínua")
	care.needs["Higiene"] = 12.0
	care.advance(care.last_update + 1801)
	_expect(care.sick, "Higiene baixa também causa doença")

func _test_rewards(game: Node3D, hud: CanvasLayer) -> void:
	var care = game.care
	care.sick = false
	care.xp = 49
	care.changed.emit()
	var balance: int = care.coins
	care.daily_wins = 0
	_expect(care.played(3) == 5 and care.coins == balance + 25, "Pontuação, bônus e nível 2 pagam juntos")
	_expect(is_instance_valid(hud.level_banner) and hud.level_banner.get_child(0).text == "Nível 2!", "Subir de nível mostra o painel")
	_expect(care.level_progress(181) == Vector3i(2, 131, 132) and care.level_progress(182).x == 3, "A curva usa o custo acumulado de cada nível")
	care.played(1)
	care.played(2)
	_expect(care.played(6) == 6, "Quarta vitória mantém só a recompensa de pontuação")
	var loaded = care.get_script().new()
	loaded.save_path = care.save_path
	root.add_child(loaded)
	_expect(loaded.coins == care.coins and loaded.played(3) == 3, "Reabrir o save preserva o limite diário e o saldo")
	loaded.bonus_day -= 1
	_expect(loaded.played(3) == 5, "Um novo dia renova o bônus")
	loaded.queue_free()

func _test_local_day_and_sleep(profile: Node) -> void:
	var care = profile.get_script().new()
	var midnight := 20000 * 86400
	_expect(care._local_day(midnight + 10799, -180) == 19999 and care._local_day(midnight + 10800, -180) == 20000, "Bônus vira à meia-noite local em UTC−3")
	_expect(care._local_day(midnight - 19801, 330) == 19999 and care._local_day(midnight - 19800, 330) == 20000, "Bônus considera fusos positivos com meia hora")
	care.save_path = profile.save_path + ".v1"
	var old := ConfigFile.new()
	var stamp: int = care.now()
	old.set_value("care", "version", 1)
	old.set_value("care", "last_update", stamp)
	old.set_value("care", "bonus_day", stamp / 86400)
	old.set_value("care", "daily_wins", 3)
	old.save(care.save_path)
	root.add_child(care)
	var migrated := ConfigFile.new()
	migrated.load(care.save_path)
	_expect(migrated.get_value("care", "version") == 2 and migrated.get_value("care", "bonus_day") == care._local_day(stamp) and care.played(1) == 1, "Save v1 migra sem repetir o bônus")
	care.needs["Fome"] = 10.0
	care.needs["Higiene"] = 16.0
	care.low_seconds["Fome"] = 1750.0
	care.rest_end = stamp + 3600
	care.advance(stamp + 2400)
	_expect(not care.sick and care.low_seconds["Fome"] == 1750 and care.low_seconds["Higiene"] == 0, "Sono pausa exposição anterior e ignora nova exposição")
	_expect(is_equal_approx(care.needs["Fome"], 5.2) and is_equal_approx(care.needs["Higiene"], 12.8), "Fome e higiene continuam caindo durante o sono")
	care.advance(stamp + 3650)
	_expect(not care.sick and care.low_seconds["Fome"] == 1800 and care.low_seconds["Higiene"] == 50, "Avanço offline conta apenas os segundos após acordar")
	care.advance(stamp + 3651)
	_expect(care.sick, "Exposição continua após acordar e ultrapassar meia hora")
	DirAccess.remove_absolute(care.save_path)
	care.queue_free()

func _test_wardrobe(game: Node3D, hud: CanvasLayer) -> void:
	var care = game.care
	var model = care.wardrobe
	var screen = hud.wardrobe_screen
	for child in hud.home.get_children():
		if child is Button and child.accessibility_name == "Inventário":
			child.pressed.emit()
	_expect(screen.visible and screen.buttons.size() == 9, "Guarda-roupa lista os nove itens")
	care.coins = 19
	screen.buttons["Boina"].pressed.emit()
	_expect(care.coins == 19 and model.owned.is_empty(), "Sem saldo preserva o inventário")
	care.coins = 200
	for item in ["Boina", "Quadrados", "Bolinhas", "Cartola"]:
		screen.buttons[item].pressed.emit()
	_expect(care.coins == 65 and model.owned.size() == 4, "Compra debita o preço de cada item uma vez")
	_expect(model.equipped[model.HAT] == "Cartola" and model.equipped.size() == 3, "Cada categoria mantém um único item equipado")
	screen.buttons["Boina"].pressed.emit()
	_expect(care.coins == 65 and screen.animation.pop_tween.is_running(), "Reequipar é gratuito e anima o Evolin")
	var loaded = care.get_script().new()
	loaded.save_path = care.save_path
	root.add_child(loaded)
	_expect(loaded.wardrobe.snapshot() == model.snapshot() and loaded.coins == 65, "Recarregar restaura roupas, papel de parede e saldo")
	loaded.queue_free()
	screen.buttons["Boina"].pressed.emit()
	_expect(not model.equipped.has(model.HAT) and "Boina" in model.owned, "Retirar mantém o item comprado")
	screen.hide()

func _test_minigames(care: Node, hud: CanvasLayer) -> void:
	hud._open(4)
	for level in [3, 5]:
		care.xp = 0
		while care.level_progress(care.xp).x < level:
			care.xp += care.level_progress(care.xp).z
		hud.activity.get_child(2).get_child(1).pressed.emit()
		await process_frame
		_expect(hud.menu.cards.size() == (8 if level == 3 else 12), "Memória ajusta pares no nível %d" % level)
		hud.menu._reveal(hud.menu.cards.find("Sol"))
		hud.menu._reveal(hud.menu.cards.rfind("Sol"))
		hud.menu._reveal(hud.menu.cards.find("Lua"))
		hud.menu._reveal(hud.menu.cards.find("Flor"))
		_expect(hud.menu.streak == 0 and hud.menu.mistakes == 1, "Errar quebra a sequência")
		await create_timer(0.68).timeout
		hud.menu.enter(4)
	hud.activity.get_child(2).get_child(2).pressed.emit()
	await process_frame
	var jumper = hud.activity.get_child(2)
	jumper.set_physics_process(false)
	var bounced := false
	for frame in 120:
		var falling: bool = jumper.speed_y > 0
		jumper._physics_process(1.0 / 60)
		if falling and jumper.speed_y < 0:
			bounced = true
			break
	_expect(bounced, "Evolin aterrissa na primeira plataforma e volta a pular")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position.x = 0.0 if jumper.platforms[0].x > 200 else jumper.size.x
	jumper._gui_input(press)
	_expect(abs(jumper.direction) == 1, "Metade tocada define a direção")
	var before: int = care.coins
	care.daily_wins = 3
	care.bonus_day = care._local_day(care.now())
	for frame in 240:
		jumper._physics_process(1.0 / 60)
		if not jumper.running:
			break
	var earned := clampi(ceili(jumper.height / 15.0), 0, 6)
	_expect(not jumper.running and jumper.height > 15 and care.coins == before + earned, "Queda paga a altura alcançada sem ultrapassar o bônus diário")
	jumper._physics_process(1.0 / 60)
	_expect(care.coins == before + earned, "A queda paga uma única vez")
	await process_frame
	hud.activity.get_child(2).get_child(2).pressed.emit()
	await process_frame
	care.sick = true
	care.changed.emit()
	_expect(not hud.menu.jumping and hud.activity.get_child(1).text == care.SICK_MESSAGE and care.coins == before + earned, "Adoecer interrompe Pula EVO sem pagar")

func _click(at: Vector2) -> void:
	_button_at(at, true)
	_button_at(at, false)

func _button_at(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
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
	checks += 1
	if not condition:
		failures += 1
		push_error(check)
