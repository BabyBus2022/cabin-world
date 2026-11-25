extends "res://entities/observer_view_base.gd"

func _input(event:InputEvent)->void:
	if active and is_instance_valid(host) and is_instance_valid(host.qingxi_host):
		var village=host.qingxi_host
		if village.can_observer_edit() and not _editing():
			var rural=village.scene
			if event is InputEventKey and event.physical_keycode==KEY_G:
				return
			if rural.build_mode and event is InputEventKey and event.physical_keycode==KEY_TAB:
				if event.pressed and not event.echo:rural.hotbar.toggle_library()
				get_viewport().set_input_as_handled()
				return
			if event is InputEventMouse:
				if rural.build_mode and not (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE):
					dragging=false
					return
				if is_instance_valid(rural.edit_button) and rural.edit_button.get_global_rect().has_point(rural.get_viewport().get_mouse_position()):return
			if rural.build_mode and event is InputEventKey and event.physical_keycode in [KEY_TAB,KEY_R,KEY_ESCAPE,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9]:return
	super._input(event)

func _place_entry() -> bool:
	var placed := super._place_entry()
	if is_instance_valid(_entry):
		var frame := _frame()
		_entry.position.x = roundf(maxf(frame.position.x,frame.end.x - ENTRY_MARGIN.x - _entry.size.x))
	return placed
