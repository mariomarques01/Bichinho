extends Node

signal changed

const SAVE_VERSION := 2
const FOODS := {"Maçã": 15, "Banana": 20, "Frutas vermelhas": 12, "Sanduíche": 35, "Biscoito": 10}
const MEDICINE := "Remédio"
const SICK_MESSAGE := "Evolin está doente. Use um remédio para voltar a brincar."
const DECAY := {"Fome": 0.12, "Higiene": 0.08, "Energia": 0.10, "Felicidade": 0.07}
var evolution := preload("res://scripts/evolution/evolution.gd").new()
var wardrobe := preload("res://scripts/inventory/wardrobe.gd").new()
var save_path := "user://care-v1.cfg"
var needs := {"Fome": 68.0, "Higiene": 72.0, "Energia": 62.0, "Felicidade": 70.0}
var stock := {"Maçã": 3, "Banana": 2, "Frutas vermelhas": 2, "Sanduíche": 1, "Biscoito": 2, MEDICINE: 0}
var sick := false
var low_seconds := {"Fome": 0.0, "Higiene": 0.0}
var coins := 30
var xp := 0
var bonus_day := -1
var daily_wins := 0
var rest_end := 0
var last_update := 0
var last_affection := 0
var discoveries: Array[String] = []

func _ready() -> void:
	var file := ConfigFile.new()
	var migrated := false
	if file.load(save_path) == OK:
		if int(file.get_value("care", "version", 0)) < SAVE_VERSION:
			_migrate_save(file)
			migrated = true
		for key: String in needs:
			needs[key] = clampf(float(file.get_value("needs", key, needs[key])), 0, 100)
		for key: String in stock:
			stock[key] = maxi(0, int(file.get_value("stock", key, stock[key])))
		wardrobe.restore(file.get_value("care", "wardrobe", {}))
		sick = bool(file.get_value("care", "sick", false))
		for key: String in low_seconds:
			low_seconds[key] = maxf(0.0, float(file.get_value("low_seconds", key, 0.0)))
		coins = maxi(0, int(file.get_value("care", "coins", coins)))
		bonus_day = int(file.get_value("care", "bonus_day", -1))
		daily_wins = clampi(int(file.get_value("care", "daily_wins", 0)), 0, 3)
		xp = maxi(0, int(file.get_value("care", "xp", xp)))
		rest_end = int(file.get_value("care", "rest_end", 0))
		last_update = int(file.get_value("care", "last_update", 0))
		last_affection = int(file.get_value("care", "last_affection", 0))
		discoveries.assign(file.get_value("care", "discoveries", []))
	evolution.restore(file, needs, sick)
	evolution.update(level_progress(xp).x)
	advance(now())
	if migrated or not file.has_section("evolution"):
		_save()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: advance(now()))
	add_child(timer)

func _migrate_save(file: ConfigFile) -> void:
	var utc_day := int(file.get_value("care", "bonus_day", -1))
	if utc_day >= 0:
		# V1 stored the UTC day but omitted the exact time of the win.
		var day_start := utc_day * 86400
		var saved_at := int(file.get_value("care", "last_update", now()))
		var estimate := clampi(saved_at, day_start, day_start + 86399)
		file.set_value("care", "bonus_day", _local_day(estimate))

func _local_day(timestamp: int, bias_minutes: int = Time.get_time_zone_from_system().bias) -> int:
	return (timestamp + bias_minutes * 60) / 86400

func now() -> int:
	return int(Time.get_unix_time_from_system())

func advance(at: int) -> void:
	if last_update <= 0:
		last_update = at
		_save()
	if at <= last_update:
		return
	var before_decay := needs.duplicate()
	var sleeping := maxi(0, mini(at, rest_end) - last_update)
	var elapsed := minf((at - last_update) / 60.0, 360.0)
	var duration := float(at - last_update)
	var onset := 0.0 if sick else INF
	var was_sick := sick
	for key: String in low_seconds:
		var before_low := float(low_seconds[key])
		var until_low := maxf(0.0, (float(needs[key]) - 15.0) * 60.0 / float(DECAY[key]))
		if needs[key] - elapsed * DECAY[key] < 15.0:
			var exposure_start := maxf(sleeping, snappedf(until_low, 0.000001))
			low_seconds[key] = before_low + duration - exposure_start
			if low_seconds[key] > 1800.0:
				onset = minf(onset, exposure_start + maxf(0.0, 1800.0 - before_low))
				sick = true
		else:
			low_seconds[key] = 0.0
	var visible_change := sick != was_sick
	for key: String in needs:
		var before := roundi(needs[key])
		if key == "Energia":
			_adjust(key, sleeping / 60.0 * 0.75)
			_adjust(key, -minf((at - last_update - sleeping) / 60.0, 360.0) * DECAY[key])
		elif key == "Felicidade" and sick:
			var sick_minutes := maxf(0.0, elapsed - onset / 60.0)
			_adjust(key, -(elapsed + sick_minutes) * DECAY[key])
		else:
			_adjust(key, -elapsed * DECAY[key])
		if roundi(needs[key]) != before:
			visible_change = true
	evolution.sample(before_decay, needs, minf(duration, 360.0 * 60.0))
	if sick and not was_sick:
		evolution.illnesses += 1
	last_update = at
	if rest_end > 0 and at >= rest_end:
		rest_end = 0
		_save()
		visible_change = true
	elif sick != was_sick:
		_save()
	if visible_change:
		changed.emit()

func _adjust(key: String, amount: float) -> void:
	needs[key] = clampf(float(needs[key]) + amount, 0.0, 100.0)

func feed(food: String) -> String:
	if not FOODS.has(food):
		return ""
	if stock[food] <= 0:
		return "Sem estoque"
	if rest_end > 0:
		return "Evolin está descansando."
	if needs["Fome"] >= 99.0:
		return "Evolin já está de barriga cheia."
	advance(now())
	stock[food] -= 1
	_adjust("Fome", FOODS[food])
	if needs["Fome"] >= 15.0:
		low_seconds["Fome"] = 0.0
	_gain_xp(5)
	_commit()
	return "Evolin comeu %s!" % food.to_lower()

func use_medicine() -> String:
	advance(now())
	if stock[MEDICINE] == 0:
		return "Sem estoque"
	if not sick:
		return "Evolin está saudável."
	stock[MEDICINE] -= 1
	sick = false
	low_seconds["Fome"] = 0.0
	low_seconds["Higiene"] = 0.0
	_commit()
	return "Evolin está curado!"

func buy(food: String) -> String:
	if not stock.has(food):
		return ""
	var price := 15 if food == MEDICINE else 5
	if coins < price:
		return "Você precisa de %d moedas para repor." % price
	coins -= price
	stock[food] += 1
	_commit()
	return "%s no inventário." % food

func wash() -> void:
	if needs["Higiene"] >= 99.0:
		return
	advance(now())
	_adjust("Higiene", 32)
	low_seconds["Higiene"] = 0.0
	_gain_xp(8)
	_commit()

func rest(minutes: int) -> bool:
	if rest_end > 0 or minutes not in [30, 60, 180]:
		return false
	advance(now())
	rest_end = now() + minutes * 60
	_commit()
	return true

func wake() -> void:
	advance(now())
	rest_end = 0
	_commit()

func affection() -> void:
	if now() - last_affection < 15 or needs["Felicidade"] >= 99.0:
		return
	last_affection = now()
	_adjust("Felicidade", 5)
	_gain_xp(2)
	_commit()

# Level, XP earned within this level, XP required to finish it.
static func level_progress(total_xp: int) -> Vector3i:
	var level := 1
	var remaining := maxi(0, total_xp)
	var required := 50
	while remaining >= required:
		remaining -= required
		level += 1
		required = roundi(50.0 * pow(level, 1.4))
	return Vector3i(level, remaining, required)

func _gain_xp(amount: int) -> void:
	var previous := level_progress(xp).x
	xp += amount
	for level in range(previous + 1, level_progress(xp).x + 1):
		coins += level * 10

func played(score: int) -> int:
	if sick or score <= 0:
		return 0
	var day := _local_day(now())
	if day > bonus_day:
		bonus_day = day
		daily_wins = 0
	var reward := clampi(score, 1, 6)
	if day == bonus_day and daily_wins < 3:
		reward += 2
		daily_wins += 1
	coins += reward
	_gain_xp(12)
	_adjust("Felicidade", 12)
	_commit()
	return reward

func mix(ingredients: Array[String]) -> String:
	if sick:
		return SICK_MESSAGE
	var sorted := ingredients.duplicate()
	sorted.sort()
	var key := "+".join(sorted)
	var recipes := {"Cristal+Folha": "Brilho de Orvalho", "Fruta+Folha": "Néctar do Bosque", "Cristal+Fruta": "Faísca Rosa"}
	if not recipes.has(key):
		return "Escolha dois ingredientes."
	var result: String = recipes[key]
	if key in discoveries:
		return "%s · já descoberto" % result
	discoveries.append(key)
	coins += 6
	_gain_xp(10)
	_commit()
	return "Descoberta: %s!" % result

func _commit() -> void:
	evolution.update(level_progress(xp).x)
	_save()
	changed.emit()

func _save() -> void:
	var file := ConfigFile.new()
	for key: String in needs:
		file.set_value("needs", key, needs[key])
	for key: String in stock:
		file.set_value("stock", key, stock[key])
	for key: String in low_seconds:
		file.set_value("low_seconds", key, low_seconds[key])
	file.set_value("care", "sick", sick)
	file.set_value("care", "wardrobe", wardrobe.snapshot())
	file.set_value("care", "version", SAVE_VERSION)
	file.set_value("care", "coins", coins)
	file.set_value("care", "xp", xp)
	file.set_value("care", "bonus_day", bonus_day)
	file.set_value("care", "daily_wins", daily_wins)
	file.set_value("care", "rest_end", rest_end)
	file.set_value("care", "last_update", last_update)
	file.set_value("care", "last_affection", last_affection)
	file.set_value("care", "discoveries", discoveries)
	evolution.save(file)
	var error := file.save(save_path)
	if error != OK:
		push_warning("Não foi possível salvar o progresso do Evolin.")
