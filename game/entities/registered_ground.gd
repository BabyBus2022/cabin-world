extends Node2D
## Register the painted architectural boundaries onto exact world-grid lines.
## Original source pixels are preserved; only the runtime drawing transform changes.
var texture: Texture2D
var xs: Array
var ys: Array
func _draw() -> void:
	for ix in range(xs.size()-1):
		for iy in range(ys.size()-1):
			var source:=Rect2(xs[ix][0],ys[iy][0],xs[ix+1][0]-xs[ix][0],ys[iy+1][0]-ys[iy][0])
			var target:=Rect2(xs[ix][1],ys[iy][1],xs[ix+1][1]-xs[ix][1],ys[iy+1][1]-ys[iy][1])
			draw_texture_rect_region(texture,target,source)
