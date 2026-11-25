extends RefCounted
## Baked lookup for an outer map (tools/bake_regions.py), same API as qingxi_data.gd:
## R = road distance, G = water blocks walking, B = distance from water; texels of 2 world px.
var fields:Image
var layout:Dictionary
var buildings=[]
func _init(folder:String):
 fields=Image.load_from_file(folder+"fields.png")
 layout=JSON.parse_string(FileAccess.get_file_as_string(folder+"layout.json"))
func field(p:Vector2)->Color:
 var x=clampi(int(p.x/2),0,fields.get_width()-1);var y=clampi(int(p.y/2),0,fields.get_height()-1)
 return fields.get_pixel(x,y)
func water_blocks(p:Vector2)->bool:return field(p).g8>127
func on_road(p:Vector2,margin=0.0)->bool:return field(p).r8*2.0<=margin
func creek_clearance(p:Vector2)->float:return field(p).b8*2.0
