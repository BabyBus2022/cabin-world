class_name WeatherBadge
extends Control
## Real Changsha weather, with a small expressive icon drawn in the game's palette.
var font: SystemFont

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei"])
	mouse_filter = Control.MOUSE_FILTER_PASS
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(queue_redraw)
	add_child(timer)

static func kind(condition: String, day: bool) -> String:
	if "雷" in condition: return "storm"
	if "雪" in condition: return "snow"
	if "雨" in condition: return "rain"
	if "雾" in condition: return "fog"
	if "阴" in condition or "云" in condition: return "cloud"
	return "sun" if day else "moon"

func _draw() -> void:
	draw_style_box(_box(), Rect2(Vector2.ZERO, size))
	var now := Time.get_datetime_dict_from_unix_time(int(SharedFeed.now_ms()/1000.0)+8*3600)
	var local = SharedFeed.local_weather
	var fresh: bool = local is Dictionary and SharedFeed.now_ms()>=float(local.get("fetchedAt",0)) and SharedFeed.now_ms()-float(local.get("at",0))<90*60000
	var condition := str(local.get("condition","")) if fresh else "天气待更新"
	_face(kind(condition, now.hour>=6 and now.hour<18) if fresh else "unknown", Vector2(25,23))
	var clock_text := "%02d:%02d" % [now.hour,now.minute] if SharedFeed.clock_synced else "--:--"
	draw_string(font,Vector2(51,30),clock_text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Hud.INK)
	var date := "%02d/%02d · 北京时间" % [now.month,now.day] if SharedFeed.clock_synced else "等待时钟"
	draw_string(font,Vector2(129,19),date,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Hud.INK2)
	var city:=str(local.get("city","城市")) if local is Dictionary else "城市"
	var weather := city+" · " + condition
	if fresh: weather += " %.1f°C" % float(local.get("temperature",0))
	draw_string(font,Vector2(129,36),weather,HORIZONTAL_ALIGNMENT_LEFT,size.x-170,13,Hud.INK)
	var live := VadsLink.connected
	draw_circle(Vector2(size.x-17,15),4,Hud.GREEN if live else Hud.AMBER)
	draw_string(font,Vector2(size.x-33,35),"在线" if live else "离线",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Hud.INK2)
	tooltip_text = city+" · " + date + " " + clock_text + ("\n已连接 " + VadsLink.host_name if live else "\n机器人软件未连接，显示上次收到的数据")
	if fresh: tooltip_text += "\n%s · %.1f°C · 风速 %.1f km/h\n天气来源：%s" % [condition,float(local.get("temperature",0)),float(local.get("wind",0)),str(local.get("source","机器人软件"))]
	else: tooltip_text += "\n城市天气暂未获取或已过期（由机器人软件提供）"
	if fresh:
		var updated := Time.get_datetime_dict_from_unix_time(int(float(local.get("at",0))/1000)+8*3600)
		tooltip_text += "\n最近天气：%02d:%02d" % [updated.hour,updated.minute]

func _box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Hud.PAPER_H
	box.border_color = Hud.WOOD_L
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	return box

func _face(weather: String, at: Vector2) -> void:
	# Rounded cream cloud mascot; unknown stays a neutral cloud, not fake sunshine.
	var cloud := weather in ["cloud","rain","storm","snow","fog","unknown"]
	var cream := Color("fffaf0")
	var outline := Color("b6c4db")
	if weather=="sun":
		for i in 8:
			var d := Vector2.from_angle(i*TAU/8)
			draw_line(at+d*15,at+d*18,Color("efb858"),2,true)
	if cloud:
		for point in [Vector3(-10,2,8),Vector3(-4,-5,10),Vector3(7,-4,9),Vector3(13,3,7)]:
			draw_circle(at+Vector2(point.x,point.y),point.z+1,outline,true,-1,true)
		for point in [Vector3(-10,2,8),Vector3(-4,-5,10),Vector3(7,-4,9),Vector3(13,3,7)]:
			draw_circle(at+Vector2(point.x,point.y),point.z,cream,true,-1,true)
		draw_rect(Rect2(at+Vector2(-10,1),Vector2(23,8)),cream)
	else:
		draw_circle(at,13,Color("efb858") if weather=="sun" else outline,true,-1,true)
		draw_circle(at,12,Color("ffdb81") if weather=="sun" else Color("e1ddf9"),true,-1,true)
		draw_circle(at+Vector2(-4,-6),2,cream,true,-1,true)
	for x in [-5,5]:
		draw_circle(at+Vector2(x,1),1.6,Color("684e50"),true,-1,true)
		draw_circle(at+Vector2(x-.4,.5),.5,cream,true,-1,true)
	for x in [-9,9]: draw_circle(at+Vector2(x,4),2.5,Color("efb8b3"),true,-1,true)
	draw_arc(at+Vector2(0,3),2.5,0,PI,12,Color("87636a"),1.3,true)
	if weather in ["rain","storm"]:
		for x in [-9,1,11]: draw_line(at+Vector2(x,13),at+Vector2(x-1,17),Color("78abcf"),2,true)
	elif weather=="snow":
		for x in [-9,1,11]: draw_circle(at+Vector2(x,15),1.8,Color("8aafd3"),true,-1,true)
	elif weather=="fog":
		for y in [13,17]: draw_line(at+Vector2(-11,y),at+Vector2(11,y),outline,1.5,true)
