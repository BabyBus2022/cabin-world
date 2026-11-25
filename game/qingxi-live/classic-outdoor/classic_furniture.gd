extends RefCounted
const ROOT="res://qingxi-live/village01/art/classic-furniture/"
var h
var textures={}
func _init(host):h=host
func place(parent:Node3D,id:String,p:Vector3,width_:float,footprint:Vector2,facing="S"):
 var key=id+"/"+facing
 if not textures.has(key):
  var im=Image.load_from_file(ROOT+key+".png")
  textures[key]=ImageTexture.create_from_image(im.get_region(im.get_used_rect()))
 var t=textures[key];var sprite=Sprite3D.new();sprite.name=id+"_"+facing;sprite.texture=t
 var max_height=2.2
 if "counter" in id:max_height=1.25
 elif "sofa" in id:max_height=1.6
 elif "bench" in id:max_height=1.35
 elif "bed" in id:max_height=2.45
 sprite.pixel_size=minf(width_/t.get_width(),max_height/t.get_height());sprite.offset.y=t.get_height()*.5
 sprite.position=p;sprite.rotation_degrees.x=-36.87;sprite.billboard=BaseMaterial3D.BILLBOARD_DISABLED
 sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.5;sprite.shaded=true
 sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;parent.add_child(sprite)
 if footprint.length()>0:h.box(parent,p+Vector3(0,.5,-footprint.y*.5),Vector3(footprint.x,1,footprint.y),Color.WHITE,true).hide()
 return sprite
func home(levels:Array):
 var g=levels[0]
 place(g,"xiaojingyu-home--xj-sofa",Vector3(-5,0,4),1.35,Vector2(1.3,2.5),"E")
 place(g,"xiaojingyu-home--xj-writing_desk",Vector3(-3.8,0,3.2),1.2,Vector2(.7,1.1),"E")
 place(g,"world-restaurant--6",Vector3(-4.8,0,-3.9),1.5,Vector2(1.5,.7))
 place(g,"world-restaurant--7",Vector3(-2.9,0,-3.9),1.5,Vector2(1.5,.7))
 place(g,"world-restaurant--0",Vector3(-4.8,0,-1.8),1.5,Vector2(1.5,1.2))
 place(g,"xiaojingyu-home--xj-album-cabinet",Vector3(1.2,0,4.7),.75,Vector2(.7,.5))
 bathroom(g)
 g=levels[1]
 place(g,"xiaojingyu-home--xj-bed",Vector3(-4.7,0,4),1.85,Vector2(1.75,2.5))
 place(g,"xiaojingyu-home--xj-album-cabinet",Vector3(-2,0,4.7),1.2,Vector2(1.2,.7))
 place(g,"xiaojingyu-home--xj-desk",Vector3(-4.2,0,-3.2),1.6,Vector2(1.6,.9))
 place(g,"xiaojingyu-home--xj-bookshelf",Vector3(-5.5,0,-1.2),.8,Vector2(.6,1.4),"E")
func bathroom(g:Node3D):
 # Retain physical plumbing fixtures where no matching original sprite exists.
 var ivory=Color("e9e8d7");var water=Color("8db7b6")
 h.box(g,Vector3(4.9,.18,-4),Vector3(1.3,.36,1.45),ivory,true)
 for x in [4.29,5.51]:h.box(g,Vector3(x,.44,-4),Vector3(.12,.20,1.45),ivory)
 for z in [-4.67,-3.33]:h.box(g,Vector3(4.9,.44,z),Vector3(1.3,.20,.12),ivory)
 h.box(g,Vector3(4.9,.37,-4),Vector3(1.05,.02,1.18),water)
 h.box(g,Vector3(3.35,.4,-4.6),Vector3(.8,.8,.5),ivory,true)
 h.box(g,Vector3(3.35,.81,-4.6),Vector3(.55,.02,.32),water)
 h.box(g,Vector3(3.35,.95,-4.8),Vector3(.06,.3,.06),Color("b5aaa0"))
 h.box(g,Vector3(2.15,.26,-4.6),Vector3(.5,.52,.55),ivory,true)
func shop(spec:Dictionary,g:Node3D):
 var w=float(spec.width);var d=float(spec.depth)
 place(g,"qianxia-shop--counter",Vector3(-w/2+1.2,0,1.2),1.3,Vector2(1.0,2.2),"E")
 place(g,"qianxia-shop--bread-shelf",Vector3(-1.1,0,-d/2+1),2.3,Vector2(2.3,.7))
 place(g,"qianxia-shop--produce",Vector3(1.3,0,-d/2+1),1.5,Vector2(1.5,.7))
func cottage(g:Node3D):
 place(g,"xiaojingyu-home--xj-bed",Vector3(-2,0,-.8),1.7,Vector2(1.7,2))
 place(g,"xiaojingyu-home--xj-bookshelf",Vector3(1.7,0,-1.3),1.2,Vector2(1.2,.7))
 place(g,"xiaojingyu-home--xj-writing_desk",Vector3(1.7,0,1.4),1.2,Vector2(1.2,.9))

