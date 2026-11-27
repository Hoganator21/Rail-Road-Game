extends CanvasLayer
## Title screen + main menu. Text floats over the train cinematic: no boxes, no fills.
## Works with mouse, touch, keyboard and controller (D-pad / A / B).

const GAME_TITLE := "HIGH IRON"
const TAGLINE := "AMERICAN  MAIN  LINE  RAILROADING"
const LOCO_ORDER := ["modern", "sd70ace", "classic", "classic_lhf"]
const LOCO_INFO := {
	"modern": ["GE ES44AC", "4,400 hp  -  AC traction  -  wide cab, desktop controls"],
	"sd70ace": ["EMD SD70ACe", "4,300 hp  -  AC traction  -  wide cab, AAR control stand"],
	"classic": ["EMD GP38-2", "2,000 hp road switcher  -  short hood forward"],
	"classic_lhf": ["EMD GP38-2  (LHF)", "2,000 hp road switcher  -  long hood forward"],
}
const TEXT := Color(0.94, 0.92, 0.87, 0.9)
const HOT := Color(1.0, 0.84, 0.52, 1.0)

var game
var root: Control
var bars: Array = []
var fade: ColorRect
var title_lbl: Label
var tag_lbl: Label
var header: Label
var menu: VBoxContainer
var hint: Label
var page := "main"
var stack: Array = []
var t := 0.0
var tsc := 1.0      # title scale: full on the main page, smaller on sub-pages
var f_title: FontVariation
var f_menu: FontVariation
var f_small: FontVariation
# ---- title video clips: res://video/title_01.ogv ... (any count up to 30)
const XFADE := 0.9
var players: Array = []
var clips: Array = []
var clip_queue: Array = []
var cur := 0
var clip_t := 0.0
var clip_len := 9.0
var last_clip := ""

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	f_title = FontVariation.new()
	f_title.base_font = load("res://fonts/Cardo-Bold.ttf")
	f_title.spacing_glyph = 18
	f_menu = FontVariation.new()
	f_menu.base_font = load("res://fonts/Poppins-Medium.ttf")
	f_menu.spacing_glyph = 5
	f_small = FontVariation.new()
	f_small.base_font = load("res://fonts/Poppins-Regular.ttf")
	f_small.spacing_glyph = 2
	# title videos (behind everything else). Two players crossfade between clips.
	for i in 2:
		var vp := VideoStreamPlayer.new()
		vp.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp.expand = true
		vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp.volume_db = -80.0
		vp.modulate.a = 0.0
		root.add_child(vp)
		players.append(vp)
	for i in range(1, 31):
		var path := "res://video/title_%02d.ogv" % i
		if ResourceLoader.exists(path):
			clips.append(path)
	# soft vignette over the picture
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(p * vec2(1.1, 1.35)));
	// soft shade where the menu floats, so text reads over bright sky and fields
	float m = 1.0 - smoothstep(0.0, 0.42, length((p - vec2(0.0, 0.08)) * vec2(0.85, 1.6)));
	float top = 1.0 - smoothstep(0.0, 0.3, UV.y);
	COLOR = vec4(0.02, 0.015, 0.01, clamp(v * 0.75 + m * 0.42 + top * 0.25, 0.0, 0.92));
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	root.add_child(vig)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(b)
		bars.append(b)
	title_lbl = _text(f_title, 92, Color(0.97, 0.93, 0.85), GAME_TITLE)
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 4)
	title_lbl.add_theme_constant_override("shadow_outline_size", 18)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	tag_lbl = _text(f_small, 17, Color(0.9, 0.82, 0.66, 0.85), TAGLINE)
	header = _text(f_small, 17, Color(1, 0.84, 0.52, 0.9), "")
	menu = VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 6)
	root.add_child(menu)
	hint = _text(f_small, 13, Color(0.92, 0.92, 0.9, 1.0), "")
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	visible = false

func _text(font: Font, size: int, col: Color, txt: String) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

# ---------------------------------------------------------------- open / close / layout
func open() -> void:
	visible = true
	t = 0.0
	stack.clear()
	show_page("main")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--title-page="):
			show_page(a.substr(13))
	start_video()

func video_on() -> bool:
	return not clips.is_empty() and bool(game.settings.get("title_video", true)) and visible

func start_video() -> void:
	for vp in players:
		vp.stop()
		vp.modulate.a = 0.0
	if not video_on():
		return
	clip_queue.clear()
	_play_next(true)

func _play_next(first_clip: bool = false) -> void:
	if clip_queue.is_empty():
		clip_queue = clips.duplicate()
		clip_queue.shuffle()
		if clip_queue.size() > 1 and clip_queue[0] == last_clip:
			clip_queue.append(clip_queue.pop_front())
	last_clip = clip_queue.pop_front()
	cur = (cur + 1) % 2 if not first_clip else 0
	var vp: VideoStreamPlayer = players[cur]
	vp.stream = load(last_clip)
	vp.play()
	clip_t = 0.0
	clip_len = vp.get_stream_length()
	if clip_len <= 1.0:
		clip_len = 9.0
	root.move_child(vp, 1)    # newest clip draws on top of the outgoing one

func _video_process(delta: float) -> void:
	if not video_on():
		return
	clip_t += delta
	var vp: VideoStreamPlayer = players[cur]
	var other: VideoStreamPlayer = players[1 - cur]
	vp.modulate.a = clampf(clip_t / XFADE, 0.0, 1.0)
	if vp.modulate.a >= 1.0 and other.is_playing():
		other.stop()
		other.modulate.a = 0.0
	if clip_t >= clip_len - XFADE or not vp.is_playing():
		_play_next()

func close() -> void:
	visible = false
	for vp in players:
		vp.stop()

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	var vw := root.size.x
	var vh := root.size.y
	var bh := maxf(0.0, (vh - vw / 2.39) * 0.5)
	bh = minf(bh, vh * 0.11)
	bars[0].position = Vector2(0, 0)
	bars[0].size = Vector2(vw, bh)
	bars[1].position = Vector2(0, vh - bh)
	bars[1].size = Vector2(vw, bh)
	# the title slowly gathers itself in, letters drawing together
	var k := clampf((t - 0.8) / 3.5, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - k, 3.0)
	var want := 1.0 if page == "main" else 0.6
	if not is_equal_approx(tsc, want):
		tsc = move_toward(tsc, want, delta * 1.6)
		title_lbl.add_theme_font_size_override("font_size", int(92.0 * tsc))
	f_title.spacing_glyph = int(lerpf(34.0, 16.0, ease) * tsc)
	title_lbl.modulate.a = ease
	title_lbl.size = Vector2(vw, 120.0 * tsc)
	title_lbl.position = Vector2(0, bh + vh * 0.04 * tsc + (1.0 - ease) * 10.0)
	tag_lbl.modulate.a = clampf((t - 2.6) / 2.0, 0.0, 1.0) * clampf((tsc - 0.6) / 0.4, 0.0, 1.0)
	tag_lbl.size = Vector2(vw, 24)
	tag_lbl.position = Vector2(0, title_lbl.position.y + 112.0 * tsc)
	var ma := clampf((t - 3.4) / 1.4, 0.0, 1.0)
	menu.modulate.a = ma
	header.modulate.a = ma
	hint.modulate.a = ma * 0.9
	menu.size = Vector2(vw, 0)
	var my := vh * 0.54 - menu.get_combined_minimum_size().y * 0.5 + 20.0
	my = maxf(my, title_lbl.position.y + 120.0 * tsc + (56.0 if header.text != "" else 30.0) - (0.0 if page == "main" else 30.0))
	menu.position = Vector2(0, my)
	header.size = Vector2(vw, 26)
	header.position = Vector2(0, menu.position.y - 42)
	hint.size = Vector2(vw, 20)
	hint.position = Vector2(0, vh - bh - 30)
	_video_process(delta)
	var cut_fade: float = 0.0 if video_on() else game.cine.fade_alpha
	fade.color.a = maxf(cut_fade, 1.0 - clampf(t / 1.5, 0.0, 1.0))
	menu.mouse_filter = Control.MOUSE_FILTER_STOP if ma > 0.5 else Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if t < 3.4 and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		t = 3.4          # skip the slow intro on any press
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- widgets
func _clear() -> void:
	for c in menu.get_children():
		menu.remove_child(c)
		c.queue_free()

func _flat(c: Control) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		c.add_theme_stylebox_override(s, StyleBoxEmpty.new())

func _item(text: String, cb: Callable, enabled: bool = true, size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("base", text)
	b.flat = true
	_flat(b)
	b.add_theme_font_override("font", f_menu)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", HOT)
	b.add_theme_color_override("font_focus_color", HOT)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8, 0.3))
	b.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.7))
	b.add_theme_constant_override("outline_size", 4)
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = not enabled
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	b.focus_entered.connect(func(): b.text = "—    " + str(b.get_meta("base")) + "    —")
	b.focus_exited.connect(func(): b.text = str(b.get_meta("base")))
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	menu.add_child(b)
	return b

func _set_text(b: Button, text: String) -> void:
	b.set_meta("base", text)
	b.text = ("—    " + text + "    —") if b.has_focus() else text

## A "NAME   <  value  >" row: press / right for next, left for previous.
## A "NAME   ‹  value  ›" row. Tap the arrows (or press left/right) to change it;
## tapping the value itself steps forward.
func _choice(label: String, get_v: Callable, step: Callable) -> Button:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	menu.add_child(row)
	var l := _row_label(label)
	row.add_child(l)
	var b := _item("", func(): pass, true, 25)
	menu.remove_child(b)
	b.custom_minimum_size = Vector2(330, 44)
	var refresh := func(): _set_text(b, str(get_v.call()))
	var prev := _arrow("‹", func(): step.call(-1); refresh.call(); _refresh_info())
	var next := _arrow("›", func(): step.call(1); refresh.call(); _refresh_info())
	row.add_child(prev)
	row.add_child(b)
	row.add_child(next)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(l.custom_minimum_size.x, 0)
	row.add_child(pad)
	refresh.call()
	b.pressed.connect(func(): step.call(1); refresh.call(); _refresh_info())
	b.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_right"):
			step.call(1); refresh.call(); _refresh_info(); b.accept_event()
		elif e.is_action_pressed("ui_left"):
			step.call(-1); refresh.call(); _refresh_info(); b.accept_event())
	b.set_meta("refresh", refresh)
	return b

func _row_label(label: String) -> Label:
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f_small)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.84, 0.52, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _arrow(txt: String, cb: Callable) -> Button:
	var a := Button.new()
	a.text = txt
	a.flat = true
	_flat(a)
	a.focus_mode = Control.FOCUS_NONE
	a.custom_minimum_size = Vector2(64, 44)
	a.add_theme_font_override("font", f_menu)
	a.add_theme_font_size_override("font_size", 32)
	a.add_theme_color_override("font_color", TEXT)
	a.add_theme_color_override("font_hover_color", HOT)
	a.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	a.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.7))
	a.add_theme_constant_override("outline_size", 4)
	a.pressed.connect(cb)
	return a

func _slider(label: String, v: float, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	var l := _row_label(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.custom_minimum_size = Vector2(420, 48)
	var grab := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	for y in 30:
		for x in 30:
			var dd := Vector2(x - 14.5, y - 14.5).length()
			grab.set_pixel(x, y, Color(1, 0.86, 0.55, clampf(14.0 - dd, 0.0, 1.0)) if dd < 14.0 else Color(0, 0, 0, 0))
	var gt := ImageTexture.create_from_image(grab)
	s.add_theme_icon_override("grabber", gt)
	s.add_theme_icon_override("grabber_highlight", gt)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := StyleBoxFlat.new()
	line.bg_color = Color(1, 1, 1, 0.25)
	line.content_margin_top = 3
	line.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", line)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.84, 0.52, 0.9)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(1, 0.84, 0.52, 0.6)
	focus.border_width_bottom = 2
	s.add_theme_stylebox_override("focus", focus)
	s.value_changed.connect(cb)
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.add_theme_font_override("font", f_small)
	val.add_theme_font_size_override("font_size", 21)
	val.add_theme_color_override("font_color", TEXT)
	val.text = str(int(round(v * (100.0 if hi <= 1.0 else 1.0))))
	s.value_changed.connect(func(x): val.text = str(int(round(x * (100.0 if hi <= 1.0 else 1.0)))))
	s.mouse_entered.connect(func(): s.grab_focus())
	row.add_child(l)
	row.add_child(s)
	row.add_child(val)
	menu.add_child(row)
	return s

func _note(text: String, size: int = 16, col: Color = Color(0.85, 0.82, 0.76, 0.7)) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", f_small)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 5)
	menu.add_child(l)
	return l

func _gap(h: float = 10.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	menu.add_child(c)

var info_lbl: Label

func _refresh_info() -> void:
	if info_lbl and is_instance_valid(info_lbl):
		if page == "depart":
			info_lbl.text = game.consist_text()
		elif page == "locos":
			info_lbl.text = LOCO_INFO[game.loco_model][1]

# ---------------------------------------------------------------- pages
func show_page(p: String, push: bool = true) -> void:
	if push and page != p and visible and menu.get_child_count() > 0:
		stack.append(page)
	page = p
	info_lbl = null
	_clear()
	hint.text = "ENTER / A  select        ESC / B  back" if p != "main" else "ENTER / A  select"
	match p:
		"main":
			header.text = ""
			if game.has_saved_run():
				_item("CONTINUE", func(): game.continue_run())
			_item("PLAY", func(): show_page("play"))
			_item("LOCOMOTIVES", func(): show_page("locos"))
			_item("SETTINGS", func(): show_page("settings"))
			_item("PROFILE", func(): show_page("profile"))
			if not OS.has_feature("web"):
				_item("QUIT", func(): get_tree().quit())
		"play":
			header.text = "SELECT  MODE"
			_item("SWITCH CHALLENGE", func(): show_page("depart"))
			_note("Read the switches. Follow the yardmaster. How far can you run?")
			_gap(6)
			_item("CAREER", func(): pass, false)
			_note("Coming soon")
			_gap(10)
			_item("BACK", back, true, 25)
		"depart":
			header.text = "SWITCH  CHALLENGE"
			_loco_rows()
			_gap(4)
			_choice("CARS", func(): return game.consist["cars"], func(d): game.set_consist("cars", int(game.consist["cars"]) + 10 * d))
			_choice("LOADING", func(): return str(game.consist["load"]).to_upper(), func(d): _cycle("load", game.LOAD_KINDS, d))
			_choice("DPU", func(): return str(game.consist["dpu"]).to_upper(), func(d): _cycle("dpu", game.DPU_KINDS, d))
			info_lbl = _note(game.consist_text(), 15, Color(0.75, 1.0, 0.8, 0.85))
			var brow := HBoxContainer.new()
			brow.alignment = BoxContainer.ALIGNMENT_CENTER
			brow.add_theme_constant_override("separation", 80)
			var bk := _item("BACK", back, true, 24)
			var dp := _item("DEPART", func(): game.start_switch_challenge(), true, 30)
			for bb in [bk, dp]:
				menu.remove_child(bb)
				brow.add_child(bb)
			menu.add_child(brow)
		"locos":
			header.text = "LOCOMOTIVES"
			_loco_rows()
			info_lbl = _note(LOCO_INFO[game.loco_model][1], 15)
			_gap(4)
			_note("The diesel shop is coming in the next update.", 13, Color(0.8, 0.8, 0.8, 0.5))
			_gap(8)
			_item("BACK", back, true, 25)
		"settings":
			header.text = "SETTINGS"
			_item("AUDIO", func(): show_page("audio"))
			_item("DISPLAY", func(): show_page("display"))
			_gap(8)
			_item("BACK", back, true, 25)
		"audio":
			header.text = "AUDIO"
			var st: Dictionary = game.settings
			_slider("MASTER", st["vol_master"], 0.0, 1.0, 0.05, func(v): game.set_setting("vol_master", v))
			_slider("LOCOMOTIVE", st["vol_engine"], 0.0, 1.0, 0.05, func(v): game.set_setting("vol_engine", v))
			_slider("HORN & BELL", st["vol_horn"], 0.0, 1.0, 0.05, func(v): game.set_setting("vol_horn", v))
			_slider("AMBIENCE", st["vol_ambient"], 0.0, 1.0, 0.05, func(v): game.set_setting("vol_ambient", v))
			_gap(8)
			_item("BACK", back, true, 25)
		"display":
			header.text = "DISPLAY"
			_choice("GRAPHICS", func(): return game.quality_name(), func(d): game.cycle_quality(d))
			_slider("FIELD OF VIEW", game.settings["fov"], 55.0, 90.0, 1.0, func(v): game.set_setting("fov", v))
			if not OS.has_feature("mobile"):
				_choice("FULLSCREEN", func(): return "ON" if game.settings["fullscreen"] else "OFF", func(_d): game.set_setting("fullscreen", not game.settings["fullscreen"]))
			if not clips.is_empty():
				_choice("TITLE BACKGROUND", func(): return "VIDEO" if game.settings["title_video"] else "LIVE 3D", func(_d): game.set_setting("title_video", not game.settings["title_video"]))
			_choice("SHOW FPS", func(): return "ON" if game.settings["show_fps"] else "OFF", func(_d): game.set_setting("show_fps", not game.settings["show_fps"]))
			_gap(8)
			_item("BACK", back, true, 25)
		"profile":
			header.text = "PROFILE"
			var le := LineEdit.new()
			le.text = str(game.profile["name"])
			le.placeholder_text = "Your name"
			le.alignment = HORIZONTAL_ALIGNMENT_CENTER
			le.max_length = 20
			le.custom_minimum_size = Vector2(360, 44)
			le.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			le.add_theme_font_override("font", f_menu)
			le.add_theme_font_size_override("font_size", 24)
			le.add_theme_color_override("font_color", HOT)
			var ul := StyleBoxFlat.new()
			ul.bg_color = Color(0, 0, 0, 0.0)
			ul.border_color = Color(1, 0.84, 0.52, 0.6)
			ul.border_width_bottom = 2
			for sname in ["normal", "focus", "read_only"]:
				le.add_theme_stylebox_override(sname, ul)
			le.text_changed.connect(func(s): game.set_profile_name(s))
			_note("ENGINEER", 12, Color(0.9, 0.8, 0.6, 0.7))
			menu.add_child(le)
			_gap(6)
			var pr: Dictionary = game.profile
			_note("Best score  %s        Runs  %d        Miles run  %.1f" % [game._commas(game.best), int(pr["runs"]), float(pr["miles"])], 16, Color(0.9, 0.9, 0.85, 0.85))
			_gap(6)
			_item("SIGN IN", func(): game.title_toast("Cloud sign-in is coming soon. Progress saves on this device for now."), true, 20)
			_note("Google Play Games and Steam accounts will sync your progress across devices.", 13, Color(0.8, 0.8, 0.8, 0.5))
			_gap(8)
			_item("BACK", back, true, 25)
	_focus_first.call_deferred()

func _loco_rows() -> void:
	_choice("LOCOMOTIVE", func(): return LOCO_INFO[game.loco_model][0], func(d):
		var i := LOCO_ORDER.find(game.loco_model)
		game.set_loco(LOCO_ORDER[(i + d + LOCO_ORDER.size()) % LOCO_ORDER.size()])
		_rebuild_rows())
	_choice("UNITS", func(): return game.consist["units"], func(d): game.set_consist("units", (int(game.consist["units"]) - 1 + d + 4) % 4 + 1))
	if game.loco_model.begins_with("classic"):
		_choice("DYNAMIC BRAKE", func(): return "EQUIPPED" if game.classic_db else "NOT EQUIPPED", func(_d): game.set_classic_db(not game.classic_db))

## Changing locomotive can add/remove the dynamic brake row, so rebuild the page.
func _rebuild_rows() -> void:
	var keep := page
	show_page.call_deferred(keep, false)

func _cycle(key: String, kinds: Array, d: int) -> void:
	var i := kinds.find(game.consist[key])
	game.set_consist(key, kinds[(i + d + kinds.size()) % kinds.size()])

func _focus_first() -> void:
	for c in menu.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			return
		if c is HBoxContainer:
			for cc in c.get_children():
				if cc is HSlider or (cc is Button and cc.focus_mode != Control.FOCUS_NONE):
					cc.grab_focus()
					return

func back() -> void:
	if stack.is_empty():
		return
	show_page(stack.pop_back(), false)

func toast(msg: String) -> void:
	_note(msg, 14, Color(1, 0.84, 0.52, 0.9))
