extends RefCounted
## One coordinate contract for the map editor, furniture editor and furniture maker.
## UI zoom never changes these values. Art pixels are not world pixels.
const CELL:int=32
const ART_SCALE:int=2
const ART_CELL:int=CELL*ART_SCALE
static func pixels(cells:Vector2)->Vector2:return cells*CELL
static func cell_at(point:Vector2,origin:Vector2=Vector2.ZERO)->Vector2i:return Vector2i(((point-origin)/CELL).floor())
static func footprint(width:int,depth:int,face:String="S")->Vector2i:return Vector2i(depth,width) if face in ["W","E"] else Vector2i(width,depth)
