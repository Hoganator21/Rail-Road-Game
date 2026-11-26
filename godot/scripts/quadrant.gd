extends Control
## On-screen control handle drawn like a real quadrant: a metal plate with
## engraved positions, a slot, and a handle you drag up and down.

signal moved(t: float)

var title: String = ""
var value_text: String = ""
var stops: Array = []            # [label, t]  t = 0 (top) .. 1 (bottom)
var zones: Array = []            # [t0, t1, Color]
var snap: bool = false
var knob: Color = Color(0.12, 0.12, 0.12)
var t: float = 0.0
var dragging: bool = false
const TOP := 52.0
const BOT_PAD := 16.0

func _init() -> void:
	custom_minimum_size = Vector2(104, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	resized.connect(queue_redraw)

func set_t(v: float) -> void:
	if dragging:
		return
	if absf(v - t) > 0.0001:
		t = v
		queue_redraw()

func _y(v: float) -> float:
	return lerpf(TOP, size.y - BOT_PAD, v)

func _draw() -> void:
	var w := size.x
	var h := size.y
	var f := get_theme_default_font()
	# brushed plate with a bevel
	draw_rect(Rect2(0, 0, w, h), Color(0.16, 0.17, 0.18, 0.92))
	draw_rect(Rect2(0, 0, w, 2), Color(0.45, 0.46, 0.48, 0.9))
	draw_rect(Rect2(0, h - 2, w, 2), Color(0.03, 0.03, 0.03, 0.9))
	for i in 6:
		draw_line(Vector2(4, 8 + i * h / 6.0), Vector2(w - 4, 8 + i * h / 6.0 + 3), Color(1, 1, 1, 0.03), 1)
	draw_string(f, Vector2(6, 17), title, HORIZONTAL_ALIGNMENT_CENTER, w - 12, 14, Color(0.85, 0.86, 0.88))
	draw_string(f, Vector2(6, 37), value_text, HORIZONTAL_ALIGNMENT_CENTER, w - 12, 17, Color(1, 0.84, 0.3))
	var sx := w * 0.64
	for z in zones:
		draw_rect(Rect2(sx + 9, _y(z[0]), 5, _y(z[1]) - _y(z[0])), z[2])
	draw_rect(Rect2(sx - 5, TOP - 4, 10, h - BOT_PAD - TOP + 8), Color(0.02, 0.02, 0.02))
	for st in stops:
		var y := _y(st[1])
		draw_line(Vector2(sx - 11, y), Vector2(sx + 7, y), Color(0.82, 0.82, 0.76), 2)
		draw_string(f, Vector2(2, y + 5), st[0], HORIZONTAL_ALIGNMENT_RIGHT, sx - 16, 12, Color(0.92, 0.92, 0.86))
	# handle: a bar across the slot with a ball knob
	var hy := _y(t)
	draw_rect(Rect2(sx - 8, hy - 7, 32, 14), Color(0.55, 0.56, 0.58))
	draw_rect(Rect2(sx - 8, hy - 7, 32, 4), Color(0.8, 0.81, 0.83))
	draw_circle(Vector2(sx + 26, hy), 14.0, Color(0, 0, 0, 0.5))
	draw_circle(Vector2(sx + 25, hy - 1), 13.0, knob)
	draw_circle(Vector2(sx + 21, hy - 5), 4.0, Color(1, 1, 1, 0.35))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if event.pressed:
			_drag_to(event.position.y)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_drag_to(event.position.y)
		accept_event()

func _drag_to(y: float) -> void:
	var v := clampf((y - TOP) / (size.y - BOT_PAD - TOP), 0.0, 1.0)
	if snap and not stops.is_empty():
		var best: float = stops[0][1]
		for st in stops:
			if absf(st[1] - v) < absf(best - v):
				best = st[1]
		v = best
	t = v
	queue_redraw()
	moved.emit(v)
