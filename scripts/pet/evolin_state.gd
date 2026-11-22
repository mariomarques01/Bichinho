extends Node

const Care = preload("res://scripts/needs/care.gd")

signal state_changed(previous: StringName, current: StringName)

const IDLE := &"idle"
const HAPPY := &"feliz"
const SAD := &"triste"
const HUNGRY := &"com_fome"
const DIRTY := &"sujo"
const TIRED := &"cansado"
const EATING := &"comendo"
const BATHING := &"tomando_banho"
const SLEEPING := &"dormindo"
const PLAYING := &"brincando"
const CELEBRATING := &"comemorando"

const REACTION_PRIORITY := {HAPPY: 1, PLAYING: 2, CELEBRATING: 3, EATING: 4, BATHING: 4}

var current := IDLE
var _care: Care
var _reaction: StringName
var _remaining := 0.0

func setup(profile: Care) -> void:
	_care = profile
	_care.changed.connect(refresh)
	refresh()

static func from_needs(needs: Dictionary, resting: bool) -> StringName:
	if resting:
		return SLEEPING
	if needs["Higiene"] <= 35.0:
		return DIRTY
	if needs["Fome"] <= 35.0:
		return HUNGRY
	if needs["Energia"] <= 35.0:
		return TIRED
	if needs["Felicidade"] <= 35.0:
		return SAD
	if needs["Felicidade"] >= 80.0:
		return HAPPY
	return IDLE

func react(target: StringName, seconds: float) -> bool:
	if not _care or _care.rest_end > 0 or seconds <= 0.0 or target not in REACTION_PRIORITY:
		return false
	if REACTION_PRIORITY[target] < REACTION_PRIORITY.get(_reaction, 0):
		return false
	_reaction = target
	_remaining = seconds
	refresh()
	return true

func cancel() -> void:
	_reaction = &""
	_remaining = 0.0
	refresh()

func advance(delta: float) -> void:
	if _remaining > 0.0:
		_remaining -= delta
		if _remaining <= 0.0:
			cancel()

func refresh() -> void:
	var resting: bool = _care.rest_end > 0
	if resting:
		_reaction = &""
		_remaining = 0.0
	var target := _reaction if _remaining > 0.0 else from_needs(_care.needs, resting)
	if target != current:
		var previous := current
		current = target
		state_changed.emit(previous, current)
