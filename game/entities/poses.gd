class_name Poses
extends RefCounted
## Qianxia's calibrated body poses and how they animate. Numbers come from the art itself, measured in atlas pixels.
## Every pose is drawn at one size: HEAD_WIDTH room units across the head, feet on the given point.

const HEAD_WIDTH := 35.0
## Bed atlas numbers were measured on a 1280-wide sheet; they scale with the real width.
const BED_MEASURED_WIDTH := 1280.0
const FILES := {"computer": "computer-atlas.png", "accessories": "accessories-atlas.png", "bed": "bed-atlas.png", "frames": "actor-frames.png"}

## name: [sheet, x, y, w, h, head x, head y, head w, head h, foot x, foot y]
const TABLE := {
	"phone0": ["accessories", 73, 475, 411, 498, 60, 0, 278, 225, 205, 498],
	"phone1": ["accessories", 557, 475, 410, 498, 60, 0, 278, 225, 205, 498],
	"listen": ["accessories", 1054, 474, 399, 499, 60, 0, 280, 225, 199, 499],
	"sit0": ["computer", 109, 577, 383, 391, 80, 0, 227, 200, 191, 391],
	"edge": ["bed", 72, 448, 322, 370, 47, 0, 221, 180, 161, 370],
	"climbing": ["bed", 486, 452, 324, 358, 76, 0, 223, 180, 162, 358],
	"lying": ["bed", 863, 430, 368, 387, 74, 0, 254, 180, 184, 387],
	"sleeping": ["bed", 57, 846, 363, 391, 59, 0, 244, 180, 181, 391],
	"waking": ["bed", 452, 848, 365, 390, 69, 0, 228, 180, 182, 390],
	"idle0": ["frames", 0, 0, 362, 500, 67, 22, 266, 222, 186, 492],
	"blink": ["frames", 362, 0, 362, 500, 65, 22, 266, 222, 184, 492],
	"draw0": ["frames", 0, 500, 280, 280, 62, 10, 156, 129, 140, 272],
	"draw1": ["frames", 280, 500, 280, 280, 62, 10, 156, 129, 140, 272],
	"draw2": ["frames", 560, 500, 280, 280, 62, 10, 156, 129, 140, 272],
	"draw3": ["frames", 840, 500, 280, 280, 62, 10, 156, 129, 140, 272],
	"read0": ["frames", 1120, 500, 280, 280, 60, 10, 161, 133, 140, 272],
	"read1": ["frames", 1400, 500, 280, 280, 60, 10, 161, 133, 140, 272],
	"read2": ["frames", 1680, 500, 280, 280, 60, 10, 161, 133, 140, 272],
	"read3": ["frames", 0, 780, 280, 280, 60, 10, 161, 133, 140, 272],
	"write0": ["frames", 280, 780, 280, 280, 62, 10, 157, 130, 140, 272],
	"write1": ["frames", 560, 780, 280, 280, 62, 10, 157, 130, 140, 272],
	"write2": ["frames", 840, 780, 280, 280, 62, 10, 157, 130, 140, 272],
	"write3": ["frames", 1120, 780, 280, 280, 62, 10, 157, 130, 140, 272],
}
static var _textures := {}


static func texture(file: String) -> Texture2D:
	if not _textures.has(file):
		_textures[file] = load("res://assets/actors/" + file)
	return _textures[file]


static func sheet(pose: String) -> Texture2D:
	return texture(FILES[TABLE[pose][0]])


static func region(pose: String) -> Rect2:
	var p: Array = TABLE[pose]
	var r := Rect2(p[1], p[2], p[3], p[4])
	return Rect2(r.position * _factor(pose), r.size * _factor(pose))


static func scale_of(pose: String) -> float:
	return HEAD_WIDTH / float(TABLE[pose][7]) / _factor(pose)


static func foot(pose: String) -> Vector2:
	var p: Array = TABLE[pose]
	return Vector2(p[9], p[10]) * _factor(pose)


## Where the head is, relative to the feet, in room units.
static func head(pose: String) -> Rect2:
	var p: Array = TABLE[pose]
	var k := HEAD_WIDTH / float(p[7])
	return Rect2((float(p[5]) - float(p[9])) * k, (float(p[6]) - float(p[10])) * k, HEAD_WIDTH, float(p[8]) * k)


static func _factor(pose: String) -> float:
	return texture(FILES["bed"]).get_width() / BED_MEASURED_WIDTH if TABLE[pose][0] == "bed" else 1.0


static func _noise(n: float) -> float:
	var x := sin(n * 127.1 + 311.7) * 43758.5453
	return x - floorf(x)


## What a pose looks like at this moment. Answers pose (a TABLE name), breathe (upward shift of the upper body), flip.
static func moment(base: String, zone: String, screen: String, audio: String, time: float) -> Dictionary:
	var breath := 0.5 if sin(time * 1.6) > 0.6 else 0.0
	var blinking := fmod(time, 3.7) < 0.14
	if base.begins_with("phone"):
		var burst := _noise(floorf(time / 1.6)) > 0.35
		return {"pose": "phone1" if burst and _noise(floorf(time * 5.0)) > 0.45 else "phone0", "breathe": breath}
	if base == "listen":
		return {"pose": base, "breathe": (0.5 if sin(time * TAU * 1.8) > 0.2 else 0.0) if audio == "playing" else breath}
	if base == "sit0":
		# Same seated body; the shoulders move a little while typing.
		var typing := screen == "typing" or screen == "web"
		var busy := typing and _noise(floorf(time / 1.2)) > 0.3 and int(floorf(time * 7.0)) % 2 == 1
		return {"pose": base, "breathe": 0.5 if busy else breath}
	if base == "write0":
		const ORDER := [0, 1, 2, 3, 2, 1]
		var pausing := fmod(time, 6.0) > 4.6
		return {"pose": "write0" if pausing else "write%d" % ORDER[int(floorf(time * 4.0)) % ORDER.size()], "breathe": 0.0}
	if base == "draw0":
		const STROKES := [0, 1, 2, 3, 3, 2, 1, 0]
		return {"pose": "draw%d" % STROKES[int(floorf(time * 3.0)) % STROKES.size()], "breathe": 0.0}
	if base == "read0":
		return {"pose": "read%d" % (int(floorf(time * 0.8)) % 4), "breathe": 0.0}
	if base == "idle0":
		return {"pose": "blink" if blinking else "idle0", "breathe": breath, "flip": zone == "shared"}
	return {"pose": base, "breathe": 0.0}
