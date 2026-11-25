extends "res://qingxi-live/seedshop-study/shop.gd"

func _ready():
 process_mode=Node.PROCESS_MODE_DISABLED
 load_character_assets()
 build_interior()

func _notification(_what):pass
