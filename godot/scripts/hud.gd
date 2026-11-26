extends CanvasLayer
## On-screen HUD and touch controls. Built in code so there are no scene files to break.

const MPH := 2.23694

var game
var root: Control
var speed_lbl: Label
var limit_lbl: Label
var controls_lbl: Label
var air_lbl: Label
var ym_lbl: Label
var next_lbl: Label
var score_lbl: Label
var strikes_lbl: Label
var toast_lbl: Label
var toast_t: float = 0.0
var btn_line: Button
var btn_zoom: Button
const Quadrant = preload("res://scripts/quadrant.gd")
var q_thr
var q_auto
var q_ind
var q_db
var db_btn: Button
var btn_bell: Button
var btn_sand: Button
var alert_lbl: Label
var force_lbl: Label
var start_panel: Control
var over_panel: Control
var pause_panel: Control
var over_title: Label
var over_msg: Label
var over_score: Label
var best_start_lbl: Label
var ym_panel: PanelContainer
var loco_btns: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 22
	root.theme = th
	add_child(root)
	_build_gauges()
	_build_yardmaster()
	_build_score()
	_build_controls()
	_build_toast()
	_build_start()
	_build_over()
	_build_pause()

# ---------------------------------------------------------------- helpers
func _style(c: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb

func _panel(c: Color = Color(0.02, 0.04, 0.08, 0.62)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(c, 10, Color(1, 1, 1, 0.12)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _label(size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, size: Vector2, cb: Callable, c: Color = Color(0.13, 0.19, 0.3, 0.88), font: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_stylebox_override("normal", _style(c, 12, Color(1, 1, 1, 0.25)))
	b.add_theme_stylebox_override("hover", _style(c.lightened(0.15), 12, Color(1, 1, 1, 0.4)))
	b.add_theme_stylebox_override("pressed", _style(c.darkened(0.3), 12, Color(1, 1, 1, 0.6)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.2, 0.2, 0.2, 0.5), 12))
	b.pressed.connect(cb)
	return b

func _anchor(c: Control, preset: int, ox: float, oy: float, grow_h: int, grow_v: int) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v

# ---------------------------------------------------------------- build
func _build_gauges() -> void:
	var p := _panel()
	_anchor(p, Control.PRESET_TOP_LEFT, 14, 14, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	speed_lbl = _label(46, Color(1, 0.85, 0.3))
	limit_lbl = _label(18, Color(0.8, 0.85, 0.95))
	controls_lbl = _label(20)
	air_lbl = _label(18, Color(0.75, 0.9, 1.0))
	force_lbl = _label(18, Color(0.85, 0.95, 0.8))
	alert_lbl = _label(22, Color(1, 0.35, 0.3))
	alert_lbl.text = "ALERTER - touch a control!"
	alert_lbl.visible = false
	for l in [speed_lbl, limit_lbl, controls_lbl, air_lbl, force_lbl, alert_lbl]:
		v.add_child(l)
	root.add_child(p)

func _build_yardmaster() -> void:
	ym_panel = _panel(Color(0.08, 0.06, 0.02, 0.7))
	_anchor(ym_panel, Control.PRESET_CENTER_TOP, 0, 14, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ym_panel.add_child(v)
	ym_lbl = _label(21, Color(1, 0.92, 0.7))
	ym_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ym_lbl.custom_minimum_size = Vector2(500, 0)
	ym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl = _label(19, Color(0.85, 0.95, 1.0))
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ym_lbl)
	v.add_child(next_lbl)
	root.add_child(ym_panel)

func _build_score() -> void:
	var p := _panel()
	_anchor(p, Control.PRESET_TOP_RIGHT, -14, 14, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	score_lbl = _label(24)
	strikes_lbl = _label(20, Color(1, 0.6, 0.4))
	v.add_child(score_lbl)
	v.add_child(strikes_lbl)
	h.add_child(_button("II", Vector2(64, 64), func(): game.toggle_pause()))
	root.add_child(p)

func _grabber(c: Color) -> ImageTexture:
	var img := Image.create(84, 46, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 46:
		for x in 84:
			var edge := x < 2 or x > 81 or y < 2 or y > 43
			var grip := (y == 15 or y == 23 or y == 31) and x > 14 and x < 70
			img.set_pixel(x, y, Color(0.05, 0.05, 0.05) if edge else (c.darkened(0.45) if grip else c))
	return ImageTexture.create_from_image(img)

func _lever(color: Color, min_v: float, max_v: float, step: float, cb: Callable) -> VSlider:
	var sl := VSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step
	sl.custom_minimum_size = Vector2(88, 270)
	sl.focus_mode = Control.FOCUS_NONE
	var tex := _grabber(color)
	sl.add_theme_icon_override("grabber", tex)
	sl.add_theme_icon_override("grabber_highlight", tex)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.02, 0.03, 0.85)
	track.set_corner_radius_all(6)
	track.content_margin_left = 9
	track.content_margin_right = 9
	sl.add_theme_stylebox_override("slider", track)
	var area := StyleBoxFlat.new()
	area.bg_color = Color(color.r, color.g, color.b, 0.25)
	area.set_corner_radius_all(6)
	area.content_margin_left = 9
	area.content_margin_right = 9
	sl.add_theme_stylebox_override("grabber_area", area)
	sl.add_theme_stylebox_override("grabber_area_highlight", area)
	sl.value_changed.connect(cb)
	return sl

func _lever_col(title: String, sl: VSlider, top_txt: String, bottom_txt: String) -> Array:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var t := _label(15, Color(0.9, 0.9, 0.9))
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var val := _label(17, Color(1, 0.85, 0.35))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tt := _label(12, Color(0.7, 0.75, 0.8))
	tt.text = top_txt
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bt := _label(12, Color(0.7, 0.75, 0.8))
	bt.text = bottom_txt
	bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in [t, val, tt]:
		v.add_child(c)
	sl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sl)
	v.add_child(bt)
	return [v, val]

func _build_controls() -> void:
	var panel := _panel(Color(0.03, 0.04, 0.06, 0.55))
	_anchor(panel, Control.PRESET_BOTTOM_RIGHT, -10, -10, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var horn := _button("HORN", Vector2(84, 58), func(): pass, Color(0.35, 0.3, 0.1, 0.92), 18)
	horn.button_down.connect(func(): game.set_horn(true))
	horn.button_up.connect(func(): game.set_horn(false))
	btn_bell = _button("BELL", Vector2(84, 58), func(): game.toggle_bell(), Color(0.25, 0.25, 0.3, 0.92), 18)
	btn_sand = _button("SAND", Vector2(84, 58), func(): game.toggle_sand(), Color(0.25, 0.25, 0.3, 0.92), 18)
	var bail := _button("BAIL", Vector2(84, 58), func(): game.bail(), Color(0.15, 0.25, 0.45, 0.92), 18)
	for b in [horn, btn_bell, btn_sand, bail]:
		row.add_child(b)
	col.add_child(row)
	var levers := HBoxContainer.new()
	levers.add_theme_constant_override("separation", 6)
	levers.alignment = BoxContainer.ALIGNMENT_CENTER
	q_thr = Quadrant.new()
	q_thr.knob = Color(0.1, 0.1, 0.1)
	q_thr.snap = true
	q_thr.moved.connect(_thr_moved)
	q_db = Quadrant.new()
	q_db.title = "DYN BRAKE"
	q_db.knob = Color(0.1, 0.1, 0.1)
	q_db.snap = true
	var dbn := ["OFF", "SETUP", "1", "2", "3", "4", "5", "6", "7", "8"]
	for k in dbn.size():
		q_db.stops.append([dbn[k], float(k) / 9.0])
	q_db.zones = [[2.0 / 9.0, 1.0, Color(0.95, 0.6, 0.15)]]
	q_db.moved.connect(func(v): game.set_db(int(round(v * 9.0)) - 1))
	q_auto = Quadrant.new()
	q_auto.title = "AUTO BRAKE"
	q_auto.knob = Color(0.72, 0.1, 0.08)
	q_auto.zones = [[0.1, 0.62, Color(0.85, 0.75, 0.2)], [0.66, 0.86, Color(0.6, 0.6, 0.6)], [0.91, 1.0, Color(0.9, 0.15, 0.1)]]
	q_auto.moved.connect(_auto_moved)
	q_ind = Quadrant.new()
	q_ind.title = "IND BRAKE"
	q_ind.knob = Color(0.15, 0.15, 0.15)
	q_ind.stops = [["REL", 0.0], ["", 0.5], ["FULL", 1.0]]
	q_ind.zones = [[0.0, 1.0, Color(0.3, 0.5, 0.9)]]
	q_ind.moved.connect(func(v): game.set_ind(v))
	for q in [q_thr, q_db, q_auto, q_ind]:
		levers.add_child(q)
	col.add_child(levers)
	configure_controls()
	var em := _button("EMERGENCY", Vector2(0, 54), func(): game.emergency_brake(), Color(0.7, 0.05, 0.05, 0.95), 22)
	col.add_child(em)
	root.add_child(panel)
	# left side: view
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	_anchor(lv, Control.PRESET_BOTTOM_LEFT, 16, -16, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	btn_zoom = _button("ZOOM\nSWITCH", Vector2(150, 84), func(): game.toggle_zoom(), Color(0.15, 0.25, 0.4, 0.9), 22)
	lv.add_child(btn_zoom)
	lv.add_child(_button("LOOK\nAHEAD", Vector2(150, 70), func(): _look_ahead(), Color(0.15, 0.25, 0.4, 0.9), 20))
	var al := _button("ALERTER", Vector2(150, 64), func(): game.alerter_reset(), Color(0.85, 0.7, 0.1, 0.95), 20)
	al.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	lv.add_child(al)
	root.add_child(lv)
	# centre: line switch
	btn_line = _button("LINE SWITCH", Vector2(300, 90), func(): game.line_switch(), Color(0.85, 0.5, 0.05, 0.95), 28)
	_anchor(btn_line, Control.PRESET_CENTER_BOTTOM, -150, -20, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	btn_line.visible = false
	root.add_child(btn_line)

func configure_controls() -> void:
	if q_thr == null:
		return
	var split: bool = game.split_db
	q_thr.stops.clear()
	q_thr.zones.clear()
	if split:
		q_thr.title = "THROTTLE"
		var names := ["8", "7", "6", "5", "4", "3", "2", "1", "IDLE"]
		for k in names.size():
			q_thr.stops.append([names[k], float(k) / 8.0])
		q_thr.zones = [[0.0, 1.0, Color(0.2, 0.7, 0.3)]]
	else:
		q_thr.title = "THROTTLE"
		var names2 := ["8", "7", "6", "5", "4", "3", "2", "1", "IDLE", "SETUP", "B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8"]
		for k in names2.size():
			q_thr.stops.append([names2[k], float(k) / 17.0])
		q_thr.zones = [[0.0, 7.0 / 17.0, Color(0.2, 0.7, 0.3)], [10.0 / 17.0, 1.0, Color(0.95, 0.6, 0.15)]]
	q_db.visible = split and game.has_db
	var off_name := "H.OFF" if game.LOCOS[game.loco_model]["brake"] == "26L" else "C.OFF"
	q_auto.title = "AUTO BRAKE " + game.LOCOS[game.loco_model]["brake"]
	q_auto.stops = [["REL", 0.0], ["MIN", 0.1], ["SVC", 0.36], ["FULL", 0.62], ["SUPP", 0.72], [off_name, 0.82], ["EMERG", 1.0]]
	for q in [q_thr, q_db, q_auto]:
		q.queue_redraw()

func _thr_moved(v: float) -> void:
	if game.split_db:
		game.set_throttle(8 - int(round(v * 8.0)))
	else:
		game.set_lever(8 - int(round(v * 17.0)))

func _auto_t(h: float, em: bool) -> float:
	if em:
		return 1.0
	if h < 0.03:
		return 0.0
	if h >= 0.93:
		return 0.82
	if h >= 0.88:
		return 0.72
	return 0.1 + (h - 0.06) / 0.8 * 0.52

func _auto_moved(v: float) -> void:
	if v > 0.91:
		game.emergency_brake()
	elif v >= 0.77:
		game.set_auto(0.95)
	elif v >= 0.67:
		game.set_auto(0.9)
	elif v < 0.05:
		game.set_auto(0.0)
	elif v < 0.1:
		game.set_auto(0.06)
	else:
		game.set_auto(minf(0.86, 0.06 + (v - 0.1) / 0.52 * 0.8))

func _look_ahead() -> void:
	game.look_yaw = 0.0
	game.look_pitch = -0.05
	game.aim_sw = null
	if game.zoomed:
		game.toggle_zoom()

func _build_toast() -> void:
	toast_lbl = _label(30)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.custom_minimum_size = Vector2(700, 0)
	_anchor(toast_lbl, Control.PRESET_CENTER, 0, -40, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	toast_lbl.modulate.a = 0.0
	root.add_child(toast_lbl)

func _overlay() -> Array:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(c)
	var p := _panel(Color(0.05, 0.07, 0.12, 0.95))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	root.add_child(bg)
	return [bg, v]

func _build_start() -> void:
	var o := _overlay()
	start_panel = o[0]
	var v: VBoxContainer = o[1]
	var t := _label(40, Color(1, 0.8, 0.2))
	t.text = "SWITCH CHALLENGE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label(18, Color(0.8, 0.85, 0.95))
	sub.text = "Endless main line  -  read the switches, follow the yardmaster"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var how := _label(15)
	how.custom_minimum_size = Vector2(900, 0)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.text = "- Switch target: GREEN = lined for the MAIN, RED = lined for the siding/spur.\n" \
		+ "- Targets can be knocked wrong. ZOOM and check which point is closed.\n" \
		+ "- If a switch is lined wrong, stop within 500 ft and press LINE SWITCH.\n" \
		+ "- Facing point wrong = wrong route or a wreck. Trailing point wrong = you run through it.\n" \
		+ "- Diverging route limit 25 MPH. Three strikes and you're done.\n" \
		+ "- This is a heavy train: plan your stops. Dynamic brake (pull the throttle below idle) holds speed; air stops you.\n\n" \
		+ "PC: W/S throttle & dynamic, D/A automatic brake, ] / [ independent, B bail, Space emergency,\n" \
		+ "     H horn (hold), G bell, X sand, E line switch, Z zoom, drag the mouse to look.\n" \
		+ "Phone: drag the three levers, hold HORN, drag the view to look, pinch to zoom."
	v.add_child(how)
	best_start_lbl = _label(22, Color(0.7, 1, 0.7))
	best_start_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_start_lbl.text = "Best score: %d" % game.best
	v.add_child(best_start_lbl)
	var pick := HBoxContainer.new()
	pick.alignment = BoxContainer.ALIGNMENT_CENTER
	pick.add_theme_constant_override("separation", 12)
	loco_btns = []
	for opt in [["modern", "MODERN WIDE CAB\nES44AC - desktop"], ["classic", "CLASSIC HOOD UNIT\nshort hood forward"], ["classic_lhf", "CLASSIC HOOD UNIT\nlong hood forward"]]:
		var kind: String = opt[0]
		var lb := _button(opt[1], Vector2(240, 58), func(): _pick_loco(kind), Color(0.15, 0.22, 0.35, 0.95), 15)
		lb.set_meta("kind", kind)
		loco_btns.append(lb)
		pick.add_child(lb)
	v.add_child(pick)
	db_btn = _button("", Vector2(360, 40), func(): game.set_classic_db(not game.classic_db); _update_db_btn(), Color(0.2, 0.2, 0.24, 0.95), 15)
	db_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(db_btn)
	_pick_loco(game.loco_model)
	var b := _button("DEPART", Vector2(280, 66), func(): game.start_game(), Color(0.1, 0.45, 0.2, 0.95), 30)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)

func _update_db_btn() -> void:
	if db_btn == null:
		return
	db_btn.visible = game.loco_model.begins_with("classic")
	db_btn.text = "Classic unit dynamic brake:  " + ("EQUIPPED" if game.classic_db else "NOT EQUIPPED")

func _pick_loco(kind: String) -> void:
	game.set_loco(kind)
	_update_db_btn()
	for lb in loco_btns:
		var on: bool = lb.get_meta("kind") == kind
		lb.add_theme_stylebox_override("normal", _style(Color(0.85, 0.55, 0.1, 0.95) if on else Color(0.15, 0.22, 0.35, 0.95), 12, Color(1, 1, 1, 0.5 if on else 0.25)))

func _build_over() -> void:
	var o := _overlay()
	over_panel = o[0]
	var v: VBoxContainer = o[1]
	over_title = _label(50, Color(1, 0.35, 0.3))
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_msg = _label(22)
	over_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_msg.custom_minimum_size = Vector2(640, 0)
	over_score = _label(28, Color(1, 0.85, 0.3))
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [over_title, over_msg, over_score]:
		v.add_child(l)
	var b := _button("RUN AGAIN", Vector2(300, 90), func(): game.restart(), Color(0.1, 0.45, 0.2, 0.95), 32)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	over_panel.visible = false

func _build_pause() -> void:
	var o := _overlay()
	pause_panel = o[0]
	var v: VBoxContainer = o[1]
	var t := _label(48)
	t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _button("RESUME", Vector2(280, 84), func(): game.toggle_pause(), Color(0.1, 0.45, 0.2, 0.95), 30)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	var q := _button("QUIT GAME", Vector2(280, 70), func(): get_tree().quit(), Color(0.4, 0.1, 0.1, 0.95), 24)
	q.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(q)
	pause_panel.visible = false

# ---------------------------------------------------------------- called by game
func on_start() -> void:
	start_panel.visible = false
	over_panel.visible = false
	pause_panel.visible = false

func set_paused(p: bool) -> void:
	pause_panel.visible = p

func show_game_over(title: String, msg: String, final: int, best: int, new_best: bool) -> void:
	over_title.text = title
	over_msg.text = msg
	over_score.text = ("NEW BEST!  " if new_best else "") + "Score %d   -   Best %d" % [final, best]
	over_panel.visible = true
	toast_lbl.modulate.a = 0.0

func toast(text: String, color: Color = Color.WHITE) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", color)
	toast_t = 2.6

func refresh() -> void:
	var g = game
	var dt := get_process_delta_time()
	speed_lbl.text = "%d MPH" % int(round(g.speed * MPH))
	var over: bool = g.speed * MPH > g.line_max() + 5.0
	limit_lbl.text = "TRACK SPEED %d%s" % [g.line_max(), "   OVERSPEED!" if over else ""]
	limit_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if over else Color(0.8, 0.85, 0.95))
	controls_lbl.text = "%s   AUTO %s   IND %d%%" % [g.lever_name(), g.auto_name(), int(g.ind_h * 100)]
	air_lbl.text = "ER %d  BP %d  BC %d  LOCO %d PSI" % [int(g.er_psi), int(g.bp_psi), int(g.bc_psi), int(g.lbc_psi)]
	var te_kn: float = minf(g.TE_MAX * g.power, g.P_MAX * g.power / maxf(g.speed, 1.5)) / 1000.0
	var db_kn: float = g.DB_MAX * g.dyn / 1000.0
	var ftxt := ("TE %d kN" % int(te_kn)) if te_kn > db_kn else ("DYN %d kN" % int(db_kn))
	if g.sand:
		ftxt += "   SAND"
	if g.bell:
		ftxt += "   BELL"
	force_lbl.text = ftxt
	alert_lbl.visible = g.running and g.alert_t > g.ALERT_WARN and int(g.time_s * 3) % 2 == 0
	if g.split_db:
		q_thr.set_t(float(8 - maxi(g.lever, 0)) / 8.0)
		q_thr.value_text = "N%d" % g.lever if g.lever > 0 else "IDLE"
		q_db.set_t(float((-g.lever - 1) + 1) / 9.0 if g.lever < 0 else 0.0)
		q_db.value_text = "OFF" if g.lever >= 0 else ("SETUP" if g.lever == -1 else "DB%d" % (-g.lever - 1))
	else:
		q_thr.set_t(float(8 - g.lever) / 17.0)
		q_thr.value_text = g.lever_name()
	var ah: float = g.auto_h
	q_auto.set_t(_auto_t(ah, g.emergency))
	q_auto.value_text = "EMERG" if g.emergency else ("REL" if ah < 0.03 else ("H.OFF" if ah >= 0.93 else ("SUPP" if ah >= 0.88 else ("FULL" if ah >= 0.85 else "%d LB" % int(90.0 - g._er_target(ah))))))
	q_ind.set_t(g.ind_h)
	q_ind.value_text = "%d PSI" % int(g.lbc_psi)
	for q in [q_thr, q_db, q_auto, q_ind]:
		q.queue_redraw()
	btn_bell.text = "BELL\nON" if g.bell else "BELL"
	btn_sand.text = "SAND\nON" if g.sand else "SAND"
	score_lbl.text = "SCORE %d" % int(g.score)
	strikes_lbl.text = "STRIKES  " + "X ".repeat(g.strikes) + "- ".repeat(maxi(0, 3 - g.strikes))
	var info: Array = g.yardmaster_info()
	ym_lbl.text = info[0]
	next_lbl.text = info[1]
	ym_panel.visible = info[0] != ""
	next_lbl.visible = info[1] != ""
	var lining: bool = g.lining_sw != null
	btn_line.visible = g.can_line() or lining
	btn_line.disabled = lining
	btn_line.text = "LINING..." if lining else "LINE SWITCH"
	btn_zoom.text = "ZOOM\nOUT" if g.zoomed else "ZOOM\nSWITCH"
	if toast_t > 0.0:
		toast_t -= dt
		toast_lbl.modulate.a = clampf(toast_t / 0.5, 0.0, 1.0)
	else:
		toast_lbl.modulate.a = 0.0
