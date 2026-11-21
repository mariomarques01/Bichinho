extends Control

const Wardrobe = preload("res://scripts/inventory/wardrobe.gd")
var wardrobe: Wardrobe
var left_eye := Vector2.ZERO
var right_eye := Vector2.ZERO
var wallpaper := false

static func attach(parent: Control, model: Wardrobe, left := Vector2.ZERO, right := Vector2.ZERO) -> Control:
	var art := new()
	art.wardrobe = model
	art.left_eye = left
	art.right_eye = right
	art.wallpaper = left == right
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	model.outfit_changed.connect(art.queue_redraw)
	return art

func _draw() -> void:
	if wallpaper:
		_draw_wallpaper()
		return
	var left := left_eye * size
	var axis := (right_eye - left_eye) * size
	draw_set_transform(left + axis * 0.5, axis.angle(), Vector2.ONE * axis.length())
	var hat: String = wardrobe.equipped.get(Wardrobe.HAT, "")
	if not hat.is_empty():
		var color: Color = Wardrobe.ITEMS[hat][2]
		if hat == "Boina":
			draw_set_transform(left + axis * 0.5, axis.angle(), Vector2(axis.length(), axis.length() * 0.5))
			draw_circle(Vector2(0, -1.7), 0.65, color)
			draw_set_transform(left + axis * 0.5, axis.angle(), Vector2.ONE * axis.length())
		elif hat == "Cartola":
			draw_rect(Rect2(-0.47, -1.48, 0.94, 0.75), color)
		else:
			var crown := PackedVector2Array([
				Vector2(-0.59, -1.28), Vector2(-0.25, -1.04), Vector2(0, -1.46),
				Vector2(0.26, -1.04), Vector2(0.59, -1.28), Vector2(0.47, -0.75), Vector2(-0.47, -0.75)
			])
			draw_colored_polygon(crown, color)
		draw_line(Vector2(-0.66,-0.74), Vector2(0.66,-0.74), color.darkened(0.3), 0.11, true)
	var glasses: String = wardrobe.equipped.get(Wardrobe.GLASSES, "")
	if not glasses.is_empty():
		var rim: Color = Wardrobe.ITEMS[glasses][2]
		draw_line(Vector2(-0.2,0), Vector2(0.2,0), rim, 0.065, true)
		for x in [-0.5, 0.5]:
			var center := Vector2(x, 0)
			if glasses == "Quadrados":
				draw_rect(Rect2(center - Vector2(0.3,0.24), Vector2(0.6,0.48)), rim, false, 0.065)
			else:
				draw_arc(center, 0.30, 0, TAU, 32, rim, 0.065, true)
				if glasses == "Gatinho":
					draw_line(center + Vector2(signf(x)*0.22,-0.20),center + Vector2(signf(x)*0.41,-0.33),rim,0.075,true)

func _draw_wallpaper() -> void:
	var paper: String = wardrobe.equipped.get(Wardrobe.WALL, "")
	if paper.is_empty():
		return
	var color: Color = Wardrobe.ITEMS[paper][2]
	var area := Vector2(size.x, size.y * 0.60)
	draw_rect(Rect2(Vector2.ZERO, area), Color(color, 0.66))
	var ink := Color(color.lightened(0.45), 0.68)
	for x in range(0, int(area.x), 48):
		if paper == "Listras":
			draw_rect(Rect2(x, 0, 12, area.y), ink)
		else:
			for y in range(16, int(area.y) - 8, 40):
				var center := Vector2(x + 15, y)
				if paper == "Bolinhas":
					draw_circle(center, 6, ink)
				else:
					draw_colored_polygon(PackedVector2Array([center + Vector2.UP * 10, center + Vector2.RIGHT * 7, center + Vector2.DOWN * 10, center + Vector2.LEFT * 7]), ink)
