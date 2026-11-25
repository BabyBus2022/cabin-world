extends "res://qingxi-live/room_private_canvas.gd"

# Built on the same two-pixel wall, window, mat and floor pieces as the farm cottage.
# The narrower shell puts the visible porch directly over the existing southern portal.
const INTERIOR=Rect2(368,398,544,308)
const NORTH=322
func _draw():
	draw_rect(Rect2(0,0,1280,900),VOID)
	floor_planks(INTERIOR)
	draw_rect(Rect2(912,398,40,332),VOID)
	draw_rect(Rect2(360,706,552,24),VOID)
	draw_rect(Rect2(360,NORTH,560,76),PAPER)
	for x in range(376,908,36):
		draw_rect(Rect2(x,NORTH+9,2,44),PAPER_STRIPE)
	draw_rect(Rect2(360,376,560,22),WOOD_MID)
	draw_rect(Rect2(360,374,560,3),WOOD_LIGHT)
	for x in range(372,902,42):
		draw_rect(Rect2(x,383,32,10),Color("805337"))
	draw_rect(Rect2(360,NORTH,560,8),WOOD_DARK)
	for x in [360,616,912]:
		draw_rect(Rect2(x,NORTH,8,76),WOOD_MID)
		draw_rect(Rect2(x,NORTH,2,76),WOOD_LIGHT)
	window(Rect2(492,339,72,34),Color("8da18a"))
	window(Rect2(758,339,72,34),Color("8da18a"))
	painting(Rect2(643,344,32,24),Color("9bb8ba"))
	kitchen_tiles(Rect2(368,398,136,88))
	rug(Rect2(468,523,162,85),Color("a8af83"),Color("838d65"))
	doormat(Rect2(604,680,72,24))
	for x in [360,912]:
		draw_rect(Rect2(x,396,8,316),WOOD_DARK)
		draw_rect(Rect2(x+(6 if x==360 else 0),396,2,312),WOOD_MID)
	for span in [Rect2(360,706,236,8),Rect2(684,706,236,8)]:
		draw_rect(span,WOOD_DARK)
		draw_rect(Rect2(span.position,Vector2(span.size.x,2)),WOOD_MID)
	draw_rect(Rect2(596,705,88,5),Color("947b5b"))
	draw_rect(Rect2(596,710,88,3),Color("735943"))

