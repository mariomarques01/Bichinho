extends SceneTree

const State = preload("res://scripts/pet/evolin_state.gd")
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
	_expect(game.sounds.day.bus == &"Música" and game.sounds.players[&"carinho"].bus == &"Efeitos", "Música e efeitos usam buses separados")
	_expect(game.sounds.day.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.sounds.night.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Dia e noite reproduzem em loop")
	game.sounds.set_night(true)
	game.sounds.fade.custom_step(1.0)
	_expect(game.sounds.day.volume_linear < 0.001 and game.sounds.night.volume_linear > 0.6, "Crossfade ativa a ambiência noturna")
	game.sounds.set_night(false)
	var view = hud.home.poses
	var pulse: float = view.phase
	await create_timer(0.12).timeout
	_expect(view.phase > pulse, "Evolin respira no quarto")
	_test_pose_states(view)
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
	game._process(0.0)
	_expect(Engine.max_fps == 30, "Arraste respeita 30 FPS")
	_button_at(head + Vector2(55, 0), false)
	game._process(0.0)
	_expect(Engine.max_fps == 30, "Soltar restaura 30 FPS")
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
	game.care.needs["Felicidade"] = 80.0
	game.care.changed.emit()
	_expect(evolin.mood == evolin.Mood.FELIZ, "Recuperar as necessidades restaura o sorriso")
	game.care.needs["Felicidade"] = original["Felicidade"]
	game.care.changed.emit()
	evolin.idle_wait = 0.0
	evolin._update_idle(0.4)
	_expect(evolin.idle_wait >= 6.0 and evolin.idle_wait <= 12.0 and absf(evolin.look) + evolin.stretch > 0.0, "Idle varia a pose e agenda outro gesto")
	await _test_care(game, hud)
	_test_sickness(game, hud)
	_test_rewards(game, hud)
	_test_local_day_and_sleep(game.care)
	_test_save_recovery(game.care)
	_test_wardrobe(game, hud)
	await _test_minigames(game.care, hud)
	await _test_evolution()
	_expect(game.sounds.players[&"mordida"].stream.get_length() > 0.0, "Áudio da mordida é carregado")
	game.hud.play_sound(&"toque")
	_expect(game.sounds.players[&"toque"].playing, "O HUD aciona o efeito de navegação")
	for player: AudioStreamPlayer in game.sounds.players.values():
		player.stop()
	_clear_save(game.care.save_path)
	game.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("EVO: %d verificações passaram." % checks)
	quit(1 if failures > 0 else 0)

func _test_pose_states(view: Control) -> void:
	var needs := {"Higiene": 35, "Fome": 35, "Energia": 35, "Felicidade": 35}
	_expect(State.from_needs(needs, true) == State.SLEEPING, "Sono tem prioridade sobre as necessidades")
	for pair in [[State.DIRTY, "Higiene"], [State.HUNGRY, "Fome"], [State.TIRED, "Energia"], [State.SAD, "Felicidade"]]:
		_expect(State.from_needs(needs, false) == pair[0], "Prioridade " + String(pair[0]))
		needs[pair[1]] = 70
	_expect(State.from_needs(needs, false) == State.IDLE, "Estado neutro")
	needs["Felicidade"] = 80
	_expect(State.from_needs(needs, false) == State.HAPPY, "Felicidade 80 seleciona feliz")
	for key: StringName in [State.IDLE, State.HAPPY, State.SAD, State.HUNGRY, State.DIRTY, State.TIRED,
			State.EATING, State.BATHING, State.SLEEPING, State.PLAYING, State.CELEBRATING]:
		_expect(view.pose_map.poses.has(key) and view.pose_map.texture_for(key) != null, "Textura configurada para " + String(key))
	view.blink_age = 0.06
	view._process(0.0)
	_expect(view.lids[0].visible and view.lids[1].scale.y > 0.95, "Quarto pisca em repouso")
	var events: Array = []
	var capture := func(previous: StringName, current: StringName) -> void:
		events.append([previous, current])
	view.state.state_changed.connect(capture)
	var idle: Sprite2D = view.front
	view.react(State.HAPPY, 2.0, 1)
	var happy: Sprite2D = view.front
	_expect(view.state.current == State.HAPPY and not view.lids[0].visible, "Carinho troca pose e oculta pálpebras")
	view.state.refresh()
	_expect(events == [[State.IDLE, State.HAPPY]], "Sinal informa a troca uma única vez")
	view.fade.pause()
	view.fade.custom_step(0.1)
	_expect(is_equal_approx(idle.modulate.a, 0.5) and is_equal_approx(happy.modulate.a, 0.5), "Crossfade de 0,20 s mistura as duas poses no ponto médio")
	view._process(2.1)
	_expect(view.state.current == State.IDLE and events.back() == [State.HAPPY, State.IDLE], "Carinho termina e restaura o estado pelas necessidades")
	_expect(is_equal_approx(idle.modulate.a, 0.5) and is_equal_approx(happy.modulate.a, 0.5), "Interromper o crossfade mantém a opacidade atual")
	view.fade.custom_step(0.21)
	var map: Resource = view.pose_map
	view.pose_map = map.duplicate()
	var alternate: Texture2D = map.texture_for(State.SAD)
	view.pose_map.poses[State.HAPPY] = alternate
	view.pose_map.poses.erase(State.TIRED)
	_expect(view.pose_map.texture_for(State.TIRED) == idle.texture, "Pose ausente usa a textura idle")
	view.react(State.HAPPY, 1.0, 0)
	_expect(view.front.texture == alternate, "Resource personalizado troca a textura selecionada")
	view.pose_map = map
	view.cancel_reaction()
	view.state.state_changed.disconnect(capture)
	view.react(State.PLAYING, 1.0, 1)
	_expect(view.state.current == State.PLAYING and view.jumps == 1, "Pulo ativa o estado brincando")
	view.react(State.CELEBRATING, 1.0, 0)
	view.react(State.PLAYING, 1.0, 0)
	_expect(view.state.current == State.CELEBRATING, "Comemoração tem prioridade sobre brincadeira")
	var care = view.care
	care.rest_end = care.now() + 60
	care.changed.emit()
	view.react(State.EATING, 1.0, 0)
	_expect(view.state.current == State.SLEEPING, "Sono encerra reação ativa e impede uma nova")
	care.rest_end = 0
	care.changed.emit()
	_expect(view.state.current == State.IDLE, "Acordar recalcula as necessidades sem restaurar a reação anterior")

func _test_care(game: Node3D, hud: CanvasLayer) -> void:
	var care = game.care
	care.needs["Fome"] = 50.0
	care.stock["Maçã"] = 2
	hud.home.action_buttons[0].pressed.emit()
	_expect(hud.home.action_buttons[0].choosing and hud.home.visible, "Toque anima o botão antes de abrir a atividade")
	await hud.home.action_buttons[0].chosen
	hud.feeding.poses.blink_age = 0.06
	hud.feeding.poses._process(0.0)
	_expect(hud.feeding.poses.lids[0].visible, "Alimentar pisca antes de receber comida")
	var drop: Vector2 = hud.feeding.character.get_global_rect().get_center()
	hud.request_food_drop("Maçã", drop)
	await create_timer(0.32).timeout
	_expect(care.stock["Maçã"] == 1 and hud.feeding.stats["Fome"][1].value == 65, "Alimentação consome um item e atualiza o HUD")
	await create_timer(0.18).timeout
	_expect(hud.feeding.poses.state.current == State.EATING, "Soltar o alimento inicia a animação de comer")
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
	_expect(not hud.feeding.animating and hud.feeding.poses.state.current != State.EATING, "Sair de Alimentar encerra a mastigação")
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
	_expect(hud.bath.poses.state.current == State.BATHING, "Ensaboar ativa o estado de banho")
	_expect(float(hud.bath.movement.get_shader_parameter("response")) > 0.0, "Ensaboar faz o Evolin se mexer na banheira")
	hud.tabs[2].pressed.emit()
	_expect(hud.rest.visible and not hud.safe.visible, "Descansar abre o quarto noturno ilustrado")
	hud.rest._choose_item(4)
	_expect(hud.rest.prop.visible and hud.rest.selected == 4, "Escolher um acessório exibe o item à beira da cama")
	hud.rest._toggle_duration()
	_expect(hud.rest.panel.visible, "Tocar na cama abre as durações")
	hud.rest.duration_buttons[0].pressed.emit()
	_expect(care.rest_end > care.now() and game.evolin.sleeping, "Descanso ativa o estado de sono")
	_expect(hud.rest.poses.state.current == State.SLEEPING, "Pose de descanso acompanha o perfil")
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
	_expect(hud.home.poses.state.current == State.CELEBRATING, "Último par seleciona a pose de comemoração")
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
	var prior_cases: int = care.evolution.illnesses
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
	_expect(care.evolution.illnesses == prior_cases + 2, "Cada episódio conta uma única vez")

func _test_evolution() -> void:
	var game := Main.instantiate()
	game.care.save_path = "user://evolution-smoke-%d.cfg" % Time.get_ticks_usec()
	root.add_child(game)
	var hud: CanvasLayer = game.hud
	var care = game.care
	var growth = care.evolution
	_expect(growth.stage == "Filhote", "Antes do nível 5 é Filhote")
	for target in [5, 10]:
		var total := 0
		for level in range(1, target):
			total += roundi(50.0 * pow(level, 1.4))
		care.xp = total - 1
		care.evolution.averages = {"Fome": 60.0, "Higiene": 70.0, "Felicidade": 80.0}
		care.evolution.illnesses = 1
		care._gain_xp(1)
		care._commit()
		var expected := "Jovem" if target == 5 else "Adulto"
		_expect(growth.stage == expected and hud.stage_label.text.begins_with(expected), "Evolução e HUD no nível %d" % target)
	_expect(growth.form == "Aurora", "Média 70 e uma doença dão Aurora")
	var saved := ConfigFile.new()
	saved.load(care.save_path)
	var restored = growth.get_script().new()
	restored.restore(saved, care.needs, false)
	_expect(restored.stage == "Adulto" and restored.form == growth.form and restored.illnesses == 1 and restored.averages == growth.averages, "Save preserva a forma e o histórico")
	for diseases in [0, 2]:
		var other = growth.get_script().new()
		var values := {"Fome": 100.0, "Higiene": 80.0, "Felicidade": 90.0}
		other.sample(values, values, 10.0)
		if diseases == 0:
			var low := {"Fome": 10.0, "Higiene": 20.0, "Felicidade": 30.0}
			other.sample(low, low, 30.0)
			_expect(is_equal_approx(other.averages.Fome, 32.5), "Média pondera o tempo de cuidado")
		other.illnesses = diseases
		other.update(10)
		_expect(other.form == "Crepúsculo", "Média baixa ou duas doenças dão Crepúsculo")
		other.illnesses = 0
		other.averages = values
		other.update(11)
		_expect(other.form == "Crepúsculo", "A forma adulta permanece no nível 11")
	await create_timer(1.5).timeout

	_clear_save(care.save_path)
	game.queue_free()

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

func _clear_save(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func _test_save_recovery(profile: Node) -> void:
	var path: String = profile.save_path + ".recovery"
	var writer = profile.get_script().new()
	writer.save_path = path
	root.add_child(writer)
	_expect(writer.startup_message == "", "Primeiro jogo inicia sem aviso")
	writer.coins = 71
	writer._save()
	writer.coins = 89
	writer._save()
	writer.free()
	# Even a truncation on a valid section boundary must be detected.
	var truncated := FileAccess.get_file_as_string(path).get_slice("[integrity]", 0)
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(truncated)
	output.close()
	var reader = profile.get_script().new()
	reader.save_path = path
	root.add_child(reader)
	_expect(reader.coins == 71 and reader.startup_message == "", "Save truncado recupera a geração anterior")
	reader.free()
	DirAccess.remove_absolute(path + ".bak")
	output = FileAccess.open(path, FileAccess.WRITE)
	output.store_string(truncated)
	output.close()
	var fresh = profile.get_script().new()
	fresh.save_path = path
	root.add_child(fresh)
	_expect(fresh.coins == 30 and fresh.xp == 0 and fresh.startup_message == fresh.CORRUPT_MESSAGE, "Sem backup o jogo inicia limpo e sinaliza a perda")
	fresh.free()
	var reopened = profile.get_script().new()
	reopened.save_path = path
	root.add_child(reopened)
	_expect(reopened.startup_message == "", "Reabrir o novo save não repete o aviso")
	reopened.free()
	_clear_save(path)

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
	_expect(migrated.get_value("care", "version") == care.SAVE_VERSION and migrated.get_value("care", "bonus_day") == care._local_day(stamp) and care.played(1) == 1, "Save v1 migra sem repetir o bônus")
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
	_clear_save(care.save_path)
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
	press.position.x = 0.0 if jumper.platforms[0].position.x > 200 else jumper.size.x
	jumper._gui_input(press)
	_expect(abs(jumper.direction) == 1, "Metade tocada define a direção")
	var before: int = care.coins
	care.daily_wins = 3
	care.bonus_day = care._local_day(care.now())
	jumper.speed_y = 100.0
	jumper.player.y = jumper.camera_y + jumper.BOARD.y + 40
	jumper._physics_process(1.0 / 60)
	_expect(not jumper.running and care.coins == before, "Partida curta termina sem moedas")
	_expect(hud.room_result.text.contains("Novo recorde!") and care.pula_record == jumper.height + jumper.collected, "Fim de partida anuncia o recorde de pontos")
	var loaded = care.get_script().new()
	loaded.save_path = care.save_path
	root.add_child(loaded)
	_expect(loaded.pula_record == care.pula_record, "Recorde persiste no save")
	loaded.free()
	_expect(jumper.payout(41, 7.99, true) == 0 and jumper.payout(41, 8.0, true) == 2 and jumper.payout(999, 20, true) == 6, "Recompensa respeita duração, altura e teto")
	_expect(jumper.payout(321, 15, false) == 0, "Ocioso não ganha moedas mesmo após oito segundos")
	jumper._physics_process(1.0 / 60)
	_expect(care.coins == before, "A queda paga uma única vez")
	_fuzz_pula()
	await process_frame
	hud.activity.get_child(2).get_child(2).pressed.emit()
	await process_frame
	jumper = hud.activity.get_child(2)
	jumper.elapsed = 8.0
	jumper.height = 81
	jumper.steered = true
	jumper.speed_y = 100
	jumper.player.y = jumper.camera_y + jumper.BOARD.y + 45
	care.daily_wins = 0
	care.xp = 0
	jumper._physics_process(1.0 / 60)
	_expect(care.coins == before + 3 and care.daily_wins == 0, "Partida válida paga apenas ceil(altura/40)")
	before = care.coins
	await process_frame
	hud.activity.get_child(2).get_child(2).pressed.emit()
	await process_frame
	care.sick = true
	care.changed.emit()
	_expect(not hud.menu.jumping and hud.activity.get_child(1).text == care.SICK_MESSAGE and care.coins == before, "Adoecer interrompe Pula EVO sem pagar")

func _fuzz_pula() -> void:
	const Jumper = preload("res://scripts/minigames/pula_evo.gd")
	var input_rng := RandomNumberGenerator.new()
	input_rng.seed = 7001
	var moving := 0
	var fragile := 0
	var springs := 0
	var coins := 0
	for seed_value in 64:
		var game := Jumper.new()
		game.rng.seed = seed_value
		root.add_child(game)
		game.set_physics_process(false)
		game.camera_y = -4200
		game._extend_platforms()
		for ledge in game.platforms:
			moving += int(ledge.moving)
			fragile += int(ledge.fragile)
			springs += int(ledge.spring)
			coins += int(ledge.coin)
		game.player = Vector2(320, -3890)
		for frame in 480:
			game.direction = input_rng.randi_range(-1, 1)
			game._physics_process(input_rng.randf_range(0.008, 0.033))
			if not game.running:
				break
		_expect(game.player.is_finite(), "Simulação de plataformas na semente %d" % seed_value)
		game.free()
	_expect(mini(mini(moving, fragile), mini(springs, coins)) > 0, "Fuzz percorre plataformas especiais, molas e moedas")
	for fragile_ledge in [false, true]:
		var game := Jumper.new()
		root.add_child(game)
		var ledge := game.platforms[0]
		ledge.spring = not fragile_ledge
		ledge.fragile = fragile_ledge
		ledge.coin = true
		game.player = ledge.position + Vector2(game.PLATFORM_WIDTH * 0.5, -1)
		game.speed_y = 120.0
		game._physics_process(1.0 / 60)
		_expect(game.collected == 1 and not game.platforms.has(ledge), "Colisão recolhe moeda aérea e consome plataforma")
		if fragile_ledge:
			_expect(game.speed_y > 0, "Plataforma frágil quebra sem quicar")
		else:
			_expect(is_equal_approx(game.speed_y, game.BOUNCE * 1.6), "Mola aumenta o impulso em 60%")
		game.free()
	var idle := Jumper.new()
	idle.rng.seed = 17
	root.add_child(idle)
	for frame in 7200:
		idle._physics_process(1.0 / 60)
		if not idle.running:
			break
	_expect(not idle.running and idle.payout(idle.height, idle.elapsed, idle.steered) == 0, "Partida ociosa completa rende zero")
	idle.free()

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
