class_name GiftPose
extends RefCounted
## Two eight-frame rows per action, shared by every configured resident.
## This is presentation only: Economy commits the item transfer before the received animation.
static var sheets := {}

static func sheet(actor: String) -> Dictionary:
	var file: String = Residents.person(actor).get("gift_art", "")
	if file == "": return {}
	if sheets.has(file): return sheets[file]
	var tex: Texture2D = load(file)
	var image := tex.get_image()
	var cell := Vector2i(image.get_width() / 4, image.get_height() / 4)
	var anchors := []
	var height := 1.0
	for i in range(16):
		var part := image.get_region(Rect2i(Vector2i(i % 4, i / 4) * cell, cell))
		var used := part.get_used_rect()
		height = maxf(height, used.size.y)
		var bottom := maxi(used.position.y, used.end.y - 12)
		var shoes := part.get_region(Rect2i(0, bottom, cell.x, used.end.y - bottom)).get_used_rect()
		anchors.append(Vector2(shoes.position.x + shoes.size.x / 2.0, used.end.y))
	sheets[file] = {"texture":tex, "cell":Vector2(cell), "anchors":anchors, "scale":68.0 / height}
	return sheets[file]

static func frame(status: String, giver: bool, elapsed: float) -> int:
	if elapsed < 0.0 or elapsed >= 3.2: return -1
	if status == "offered": return mini(4, int(elapsed * 8.0)) if giver else -1
	if status == "received": return mini(7, 4 + int(elapsed * 4.0)) if giver else 8 + mini(7, int(elapsed * 5.0))
	return maxi(0, 6 - int(elapsed * 5.0)) if giver else -1
