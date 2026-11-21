extends RefCounted

const TRACKED := ["Fome", "Higiene", "Felicidade"]
var stage := "Filhote"
var form := ""
var illnesses := 0
var weight := 0.0
var averages := {}

func sample(before: Dictionary, after: Dictionary, seconds: float) -> void:
	weight += seconds
	for key: String in TRACKED:
		var midpoint := (float(before[key]) + float(after[key])) * 0.5
		var previous := float(averages.get(key, midpoint))
		averages[key] = previous + (midpoint - previous) * seconds / weight

func update(level: int) -> void:
	if level >= 10 and stage != "Adulto":
		stage = "Adulto"
		var mean: float = (averages.Fome + averages.Higiene + averages.Felicidade) / 3.0
		form = "Aurora" if mean >= 70 and illnesses <= 1 else "Crepúsculo"
	elif level >= 5 and stage == "Filhote":
		stage = "Jovem"

func size_factor() -> float:
	if stage == "Adulto":
		return 1.15 if form == "Aurora" else 1.09
	return 1.05 if stage == "Jovem" else 1.0

func tint() -> Color:
	if stage == "Adulto":
		return Color("#ffe49a") if form == "Aurora" else Color("#d0a3ff")
	return Color("#c1ffe8") if stage == "Jovem" else Color.WHITE

func restore(file: ConfigFile, needs: Dictionary, sick: bool) -> void:
	stage = file.get_value("evolution", "stage", "Filhote")
	form = file.get_value("evolution", "form", "")
	illnesses = maxi(0, file.get_value("evolution", "illnesses", int(sick)))
	weight = maxf(1.0, file.get_value("evolution", "weight", 1.0))
	for key: String in TRACKED:
		averages[key] = clampf(file.get_value("evolution", key, needs[key]), 0, 100)

func save(file: ConfigFile) -> void:
	file.set_value("evolution", "stage", stage)
	file.set_value("evolution", "form", form)
	file.set_value("evolution", "illnesses", illnesses)
	file.set_value("evolution", "weight", weight)
	for key: String in TRACKED:
		file.set_value("evolution", key, averages[key])
