extends RefCounted
# Shared Tuantuan identity. Each row keeps one crop and scale across its poses.
const ROLES=["种子商贩","农夫","鱼塘向导"]
const ROUTES=[
	[Vector2(530,558),Vector2(573,577)],
	[Vector2(744,557),Vector2(831,593),Vector2(893,524),Vector2(811,501)],
	[Vector2(415,607),Vector2(493,638),Vector2(519,605)]]
var world
var rows=[]
var actors=[]
func _init(host):
	world=host
	var image=world.full_image("tuantuan-villagers.png")
	var cell=Vector2i(image.get_width()/4,image.get_height()/3)
	for row in 3:
		var pieces=[];var bounds=Rect2i()
		for column in 4:
			var piece=image.get_region(Rect2i(Vector2i(column,row)*cell,cell));pieces.append(piece)
			var lo=cell;var hi=Vector2i.ZERO
			for y in cell.y:
				for x in cell.x:
					if piece.get_pixel(x,y).a>0.5:lo=lo.min(Vector2i(x,y));hi=hi.max(Vector2i(x,y))
			var used=Rect2i(lo,hi-lo+Vector2i.ONE)
			bounds=used if column==0 else bounds.merge(used)
		var textures=[]
		for piece in pieces:textures.append(ImageTexture.create_from_image(piece.get_region(bounds)))
		rows.append(textures)
func reset():actors.clear()
func spawn():
	for i in 3:
		var node=Node2D.new();node.position=ROUTES[i][0];world.scenery.add_child(node)
		var shadow=Polygon2D.new();var points=PackedVector2Array()
		for j in 10:points.append(Vector2(cos(j*TAU/10)*11,sin(j*TAU/10)*3))
		shadow.polygon=points;shadow.color=Color(0.16,0.20,0.15,0.22);node.add_child(shadow)
		var sprite=Sprite2D.new();sprite.centered=false;sprite.material=world.light_material();node.add_child(sprite)
		var tag=world.world_label("团团 · "+ROLES[i],Vector2.ZERO);tag.reparent(node);tag.position=Vector2(-64,-60)
		actors.append({"node":node,"sprite":sprite,"tag":tag,"next":1,"pause":float(i),"phase":0.0})
		world.targets.append({"kind":"villager","pos":node.position,"name":"团团 · "+ROLES[i],"extra":str(i)})
	tick(0)
func tick(dt:float):
	for i in actors.size():
		var a:Dictionary=actors[i];var frame=0
		var near=a.node.position.distance_to(world.player.position)<64
		if near:frame=3
		elif a.pause>0:a.pause=maxf(0,a.pause-dt)
		else:
			var delta:Vector2=ROUTES[i][a.next]-a.node.position
			if delta.length()<3:
				a.next=(a.next+1)%ROUTES[i].size();a.pause=3.0+i
			else:
				var step:Vector2=delta.normalized()*minf(dt*19,delta.length())
				if not world.blocked(a.node.position+step):a.node.position+=step
				a.phase+=dt*5;frame=1+int(a.phase)%2;a.sprite.flip_h=delta.x>0
		if frame==0 or frame==3:a.sprite.flip_h=false
		var texture:Texture2D=rows[i][frame]
		# Straw hat extends the silhouette upwards; it does not shrink the body.
		var factor=(49.0 if i==1 else 46.0)/rows[i][0].get_height()
		a.sprite.texture=texture;a.sprite.scale=Vector2.ONE*factor
		a.sprite.position=Vector2(-texture.get_width()*factor/2,-texture.get_height()*factor)
		a.tag.visible=a.node.position.distance_to(world.player.position)<110
		for target in world.targets:
			if target.kind=="villager" and target.extra==str(i):target.pos=a.node.position
