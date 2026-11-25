extends Control
## 小屋用量手账: daily model-token usage per resident and per activity, in the Cabin World paper-and-wood style.
## Read-only accounting: opening this page never asks a model anything. Data: VadsLink panel.get "tokens"
## {who, day} -> {day, rows:[{id,name,requests,promptTokens,completionTokens,cacheHitTokens,totalTokens,unknownCalls}],
## totals, hasRecords, notes}; residents from panel.get "tokenResidents". The previous day is fetched too, for the
## day-over-day change. Layout redesigned 2026-11-11 (handover/token-ui-20261111).

const BOTH := "__both__"
const SORTS := [["total","按总量"],["calls","按调用"],["cache","按未命中量"]] ## 未命中量 = input that was billed as new (not served from the cache): where caching could still save
const BAR_CACHED := Color("9db64a") ## input served from the cache
const BAR_FRESH := Color("f0a64a") ## new (uncached) input
const BAR_OUTPUT := Color("a96f3b") ## model output
const CACHE_GOOD := 80.0
const CACHE_OK := 50.0

var ids: Array = []
var names: Dictionary = {}
var who := ""          ## a resident id, or BOTH to compare
var sort_by := "total"
var sets: Dictionary = {}  ## resident id -> {"day": data, "prev": data}
var pending: Dictionary = {} ## request id -> [resident id, "day"|"prev"]
var people_request := ""
var remaining := 0.0

var day: LineEdit
var status: Label
var chips: HBoxContainer
var sort_row: HBoxContainer
var tiles: VBoxContainer
var rows_box: VBoxContainer
var header_row: HBoxContainer
var notes: Label
var notes_button: Button
var scroll: ScrollContainer

# ---------- building ----------
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new();shade.color = Color(0.05,0.08,0.15,0.65);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	shade.gui_input.connect(func(e):if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:close())
	var sheet := PanelContainer.new();sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.offset_left = -560;sheet.offset_right = 560;sheet.offset_top = -380;sheet.offset_bottom = 380
	sheet.add_theme_stylebox_override("panel",box(Hud.PAPER,Hud.WOOD,4,20,10));add_child(sheet)
	theme = make_theme()
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",10);sheet.add_child(column)
	# title row
	var head := HBoxContainer.new();head.add_theme_constant_override("separation",10);column.add_child(head)
	var title := label(head,"小屋 · 用量手账",26);title.size_flags_horizontal = SIZE_EXPAND_FILL
	label(head,"北京时间 · 只读记录，不是费用账单",13,Hud.INK2).size_flags_vertical = SIZE_SHRINK_CENTER
	button(head,"关闭",close)
	# who + day
	var controls := HBoxContainer.new();controls.add_theme_constant_override("separation",8);column.add_child(controls)
	chips = HBoxContainer.new();chips.add_theme_constant_override("separation",6);chips.size_flags_horizontal = SIZE_EXPAND_FILL;controls.add_child(chips)
	for person in Residents.people():
		ids.append(person.key);names[person.key] = person.name
	who = ids[0] if not ids.is_empty() else ""
	build_chips()
	button(controls,"‹ 前一天",func():move_day(-1))
	day = LineEdit.new();day.custom_minimum_size.x = 132;day.max_length = 10;day.alignment = HORIZONTAL_ALIGNMENT_CENTER;day.text = today();controls.add_child(day)
	day.text_submitted.connect(func(_t):refresh())
	button(controls,"后一天 ›",func():move_day(1))
	button(controls,"今天",func():day.text = today();refresh())
	# summary tiles (one row per shown resident)
	tiles = VBoxContainer.new();tiles.add_theme_constant_override("separation",8);column.add_child(tiles)
	status = label(column,"",13,Hud.INK2);status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# activity table
	var table_head := HBoxContainer.new();table_head.add_theme_constant_override("separation",8);column.add_child(table_head)
	label(table_head,"活动明细",19).size_flags_horizontal = SIZE_EXPAND_FILL
	sort_row = HBoxContainer.new();sort_row.add_theme_constant_override("separation",4);table_head.add_child(sort_row)
	build_sorts()
	header_row = HBoxContainer.new();column.add_child(header_row)
	scroll = ScrollContainer.new();scroll.size_flags_vertical = SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	rows_box = VBoxContainer.new();rows_box.size_flags_horizontal = SIZE_EXPAND_FILL;rows_box.add_theme_constant_override("separation",4);scroll.add_child(rows_box)
	# legend + notes
	var foot := HBoxContainer.new();foot.add_theme_constant_override("separation",14);column.add_child(foot)
	legend(foot,BAR_CACHED,"缓存命中的输入");legend(foot,BAR_FRESH,"新输入");legend(foot,BAR_OUTPUT,"输出")
	var gap := Control.new();gap.size_flags_horizontal = SIZE_EXPAND_FILL;foot.add_child(gap)
	label(foot,"缓存命中 ≥%d%% 绿 · %d–%d%% 黄 · 更低 红" % [CACHE_GOOD,CACHE_OK,CACHE_GOOD],12,Hud.INK2).size_flags_vertical = SIZE_SHRINK_CENTER
	notes_button = button(foot,"说明 ▸",func():notes.visible = not notes.visible;notes_button.text = "说明 ▾" if notes.visible else "说明 ▸")
	notes = label(column,"",12,Hud.INK2);notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;notes.visible = false
	VadsLink.panel_arrived.connect(receive)
	if VadsLink.connected:
		people_request = "token-people:"+str(Time.get_ticks_usec())
		VadsLink.send({"type":"panel.get","panel":"tokenResidents","id":people_request})
	refresh()

func make_theme() -> Theme:
	var t := Theme.new();var font := SystemFont.new();font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"]);t.default_font = font;t.default_font_size = 15
	for kind in ["Label","Button","LineEdit"]:
		for c in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:t.set_color(c,kind,Hud.INK)
	for kind in ["Button","LineEdit"]:
		t.set_stylebox("normal",kind,box(Hud.PAPER_H,Hud.WOOD_L,2,6,6));t.set_stylebox("hover",kind,box(Hud.PAPER_D,Hud.WOOD_L,2,6,6))
		t.set_stylebox("pressed",kind,box(Hud.PAPER_D,Hud.WOOD,2,6,6));t.set_stylebox("focus",kind,box(Hud.PAPER_H,Hud.WOOD,2,6,6))
	return t

func build_chips() -> void:
	for c in chips.get_children():c.queue_free()
	var options := ids.duplicate()
	if ids.size() > 1:options.append(BOTH)
	for key in options:
		var chip := Button.new();chip.text = "两位一起" if key == BOTH else str(names.get(key,key))
		if key == who:chip.add_theme_stylebox_override("normal",box(Hud.GOLD,Hud.WOOD,2,6,12));chip.add_theme_stylebox_override("hover",box(Hud.GOLD,Hud.WOOD,2,6,12))
		chip.pressed.connect(func():who = key;build_chips();refresh());chips.add_child(chip)

func build_sorts() -> void:
	for c in sort_row.get_children():c.queue_free()
	for s in SORTS:
		var b := Button.new();b.text = s[1];b.add_theme_font_size_override("font_size",13)
		if s[0] == sort_by:b.add_theme_stylebox_override("normal",box(Hud.GOLD,Hud.WOOD,2,4,10))
		b.pressed.connect(func():select_tab(s[0]));sort_row.add_child(b)

func select_tab(key: String) -> void:
	sort_by = key;build_sorts();render()

# ---------- data ----------
func today() -> String:return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system())+28800)
func shift(text: String, days: int) -> String:return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(text+"T00:00:00")+days*86400)
func valid_day() -> bool:
	var regex := RegEx.new();regex.compile("^\\d{4}-\\d{2}-\\d{2}$")
	if not regex.search(day.text):return false
	# Check the calendar first: the engine prints an error for impossible dates such as 02-30.
	var parts := day.text.split("-");var year := int(parts[0]);var month := int(parts[1]);var date := int(parts[2])
	var leap: bool = year%4 == 0 and (year%100 != 0 or year%400 == 0)
	if year < 1 or month < 1 or month > 12 or date < 1 or date > [31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31][month-1]:return false
	var stamp := Time.get_unix_time_from_datetime_string(day.text+"T00:00:00")
	return stamp > 0 and Time.get_date_string_from_unix_time(stamp) == day.text
func move_day(delta: int) -> void:
	if not valid_day():status.text = "请填写有效日期，例如 2026-11-11。";return
	day.text = shift(day.text,delta);refresh()
func shown() -> Array:return ids.duplicate() if who == BOTH else ([who] if who != "" else [])
func refresh() -> void:
	sets.clear();pending.clear();remaining = 0;render()
	if not valid_day():status.text = "请填写有效日期，例如 2026-11-11。";return
	if not VadsLink.connected:status.text = "请先连接机器人软件，再查询用量。";return
	if ids.is_empty():status.text = "还没有机器人。";return
	for key in shown():
		sets[key] = {}
		for which in ["day","prev"]:
			var id := "tokens:%s:%s:%d" % [key,which,Time.get_ticks_usec()];pending[id] = [key,which]
			VadsLink.send({"type":"panel.get","panel":"tokens","id":id,"who":key,"day":day.text if which == "day" else shift(day.text,-1)})
	remaining = 12;status.text = "正在读取用量账本…"
func receive(frame: Dictionary) -> void:
	var id := str(frame.get("id",""))
	if people_request != "" and id == people_request:
		people_request = ""
		if frame.get("ok",false) and frame.get("data",{}).get("residents",[]) is Array:
			var keep := who;ids.clear();names.clear()
			for person in frame.data.residents:
				var key := str(person.get("id",""))
				if Residents.person(key).is_empty() or ids.has(key):continue
				ids.append(key);names[key] = str(person.get("name",key))
			who = keep if (keep == BOTH and ids.size() > 1) or ids.has(keep) else (ids[0] if not ids.is_empty() else "")
			build_chips()
		return
	if not pending.has(id):return
	var target: Array = pending[id];pending.erase(id)
	if frame.get("ok",false) and frame.get("data") is Dictionary:sets.get(target[0],{})[target[1]] = frame.data
	elif target[1] == "day":status.text = str(frame.get("error","读取失败，请重试。"))
	if pending.is_empty():remaining = 0;render()
## Test/preview hook: show prepared data without the host ({resident id: {"day": data, "prev": data}}).
func show_sets(value: Dictionary, mode := "") -> void:
	if mode != "":who = mode;build_chips()
	sets = value;pending.clear();remaining = 0;render()
func show_data(data: Dictionary) -> void:show_sets({who:{"day":data}})

# ---------- rendering ----------
func render() -> void:
	for c in tiles.get_children():tiles.remove_child(c);c.queue_free()
	for c in rows_box.get_children():rows_box.remove_child(c);c.queue_free()
	for c in header_row.get_children():header_row.remove_child(c);c.queue_free()
	var keys := shown().filter(func(k):return sets.has(k) and sets[k].has("day"))
	if keys.is_empty():return
	var both := keys.size() > 1
	var notes_text: Array = ["缓存命中是输入的一部分，不重复加总；总量 = 输入 + 输出。前一天对比按同一北京时间日期。"]
	for key in keys:
		var d: Dictionary = sets[key].day
		summary(key,d,sets[key].get("prev",{}),both)
		for n in d.get("notes",[]):if not notes_text.has(n):notes_text.append(n)
	notes.text = "\n".join(notes_text)
	var first: Dictionary = sets[keys[0]].day
	status.text = "%s · %s" % [str(first.get("day",day.text)),"两位机器人对比（每格先%s后%s）" % [names.get(keys[0],keys[0]),names.get(keys[1],keys[1])] if both else "共 %d 类活动 · 鼠标停在用量条上看精确数字" % first.get("rows",[]).size()]
	if not first.get("hasRecords",false) and not both:status.text = "%s 没有可用记录；不代表实际消耗一定为零。" % str(first.get("day",day.text))
	# activity rows: union of activities across the shown residents
	var by_activity: Dictionary = {}
	for key in keys:
		for row in sets[key].day.get("rows",[]):
			var a := str(row.get("id",row.get("name","")))
			if not by_activity.has(a):by_activity[a] = {"name":str(row.get("name","未分类")),"per":{}}
			by_activity[a].per[key] = row
	var list: Array = by_activity.values()
	var peak := 1
	for a in list:
		for r in a.per.values():peak = maxi(peak,int(r.get("totalTokens",0)))
	list.sort_custom(func(x,y):return sort_value(x) > sort_value(y))
	head_cells(both,keys)
	for a in list:activity_row(a,keys,peak,both)
	if list.is_empty():label(rows_box,"这一天没有活动记录，试试其他日期。",15,Hud.INK2)

func sort_value(a: Dictionary) -> float:
	var t := 0.0;var calls := 0.0;var input := 0.0;var hit := 0.0
	for r in a.per.values():t += float(r.get("totalTokens",0));calls += float(r.get("requests",0));input += float(r.get("promptTokens",0));hit += float(r.get("cacheHitTokens",0))
	if sort_by == "calls":return calls
	if sort_by == "cache":return input-hit # most uncached input first: where a better cache saves the most
	return t

func summary(key: String, d: Dictionary, prev: Dictionary, both: bool) -> void:
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",8);tiles.add_child(row)
	if both:
		var who_label := label(row,str(names.get(key,key)),17);who_label.custom_minimum_size.x = 64;who_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var t: Dictionary = d.get("totals",{});var p: Dictionary = prev.get("totals",{}) if prev.get("hasRecords",false) else {}
	var input := float(t.get("promptTokens",0));var cache := 100.0*float(t.get("cacheHitTokens",0))/input if input > 0 else -1.0
	var pin := float(p.get("promptTokens",0));var pcache := 100.0*float(p.get("cacheHitTokens",0))/pin if pin > 0 else -1.0
	var size_of := 22 if both else 26
	var partial: bool = str(d.get("day",day.text)) == today() # today is not over: compare rates, not amounts
	tile(row,"当日 Token",compact(t.get("totalTokens",0)),change(float(t.get("totalTokens",0)),float(p.get("totalTokens",0)),p.is_empty(),partial),number(t.get("totalTokens",0))+" Token",size_of,1.6)
	tile(row,"模型调用",number(t.get("requests",0))+" 次",change(float(t.get("requests",0)),float(p.get("requests",0)),p.is_empty(),partial," 次"),"",size_of,1.3)
	var cache_tile := tile(row,"输入缓存命中","%.1f%%" % cache if cache >= 0 else "—",points(cache,pcache),"",size_of,1.5)
	if cache >= 0:cache_tile.add_theme_stylebox_override("panel",box(cache_color(cache).lerp(Hud.PAPER_H,0.62),cache_color(cache),2,10,8))
	var out := float(t.get("completionTokens",0))
	var unknown := int(t.get("unknownCalls",0))
	tile(row,"输入 / 输出","%s / %s" % [compact(input),compact(out)],["未返回用量 %d 次" % unknown,Hud.RED] if unknown > 0 else ["",Hud.INK2],"输入 %s（其中缓存命中 %s）· 输出 %s" % [number(input),number(t.get("cacheHitTokens",0)),number(out)],size_of-4,1.4)

func tile(parent: Node, caption: String, value: String, delta: Array, tip: String, size_of: int, stretch: float) -> PanelContainer:
	var card := PanelContainer.new();card.size_flags_horizontal = SIZE_EXPAND_FILL;card.size_flags_stretch_ratio = stretch
	card.add_theme_stylebox_override("panel",box(Hud.PAPER_H,Hud.WOOD_L,2,10,8));card.tooltip_text = tip;parent.add_child(card)
	var c := VBoxContainer.new();c.add_theme_constant_override("separation",0);card.add_child(c)
	label(c,caption,13,Hud.INK2)
	label(c,value,size_of)
	label(c,str(delta[0]) if str(delta[0]) != "" else " ",12,delta[1])
	return card

## Change vs the previous day. For spending (tokens, calls) more is shown red and less green.
func change(now: float, before: float, missing: bool, partial := false, unit := "") -> Array:
	if missing or before <= 0:return ["前一天无记录",Hud.INK2]
	if partial:return ["今天未过完 · 前一天全天 %s%s" % [compact(before) if unit == "" else number(before),unit],Hud.INK2]
	var pct := 100.0*(now-before)/before
	if absf(pct) < 0.5:return ["与前一天持平",Hud.INK2]
	return ["%s %.0f%%（比前一天）" % ["↑" if pct > 0 else "↓",absf(pct)],Hud.RED if pct > 0 else Hud.GRASS_D]
func points(now: float, before: float) -> Array:
	if now < 0 or before < 0:return ["前一天无记录",Hud.INK2]
	var d := now-before
	if absf(d) < 0.1:return ["与前一天持平",Hud.INK2]
	return ["%s %.1f 个百分点（比前一天）" % ["↑" if d > 0 else "↓",absf(d)],Hud.GRASS_D if d > 0 else Hud.RED]

const COLS := {"name":150,"calls":84,"total":110,"share":76,"cache":96}
const COLS_BOTH := {"name":150,"calls":100,"total":160,"share":120,"cache":104}
var cols: Dictionary = COLS
func head_cells(both: bool, keys: Array) -> void:
	cols = COLS_BOTH if both else COLS
	cell(header_row,"活动",cols.name,true,true)
	cell(header_row,"调用",cols.calls,false,true)
	var bar_head := cell(header_row,"   用量构成" if not both else "   用量构成（上：%s · 下：%s）" % [names.get(keys[0],keys[0]),names.get(keys[1],keys[1])],0,true,true);bar_head.size_flags_horizontal = SIZE_EXPAND_FILL
	cell(header_row,"合计",cols.total,false,true)
	cell(header_row,"占比",cols.share,false,true)
	cell(header_row,"缓存命中",cols.cache,false,true)
	var pad := Control.new();pad.custom_minimum_size.x = 14;header_row.add_child(pad) # the rows have a frame of this width

func activity_row(a: Dictionary, keys: Array, peak: int, both: bool) -> void:
	var line := PanelContainer.new();line.add_theme_stylebox_override("panel",box(Hud.PAPER_H,Hud.PAPER_D,1,5,6));rows_box.add_child(line)
	var h := HBoxContainer.new();h.add_theme_constant_override("separation",0);line.add_child(h)
	cell(h,a.name,cols.name,true,false,15)
	var calls := [];var totals := [];var shares := [];var caches := []
	var bars := VBoxContainer.new();bars.size_flags_horizontal = SIZE_EXPAND_FILL;bars.alignment = BoxContainer.ALIGNMENT_CENTER;bars.add_theme_constant_override("separation",3)
	for key in keys:
		var r: Dictionary = a.per.get(key,{})
		var grand := float(sets[key].day.get("totals",{}).get("totalTokens",0))
		calls.append(number(r.get("requests",0)) if not r.is_empty() else "—")
		totals.append(compact(r.get("totalTokens",0)) if not r.is_empty() else "—")
		shares.append("%.1f%%" % (100.0*float(r.get("totalTokens",0))/grand) if grand > 0 and not r.is_empty() else "—")
		var input := float(r.get("promptTokens",0))
		caches.append(100.0*float(r.get("cacheHitTokens",0))/input if input > 0 else -1.0)
		var bar := UsageBar.new();bar.setup(r,peak,both)
		bar.tooltip_text = "%s · %s\n调用 %s 次 · 输入 %s（其中缓存命中 %s）· 输出 %s · 合计 %s" % [str(names.get(key,key)),a.name,number(r.get("requests",0)),number(r.get("promptTokens",0)),number(r.get("cacheHitTokens",0)),number(r.get("completionTokens",0)),number(r.get("totalTokens",0))]
		bars.add_child(bar)
	cell(h," / ".join(calls),cols.calls,false,false)
	h.add_child(bars)
	cell(h," / ".join(totals),cols.total,false,false,15)
	cell(h," / ".join(shares),cols.share,false,false,13,Hud.INK2)
	var chip_box := HBoxContainer.new();chip_box.custom_minimum_size.x = cols.cache;chip_box.alignment = BoxContainer.ALIGNMENT_END;chip_box.add_theme_constant_override("separation",3);h.add_child(chip_box)
	for c in caches:
		var chip := PanelContainer.new();chip.custom_minimum_size.x = 44
		chip.add_theme_stylebox_override("panel",box(cache_color(c).lerp(Hud.PAPER_H,0.55) if c >= 0 else Hud.PAPER_D,cache_color(c) if c >= 0 else Hud.PAPER_D,1,1,8));chip_box.add_child(chip)
		label(chip,"%d%%" % roundi(c) if c >= 0 else "—",13).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func cache_color(pct: float) -> Color:
	if pct >= CACHE_GOOD:return Hud.GRASS
	if pct >= CACHE_OK:return Hud.AMBER
	return Hud.RED

# ---------- small helpers ----------
func cell(parent: Node, text: String, width: int, left: bool, heading: bool, size_of := 14, color := Hud.INK) -> Label:
	var l := label(parent,text,13 if heading else size_of,Hud.INK2 if heading else color);l.custom_minimum_size.x = width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT;l.clip_text = true;l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
func legend(parent: Node, color: Color, text: String) -> void:
	var swatch := ColorRect.new();swatch.color = color;swatch.custom_minimum_size = Vector2(14,10);swatch.size_flags_vertical = SIZE_SHRINK_CENTER;parent.add_child(swatch)
	label(parent,text,12,Hud.INK2).size_flags_vertical = SIZE_SHRINK_CENTER
func label(parent: Node, text: String, size_of := 15, color := Hud.INK) -> Label:
	var l := Label.new();l.text = text;l.add_theme_font_size_override("font_size",size_of);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
func button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new();b.text = text;b.pressed.connect(callback);parent.add_child(b);return b
func box(bg: Color, border: Color, width: int, pad: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new();s.bg_color = bg;s.border_color = border;s.set_border_width_all(width);s.set_corner_radius_all(radius)
	s.content_margin_left = pad+4;s.content_margin_right = pad+4;s.content_margin_top = pad;s.content_margin_bottom = pad;return s
func number(value) -> String:
	var raw := str(int(value));var out := ""
	for i in raw.length():
		if i > 0 and (raw.length()-i)%3 == 0:out += ","
		out += raw[i]
	return out
func compact(value) -> String:
	var v := float(value)
	if v >= 1e6:return "%.2fM" % (v/1e6)
	if v >= 1e4:return "%.0fK" % (v/1e3)
	if v >= 1e3:return "%.1fK" % (v/1e3)
	return str(int(v))
func close() -> void:queue_free()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):close();get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if pending.is_empty():return
	remaining -= delta
	if remaining <= 0:pending.clear();status.text = "读取超时，请确认机器人软件已连接后重试。";render()

## One stacked bar: cached input | new input | output; length relative to the biggest activity on the page.
class UsageBar extends Control:
	var cached := 0.0
	var fresh := 0.0
	var output := 0.0
	var peak := 1.0
	func setup(r: Dictionary, top: int, thin: bool) -> void:
		cached = float(r.get("cacheHitTokens",0));fresh = maxf(0.0,float(r.get("promptTokens",0))-cached);output = float(r.get("completionTokens",0));peak = maxf(1.0,float(top))
		custom_minimum_size = Vector2(120,10 if thin else 18);size_flags_horizontal = SIZE_EXPAND_FILL;size_flags_vertical = SIZE_SHRINK_CENTER;mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var w := size.x-16.0;var h := size.y
		draw_rect(Rect2(8,0,w,h),Color("e2c99f"))
		var x := 8.0
		for part in [[cached,Color("9db64a")],[fresh,Color("f0a64a")],[output,Color("a96f3b")]]:
			var length := w*float(part[0])/peak
			if length > 0:draw_rect(Rect2(x,0,maxf(length,1.0),h),part[1]);x += length
