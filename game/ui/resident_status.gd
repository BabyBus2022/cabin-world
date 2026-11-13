extends RefCounted
## A location id is navigation data, not human-readable activity text.
static var restaurant:Dictionary={}
static func internal(text:String)->bool:
	var regex:=RegEx.new();regex.compile("^[A-Za-z0-9_-]+$");return regex.search(text)!=null
static func status(action:String,sleeping:bool,caption:String,place:String,scene:String,zone:String,walking:bool)->String:
	if action!="" and not internal(action):return action
	if sleeping:return "正在睡觉"
	if walking:return "正在走路"
	if caption!="" and not internal(caption):return caption
	if restaurant.is_empty():restaurant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/restaurant/zone-names.json"))
	if scene=="world-restaurant":
		for key in [caption,place,zone]:
			if restaurant.has(key):return "在"+str(restaurant[key])
	if place!="" and not internal(place):return "在"+place
	return "在这里待着"
