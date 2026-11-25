extends RefCounted
const Trial=preload("res://qingxi-live/village-center/flat-build/trial.gd")
const Worker=preload("res://core/farm_edit_view.gd")
const Stay=preload("res://qingxi-live/cottage_lodging.gd")
const Grid=preload("res://qingxi-live/village-center/placement_grid.gd")
const Region=preload("res://qingxi-live/village-center/region.gd")
static func point(arg:String):
 var fields=arg.split("|")
 if fields.size()<3:return null
 var xy=fields[2].split(":")
 if xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():return null
 return Vector2(int(xy[0]),int(xy[1]))

static func run(host,farm,action:String,arg:String,out:Dictionary)->String:
 var parts=arg.split("|")
 var map=str(parts[0]) if parts.size() and parts[0]!="" else "ranch"
 var level=Trial.barn_level(map)
 var private_room=map in ["room_private","room_private_up",Stay.DORM]
 var layout:Dictionary=farm.sim.data.get("layout",{})
 if map!="ranch" and not private_room and level<1:return "请选择自家农场、已建私人小屋或牧场屋的楼层。"
 if private_room and not layout.has("meadow_house"):return "还没有建私人小屋。"
 if map==Stay.DORM and not Stay.data(host.profile_path(Stay.FILE)).get("expanded",false):return "需要先在私人小屋扩建宿舍。"
 if level>0 and not layout.has("meadow_barn"):return "还没有建牧场屋。"
 if level>1:
  var stairs=layout.get("barn_stair",[]) if level==2 else layout.get("barn_stairs",{}).get(Trial.barn_map(level-1),[])
  if stairs.is_empty():return "上层还没有可通行的楼梯。"
 var position=point(arg)
 if action!="edit_catalog" and position==null:return "写 地图|工具|横坐标:纵坐标，可先查看 edit_catalog。"
 var live=host.scene if host.active and is_instance_valid(host.scene) else null
 var use_live=live!=null and live.get("open_meadow")==true and live.get("map_id")==map and live.get("placement")!=null
 var view=live
 var viewport
 var pen_override=Trial.Herd.pen_override.duplicate(true)
 if not use_live:
  viewport=SubViewport.new()
  viewport.size=Vector2i(640,360)
  viewport.disable_3d=true
  viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  host.add_child(viewport)
  view=Worker.new()
  view.edit_map=map
  view.sim=load(host.PASTURE).new()
  view.sim.bind_snapshot(farm.sim.data.duplicate(true))
  viewport.add_child(view)
 var original=view.sim.data.duplicate(true) if not use_live and action!="edit_catalog" else {}
 var result=""
 if action=="edit_catalog":
  var catalog=[]
  for row in view.editor_catalog():
   if (view.editor_tool_available(row[0]) or (row[0]=="water" and map=="ranch")) and not catalog.has(row):catalog.append(row)
  out.text="可用设施（地图|工具|世界像素横:纵；每个农场格 64 像素；田块、小路、水渠可选区：ranch|工具|起点横:纵|0|终点横:纵）："+str(catalog)
 elif not view.world_bounds().has_point(position):result="位置在地图外。"
 else:
  var tool=str(parts[1])
  var direction=clampi(int(parts[3]),0,3) if parts.size()>3 else 0
  var available=view.editor_catalog().any(func(t):return t[0]==tool)
  if not available or (not view.editor_tool_available(tool) and not (map=="ranch" and tool=="water")):result="这里不能使用这种工具。"
  else:
   if parts.size()>4:
    var end=point(map+"|"+tool+"|"+str(parts[4]))
    if end==null or not view.world_bounds().has_point(end):result="终点在地图外或格式错误。"
    elif map!="ranch" or tool not in ["plot","path","channel"]:result="仅田块、小路和水渠可拖动选区。"
    elif tool=="plot":result="ok" if view.edit_plots(view.pond_box(position,end),action=="remove_at")>0 else "选区内没有可修改的田块。"
    else:
     var first=view.ground_tiles.cell(position)
     var last=view.ground_tiles.cell(end)
     var cells={}
     for y in range(mini(first.y,last.y),maxi(first.y,last.y)+1):
      for x in range(mini(first.x,last.x),maxi(first.x,last.x)+1):cells[Vector2i(x,y)]=true
     result=view.ground_tiles.edit(tool,cells,action=="remove_at")
   else:result=edit(view,tool,position,action=="remove_at",direction)
   if result=="ok":
    if not use_live:
     # Only copy the fields the actual edit changed. Keep the player's location and simulation clock.
     var before_layout:Dictionary=farm.sim.data.get("layout",{})
     if not farm.sim.data.has("layout"):farm.sim.data.layout=before_layout
     for key in view.sim.data.layout:
      if key!="meadow_arrival" and original.layout.get(key)!=view.sim.data.layout[key]:
       var changed=view.sim.data.layout[key]
       before_layout[key]=changed.duplicate(true) if changed is Dictionary or changed is Array else changed
     for key in original.layout:
      if not view.sim.data.layout.has(key):before_layout.erase(key)
     for key in ["bag","farm_timers","crops","pond"]:
      if view.sim.data.has(key) and view.sim.data[key]!=original.get(key):farm.sim.data[key]=view.sim.data[key].duplicate(true)
    host._farm_commit(farm)
    out.text=("已收回" if action=="remove_at" else "已布置")+view.tool_name(tool)+"（%s，%s）"%[map,position]
    result=""
   elif result=="":result="该位置没有可操作的物件，农场未改变。"
 if not use_live:
  viewport.free()
  Trial.Herd.pen_override.assign(pen_override)
 return result

static func edit(view,tool:String,p:Vector2,erase:bool,direction:int)->String:
 if Grid.FLOORS.has(tool):return view.placement.paint(tool,p,erase)
 if tool.begins_with("furn:"):return view.placement.edit_furniture(tool,p,erase)
 if tool=="pick" or tool.begins_with("prop:"):
  if tool=="pick" or erase:
   var picked=view.placement.edit_furniture("",p,true)
   if picked!="" or view.region==null:return picked
   return view.region.pick_prop(view.region.prop_at(p))
  if not Region.PROP_NAMES.has(tool.substr(5)):return "未知物件。"
  if view.region==null or view.is_barn_floor():return view.placement.edit_furniture(tool,p,false)
  return view.region.put_prop(tool.substr(5),view.prop_spot(p))
 if view.is_barn_floor():
  if tool=="stairs":
   view.barn_stairs.preview_steps=direction
   return view.barn_stairs.edit(p,erase)
  return view.barn_editor.edit(tool,p,erase)
 if view.map_id!="ranch":return "请在对应场地使用。"
 match tool:
  "water":return view.fill_water(p) if erase else view.change_water(view.pond_box(p,p+Vector2(64,64)))
  "path","channel":return view.ground_tiles.edit(tool,{view.ground_tiles.cell(p):true},erase)
  "bridge":return view.bridges.change(p,erase,mini(direction,2))
  "house_unit":return view.change_house(p,erase)
  "barn_unit":return view.change_barn(p,erase)
  "plot":return "ok" if view.edit_plots(view.pond_box(p,p),erase)>0 else "只能开垦空地或收回空田。"
 if tool in ["fence","gate"] or tool.begins_with("feeder_"):
  var cell=Vector2i((p/64).floor())
  if tool.begins_with("feeder_"):return view.region.take_feeder(cell) if erase else view.region.place_feeder(tool.substr(7),cell)
  return view.region.set_edge(view.nearest_edge(p)[1],"" if erase else tool)
 return "该工具不适用于此处。"
