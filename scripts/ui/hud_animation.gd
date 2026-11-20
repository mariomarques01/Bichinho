extends RefCounted

var shown := {}
var targets := {}
var transitions := {}
var pop_tween: Tween
var popping_icon: Control

func update(owner: Node, key: String, value: float, draw: Callable) -> void:
	if targets.get(key) == value:
		return
	targets[key] = value
	if transitions.has(key):
		transitions[key].kill()
	if not shown.has(key):
		shown[key] = value
		draw.call()
		return
	var tween := owner.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transitions[key] = tween
	tween.tween_method(func(current: float) -> void:
		shown[key] = current
		draw.call()
	, float(shown[key]), value, 0.3)

func pop(icon: Control) -> void:
	if pop_tween:
		pop_tween.kill()
		popping_icon.scale = Vector2.ONE
	popping_icon = icon
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2.ONE
	pop_tween = icon.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(icon, "scale", Vector2.ONE * 1.15, 0.12)
	pop_tween.tween_property(icon, "scale", Vector2.ONE, 0.18)
