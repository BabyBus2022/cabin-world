extends Node2D
var points=PackedVector2Array()
func _draw():
	if not points.is_empty():draw_multiline(points,Color(0.17,0.20,0.14,0.24),4.0)
