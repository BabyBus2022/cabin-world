extends SceneTree
func _initialize():
 var image=Image.load_from_file("res://qingxi-live/ranch-life/art/barn-source.png")
 image.convert(Image.FORMAT_RGBA8)
 for y in image.get_height():
  for x in image.get_width():
   var color=image.get_pixel(x,y);color.a=1.0 if color.a>=.65 else 0.0;image.set_pixel(x,y,color)
 image=image.get_region(image.get_used_rect())
 image.resize(544,roundi(544.0*image.get_height()/image.get_width()),Image.INTERPOLATE_NEAREST)
 image.save_png("res://qingxi-live/ranch-life/art/barn-exterior.png")
 print("BARN_ART ",image.get_size());quit()
