extends RefCounted
const HOUSES=[
 {"id":"seed","name":"青芽种子店","at":Vector3(-11,0,-9),"width":7.2,"depth":6.667,"floors":1,"model":"seed"},
 {"id":"livestock","name":"牧铃畜牧店","at":Vector3(5,0,-10),"width":8.4,"depth":7.273,"floors":1,"model":"livestock"},
 {"id":"fish","name":"水畔鱼苗铺","at":Vector3(28,0,-55),"width":6.0,"depth":5.455,"floors":1,"model":"fish"},
 {"id":"home","name":"我的转角小院","at":Vector3(18,0,23),"width":12.0,"depth":10.0,"floors":2,"model":"home"},
 {"id":"resident_a","name":"团团的花篱小屋","at":Vector3(-22,0,17),"width":7.2,"depth":6.667,"floors":1,"model":"cottage"},
 {"id":"resident_b","name":"团团的溪风小屋","at":Vector3(-3,0,30),"width":7.2,"depth":6.667,"floors":1,"model":"cottage"}]
const PATHS=[
 # One village street, a quieter residential lane, and short destination spurs.
 [1.10,Vector2(-72,8),Vector2(-59,7),Vector2(-48,5),Vector2(-29,1),Vector2(-15,0),Vector2(-8,1),Vector2(0,3),Vector2(9,0),Vector2(15,-10),Vector2(19,-27),Vector2(18.5,-36),Vector2(19,-47),Vector2(25,-48),Vector2(28,-50),Vector2(28,-52.27)],
 [.85,Vector2(-29,1),Vector2(-32,13),Vector2(-32,21),Vector2(-29,22),Vector2(-25,25),Vector2(-15,25),Vector2(-10,26),Vector2(-10,35),Vector2(-8,38),Vector2(0,38),Vector2(9,38),Vector2(18,38),Vector2(31,33),Vector2(35,20),Vector2(45,18)],
 [1.05,Vector2(9,0),Vector2(16,6),Vector2(27,9),Vector2(35,15),Vector2(45,18),Vector2(55,17),Vector2(79,17)],
 [.75,Vector2(-15,0),Vector2(-11,-1.4),Vector2(-11,-5.66)],
 [.80,Vector2(9,0),Vector2(5,-2.8),Vector2(5,-6.36)],
 [.65,Vector2(-25,25),Vector2(-22,24),Vector2(-22,20.33)],
 [.65,Vector2(0,38),Vector2(-3,37),Vector2(-3,33.33)],
 [.85,Vector2(18,38),Vector2(18,32),Vector2(18,28)],
 [.65,Vector2(18,38),Vector2(14.5,36),Vector2(14.5,34.06)],
 [.90,Vector2(-48,5),Vector2(-49,14),Vector2(-54,17),Vector2(-58,18)],
 [.80,Vector2(19,-47),Vector2(18.5,-42),Vector2(20,-35),Vector2(28,-32)]]
const AREAS={"village":{"name":"乡村中心","at":Vector3(-2,0.05,3)},"field":{"name":"青芽田地","at":Vector3(-54,0.05,18)},"ranch":{"name":"牧铃牧场","at":Vector3(55,0.05,17)},"pond":{"name":"水畔鱼塘","at":Vector3(28,0.05,-32)},"home":{"name":"我的小院","at":Vector3(18,0.05,32)}}
const PENS={"cow":Rect2(45,0,13,12),"sheep":Rect2(64,1,13,12),"pig":Rect2(54,23,14,12)}
const SHEDS=[Vector3(-18,0,-11),Vector3(12,0,-11),Vector3(-29,0,17),Vector3(6.5,0,31),Vector3(27,0,24),Vector3(70,0,-5),Vector3(-13,0,16),Vector3(-7,0,-17)]
static func footprints()->Array:
 var result=[]
 for s in HOUSES:result.append(Rect2(Vector2(s.at.x-s.width/2,s.at.z-s.depth/2),Vector2(s.width,s.depth)))
 result.append(Rect2(11.95,28,5.1,6.06));result.append(Rect2(17.1,28,7.3,2.2))
 return result
static func area(p:Vector3)->String:
 if p.x< -39:return "field"
 if p.x>40:return "ranch"
 if p.z< -29:return "pond"
 if p.x>8 and p.z>17:return "home"
 return "village"


