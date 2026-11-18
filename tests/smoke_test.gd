extends SceneTree

const Main = preload("res://scenes/main/main.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Main.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var evolin: Node3D = game.get_node("Evolin")
	var room: Node3D = game.get_node("Room")
	var hud: CanvasLayer = game.get_node("HUD")
	var camera: Camera3D = room.get_node("Camera")
	var head := evolin.global_position + Vector3(0, 1.42, 0.2)
	_click(Vector2(4, 4))
	await physics_frame
	await process_frame
	_expect(hud.feedback.text.begins_with("Toque"), "Toque fora do Evolin preserva a instrução")
	_click(camera.unproject_position(head))
	await physics_frame
	await process_frame
	_expect(hud.feedback.text.contains("carinho"), "Toque acerta o Evolin e atualiza a interface")
	_expect(_hearts(hud) == 1, "Toque cria um coração")
	_click(camera.unproject_position(head))
	await physics_frame
	await process_frame
	_expect(_hearts(hud) == 1, "Intervalo mínimo limita os efeitos de toques repetidos")
	await create_timer(0.64).timeout
	_expect(_hearts(hud) == 0, "Coração é removido após a animação")
	_drag(camera.unproject_position(head) + Vector2(55, 0))
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
	if failures == 0:
		print("EVO: 12 verificações passaram.")
	quit(1 if failures > 0 else 0)

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
	return hud.get_node("Interface").get_child_count() - 1

func _expect(condition: bool, check: String) -> void:
	if not condition:
		failures += 1
		push_error(check)
