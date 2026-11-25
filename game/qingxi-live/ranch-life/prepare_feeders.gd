extends SceneTree

const DIR = "res://qingxi-live/village-center/art/regions/props/feeders/"
const WIDTHS = {"chicken": 38, "cow": 72, "pig": 60, "sheep": 56}

func _initialize():
 var preview = Image.create_empty(696, 116, false, Image.FORMAT_RGBA8)
 preview.fill(Color("b8c799"))
 var index = 0
 for kind in WIDTHS:
  var source_path = ProjectSettings.globalize_path(DIR + "sources/" + kind + ".png")
  var source = Image.load_from_file(source_path)
  source.convert(Image.FORMAT_RGBA8)
  var bounds = source.get_used_rect()
  var sprite = source.get_region(bounds)
  var width: int = WIDTHS[kind]
  sprite.resize(width, roundi(float(width) * bounds.size.y / bounds.size.x), Image.INTERPOLATE_LANCZOS)
  for y in sprite.get_height():
   for x in sprite.get_width():
    var pixel = sprite.get_pixel(x, y)
    pixel.a = 1.0 if pixel.a >= .56 else 0.0
    sprite.set_pixel(x, y, pixel)
  sprite = sprite.get_region(sprite.get_used_rect())
  var output = Image.create_empty(sprite.get_width() + 2, sprite.get_height() + 1, false, Image.FORMAT_RGBA8)
  output.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(1, 1))
  var filename = "feeder_" + kind + ".png"
  var saved = output.save_png(DIR + filename)
  if saved != OK or not output.detect_alpha() == Image.ALPHA_BIT:
   push_error("Feeder export failed "+filename)
   quit(1)
   return
  print(filename, " ", output.get_size())
  output.resize(output.get_width() * 2, output.get_height() * 2, Image.INTERPOLATE_NEAREST)
  var position = Vector2i(index * 174 + (174 - output.get_width()) / 2, 98 - output.get_height())
  preview.blend_rect(output, Rect2i(Vector2i.ZERO, output.get_size()), position)
  index += 1
 preview.save_png(DIR + "preview.png")
 quit()
