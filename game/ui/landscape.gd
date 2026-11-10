class_name Landscape
extends Control
## The garden behind everything: a fence and grass along the bottom of the window.

const U := 2.0


static func _noise(i: int) -> float:
	var v := sin(i * 127.1 + 311.7) * 43758.5453
	return v - floor(v)


func _draw() -> void:
	var W := size.x
	var H := size.y
	var grass := 14 * U
	var top := H - grass
	var x := 8.0
	while x < W:
		draw_rect(Rect2(x, top - 13 * U, 4 * U, 13 * U), Hud.WOOD_D)
		draw_rect(Rect2(x + U, top - 13 * U, 2 * U, 13 * U), Hud.WOOD)
		draw_rect(Rect2(x + U, top - 13 * U, U, 13 * U), Hud.WOOD_L)
		draw_rect(Rect2(x, top - 14 * U, 4 * U, U), Hud.WOOD_H)
		x += 28 * U
	for ry in [top - 11 * U, top - 6 * U]:
		draw_rect(Rect2(0, ry, W, 2 * U), Hud.WOOD_D)
		draw_rect(Rect2(0, ry, W, U), Hud.WOOD_L)
	draw_rect(Rect2(0, top, W, grass), Hud.GRASS)
	draw_rect(Rect2(0, top, W, U), Hud.GRASS_L)
	draw_rect(Rect2(0, H - 5 * U, W, 5 * U), Hud.GRASS_D)
	draw_rect(Rect2(0, H - 2 * U, W, 2 * U), Hud.DIRT)
	var i := 0
	while i * 9 * U < W:
		var px := i * 9 * U + floorf(_noise(i) * 6.0) * U
		var py := top + floorf(_noise(i + 9) * 5.0) * U
		var kind := int(_noise(i + 21) * 7.0)
		if kind < 3:
			draw_rect(Rect2(px, py - U, U, 2 * U), Hud.GRASS_D)
			draw_rect(Rect2(px + 2 * U, py - 2 * U, U, 3 * U), Hud.GRASS_D)
			draw_rect(Rect2(px + 4 * U, py - U, U, 2 * U), Hud.GRASS_D)
		elif kind < 5:
			var petal: Color = Hud.CREAM if kind == 3 else Hud.PINK
			draw_rect(Rect2(px + U, py - 3 * U, U, 3 * U), Hud.GRASS_D)
			draw_rect(Rect2(px, py - 4 * U, 3 * U, U), petal)
			draw_rect(Rect2(px + U, py - 5 * U, U, 3 * U), petal)
			draw_rect(Rect2(px + U, py - 4 * U, U, U), Hud.GOLD)
		i += 1
