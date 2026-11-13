extends RefCounted
## Data-driven action poses shared by every avatar using this schema.
static var data={}
static var textures={}
static var menu={}
static func menu_data()->Dictionary:
 if menu.is_empty():menu=JSON.parse_string(FileAccess.get_file_as_string("res://assets/restaurant/menu.json"))
 return menu
static func ready():
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/restaurant/actions.json"))
static func sample(avatar:String,action:String,facing:String,seconds:float)->Dictionary:
 ready()
 var who:Dictionary=data.avatars.get(avatar,{})
 var frames:Array=who.get("actions",{}).get(action,{}).get(facing,[])
 if frames.is_empty():return {}
 var frame:Dictionary=frames[int(floor(maxf(0,seconds)*2))%frames.size()]
 var r:Array=frame.rect
 return {"sheet":frame.get("sheet",who.sheet),"region":Rect2(r[0],r[1],r[2],r[3]),"anchor":Vector2(frame.anchor[0],frame.anchor[1]),"scale":float(frame.get("scale",who.pixel_scale)),"action":action,"facing":facing}
static func resolve(avatar:String,scene:String,zone:String,effect:Dictionary,seconds:float,legacy:Dictionary)->Dictionary:
 var action:String=str(effect.get("kind","")).trim_prefix("restaurant_")
 if not str(effect.get("kind","")).begins_with("restaurant_") or seconds>=float(effect.get("seconds",0)):return legacy
 var room:Dictionary=WorldData.scenes.get(scene,{})
 var facing:String=str(effect.get("facing","north"))
 var at:Vector2
 var depth:float
 var seated:bool=action=="eat"
 if not room.get("zones",{}).has(zone):return legacy
 if not seated:
  var turn:int=["S","W","N","E"].find(str(room.zones[zone].get("furnitureFacing","S")))
  var directions:=["north","east","south","west"]
  if turn>0 and facing in directions:facing=directions[(directions.find(facing)+turn)%4]
 at=WorldData.point(room.zones[zone]);depth=at.y
 if seated:
  var module:Dictionary=room.get("modules",{}).get(str(effect.get("seat","")),{})
  var slot:Dictionary=module.get("sitting",{}).get("slots",{}).get("only",{})
  if slot.is_empty():return legacy
  facing=slot.facing;at=Vector2(module.x+slot.anchor[0],module.y+slot.anchor[1]);depth=at.y
 var pose=sample(avatar,action,facing,seconds)
 if pose.is_empty():return legacy
 return {"restaurant_pose":pose,"feet":at,"sort":depth+.05,"seat":seated,"still":true,"snap":true}
static func texture(file:String)->Texture2D:
 if not textures.has(file):textures[file]=load(file)
 return textures[file]
