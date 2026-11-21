extends RefCounted

signal outfit_changed

const HAT := "Chapéu"
const GLASSES := "Óculos"
const WALL := "Papel de parede do quarto"
const ITEMS := {
	"Boina": [HAT, 20, Color("#ec7979")],
	"Cartola": [HAT, 40, Color("#7761ad")],
	"Coroa": [HAT, 60, Color("#ffce56")],
	"Redondos": [GLASSES, 20, Color("#73d8c1")],
	"Quadrados": [GLASSES, 35, Color("#568ddc")],
	"Gatinho": [GLASSES, 50, Color("#dc689c")],
	"Listras": [WALL, 20, Color("#9184c8")],
	"Bolinhas": [WALL, 40, Color("#74ada6")],
	"Losangos": [WALL, 60, Color("#b87ba0")],
}

var owned: Array[String] = []
var equipped := {}

func select(item: String, care: Node) -> String:
	if not ITEMS.has(item):
		return ""
	var category: String = ITEMS[item][0]
	if item not in owned:
		var price: int = ITEMS[item][1]
		if care.coins < price:
			return "Moedas insuficientes."
		care.coins -= price
		owned.append(item)
	if equipped.get(category) == item:
		equipped.erase(category)
	else:
		equipped[category] = item
	care._commit()
	outfit_changed.emit()
	return ""

func restore(data: Dictionary) -> void:
	owned.clear()
	equipped.clear()
	for item in data.get("owned", []):
		if ITEMS.has(item) and item not in owned:
			owned.append(item)
	var worn: Dictionary = data.get("equipped", {})
	for item in owned:
		var category: String = ITEMS[item][0]
		if worn.get(category) == item:
			equipped[category] = item

func snapshot() -> Dictionary:
	return {"owned": owned, "equipped": equipped}
