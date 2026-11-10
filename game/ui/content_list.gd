class_name ContentList
extends VBoxContainer
## Shared game collection view. Adapters supply data, never their own paging rules.
## Row: id, title, detail, meta, category, icon (optional Texture2D).
## Optional presentation: card(row) -> Control, min_height, unit. Paging/search stay shared.
var states := {}
var key := ""
var rows: Array = []
var columns := 2
var capacity := 2
var row_height := 116.0
var filtered: Array = []
var _signature := ""
var _filters: HBoxContainer
var _category: OptionButton
var _search: LineEdit
var _status: Label
var _body: Control
var _footer: HBoxContainer
var _back: Button
var _next: Button
var _count: Label
var _empty := "暂无内容"
var _last_size := Vector2.ZERO
var _presentation := {}

func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_constant_override("separation",6)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	add_theme_font_override("font",font)
	_filters = HBoxContainer.new()
	_filters.add_theme_constant_override("separation",5)
	add_child(_filters)
	_category = OptionButton.new()
	_category.fit_to_longest_item = false
	_category.size_flags_horizontal = SIZE_EXPAND_FILL
	_category.custom_minimum_size.x = 100
	_style(_category)
	_filters.add_child(_category)
	_search = LineEdit.new()
	_search.size_flags_horizontal = SIZE_EXPAND_FILL
	_search.custom_minimum_size.x = 100
	_search.placeholder_text = "搜索…"
	_style(_search)
	_filters.add_child(_search)
	_status = _label("",11,Hud.INK2)
	_status.custom_minimum_size.y = 17
	add_child(_status)
	_body = Control.new()
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	_body.clip_contents = true
	add_child(_body)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation",5)
	add_child(_footer)
	_back = Button.new()
	_back.text = "上一页"
	_style(_back)
	_footer.add_child(_back)
	_count = _label("",12,Hud.INK2)
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_count.custom_minimum_size.y = 18
	_count.size_flags_horizontal = SIZE_EXPAND_FILL
	_footer.add_child(_count)
	_next = Button.new()
	_next.text = "下一页"
	_style(_next)
	_footer.add_child(_next)
	_back.pressed.connect(func(): turn(-1))
	_next.pressed.connect(func(): turn(1))
	_search.text_changed.connect(func(text):
		if key=="": return
		states[key].search = text
		states[key].page = 0
		_render())
	_category.item_selected.connect(func(index):
		if key=="": return
		states[key].category = str(_category.get_item_metadata(index))
		states[key].page = 0
		_render())

func present(collection: String, entries: Array, count_columns := 2, status := "", empty := "暂无内容", categories := true, presentation := {}) -> void:
	key = collection
	columns = count_columns
	rows = entries
	_presentation = presentation
	_empty = empty
	if not states.has(key): states[key] = {"page":0,"search":"","category":""}
	_category.visible = categories
	if not categories: states[key].category = ""
	var tags := []
	for row in rows:
		var category := str(row.get("category",""))
		if category!="" and not category in tags: tags.append(category)
	tags.sort()
	if states[key].category!="" and not states[key].category in tags: states[key].category = ""
	_category.clear()
	_category.add_item("全部")
	_category.set_item_metadata(0,"")
	for tag in tags:
		_category.add_item(tag)
		_category.set_item_metadata(_category.item_count-1,tag)
	_category.select(tags.find(states[key].category)+1)
	if _search.text!=states[key].search: _search.text = states[key].search
	_status.text = status
	_status.visible = status!=""
	_render()

func turn(step: int) -> void:
	if key=="": return
	states[key].page = clampi(int(states[key].page)+step,0,maxi(0,ceili(filtered.size()/float(capacity))-1))
	_render()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or key=="": return
	if _last_size!=_body.size:
		_last_size = _body.size
		_render()

func _render() -> void:
	if not is_inside_tree() or key=="": return
	var state: Dictionary = states[key]
	var query := str(state.search).strip_edges().to_lower()
	filtered = rows.filter(func(row):
		return (state.category=="" or row.get("category","")==state.category) and (query=="" or query in (str(row.get("title",""))+" "+str(row.get("detail",""))+" "+str(row.get("meta",""))+" "+str(row.get("category",""))).to_lower()))
	var min_height := float(_presentation.get("min_height",100.0 if columns==1 else 116.0))
	var slots := maxi(1,floori((_body.size.y+5.0)/(min_height+5.0)))
	capacity = slots*columns
	row_height = maxf(1,(_body.size.y-(slots-1)*5.0)/slots)
	var pages := maxi(1,ceili(filtered.size()/float(capacity)))
	state.page = clampi(int(state.page),0,pages-1)
	_count.text = "%d / %d · 共 %d %s" % [state.page+1,pages,filtered.size(),str(_presentation.get("unit","项"))]
	_back.disabled = state.page==0
	_next.disabled = state.page>=pages-1
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if filtered.is_empty():
		var empty_label := _label("没有符合的内容" if query!="" or state.category!="" else _empty,13,Hud.INK2)
		empty_label.size.x = _body.size.x
		empty_label.size.y = 42
		_body.add_child(empty_label)
		return
	var width := (_body.size.x-(columns-1)*5.0)/columns
	var entries := filtered.slice(state.page*capacity,(state.page+1)*capacity)
	for i in entries.size():
		var factory: Callable = _presentation.get("card",Callable())
		var card: Control = factory.call(entries[i]) if factory.is_valid() else _card(entries[i])
		card.position = Vector2((i%columns)*(width+5),int(i/columns)*(row_height+5))
		card.size = Vector2(width,row_height)
		_body.add_child(card)

func _card(row: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.clip_contents = true
	card.add_theme_stylebox_override("panel",_box(Hud.PAPER_H,Hud.PAPER_D,1,6))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",3)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	if row.get("icon") is Texture2D:
		var icon := TextureRect.new()
		icon.texture = row.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32,32)
		head.add_child(icon)
	var title := _label(str(row.get("title","")),13,Hud.INK)
	title.max_lines_visible = 2
	title.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(title)
	var detail := _label(str(row.get("detail","")),12,Hud.INK2)
	detail.max_lines_visible = 2
	detail.visible = detail.text!=""
	box.add_child(detail)
	var meta := _label(str(row.get("meta","")),11,Hud.WOOD)
	meta.max_lines_visible = 1
	meta.visible = meta.text!=""
	box.add_child(meta)
	return card

func _label(text: String, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",pixels)
	label.add_theme_color_override("font_color",color)
	return label

func _box(color: Color, border: Color, width: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(padding)
	return box

func _style(control: Control) -> void:
	control.add_theme_font_size_override("font_size",13)
	for state in ["normal","hover","pressed","focus"]: control.add_theme_stylebox_override(state,_box(Hud.PAPER_H,Hud.WOOD_L,1,4))
	for state in ["font_color","font_hover_color","font_pressed_color","font_placeholder_color","caret_color"]: control.add_theme_color_override(state,Hud.INK)
	control.add_theme_color_override("font_disabled_color",Hud.INK2)
