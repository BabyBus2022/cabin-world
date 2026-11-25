extends RefCounted
# UV carries the common root of each leaf, including the drooping grain. Colour stores
# the blade tone, its resting orientation, and whether this triangle is a seed head.
static func make(seed_:int)->ArrayMesh:
 var rng=RandomNumberGenerator.new()
 rng.seed=seed_
 var vertices=PackedVector2Array()
 var roots=PackedVector2Array()
 var tones=PackedColorArray()
 for row in 13:
  for col in 31:
   var root=Vector2(10+col*16+(row%2)*3+rng.randf_range(-2,2),17+row*19+rng.randf_range(-2,2))
   var vigor=rng.randf_range(.83,1.17)
   for blade in 5:
    var fan=(blade-2)*.5
    var stem=Vector2(fan*1.30,0)
    var side=fan*8+rng.randf_range(-2.5,2.5)
    var height=(23-absf(fan)*7+rng.randf_range(-2,2))*vigor
    var mid=Vector2(side*.34,-height*.65)
    var left=mid-Vector2(1.15,.1)
    var right=mid+Vector2(1.15,.1)
    var tip=Vector2(side,-height)
    var tone=.48+.21*fan+rng.randf_range(-.14,.14)
    for offset in [stem,left,right,left,tip,right]:
     vertices.append(root+offset);roots.append(root)
     tones.append(Color(clampf(tone+(-offset.y/height)*.29,0,1),.5+fan*.45,0))
    if blade==2 or blade==3:
     var d=1 if side>=0 else -1
     for grain in 4:
      var head=tip+Vector2(d*(grain+1),grain*grain*.24)
      for offset in [head-Vector2(1.3,1.4),head+Vector2(d*1.5,2.8),head+Vector2(1.5,-.5)]:
       vertices.append(root+offset);roots.append(root);tones.append(Color(.48+.10*grain,.6,1))
 var arrays=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=roots;arrays[Mesh.ARRAY_COLOR]=tones
 var mesh=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

