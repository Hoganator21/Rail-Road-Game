extends Node
## Locomotive sound. Every layer is driven by the physics, not by button presses:
## engine RPM follows the throttle notch (with turbo lag), exhaust bark follows actual
## load, brake hiss follows how fast brake pipe pressure is moving, and so on.

const MPH := 2.23694

var loops: Dictionary = {}
var one_shots: Array = []
var shot_i: int = 0
var streams: Dictionary = {}
var rpm: float = 400.0
var horn_amp: float = 0.0
var bell_t: float = 0.0
var bell_players: Array = []
var bell_i: int = 0
var muted: bool = false
var was_emergency: bool = false
var prev_bp: float = 90.0
var prev_lbc: float = 0.0
var hiss_apply: float = 0.0
var hiss_release: float = 0.0

func _ready() -> void:
	for k in ["engine", "engine_load", "turbo", "rumble", "brake_apply", "brake_release", "squeal", "dyn_fan", "horn", "alerter"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % k)
		p.volume_db = -80.0
		p.autoplay = false
		add_child(p)
		loops[k] = p
	for k in ["clack", "clack_heavy", "dump", "crash", "click", "bell"]:
		streams[k] = load("res://audio/%s.wav" % k)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		one_shots.append(p)
	for i in 3:
		var b := AudioStreamPlayer.new()
		b.stream = streams["bell"]
		add_child(b)
		bell_players.append(b)

## Route players onto the Engine / Horn buses so the settings sliders work.
func assign_buses() -> void:
	for k in loops:
		loops[k].bus = "Horn" if k in ["horn", "alerter"] else "Engine"
	for p in one_shots:
		p.bus = "Engine"
	for b in bell_players:
		b.bus = "Horn"

func start() -> void:
	for k in loops:
		if not loops[k].playing:
			loops[k].play()

func stop_all() -> void:
	for k in loops:
		loops[k].stop()

func _lp(k: String, amp: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = loops[k]
	amp = 0.0 if muted else amp
	p.volume_db = linear_to_db(maxf(amp, 0.00001))
	p.pitch_scale = clampf(pitch, 0.05, 4.0)

func play(k: String, gain: float = 1.0, pitch: float = 1.0) -> void:
	if muted:
		return
	var p: AudioStreamPlayer = one_shots[shot_i]
	shot_i = (shot_i + 1) % one_shots.size()
	p.stream = streams[k]
	p.volume_db = linear_to_db(maxf(gain, 0.00001))
	p.pitch_scale = pitch
	p.play()

func clack(gain: float, heavy: bool) -> void:
	play("clack_heavy" if heavy else "clack", gain, randf_range(0.88, 1.12))

## s: speed (m/s), notch (0-8), power (0-1), dyn (0-1), bp, bc, lbc (psi),
## emergency, horn, bell, alert (0 off, 1 warning), running
func update(delta: float, s: Dictionary) -> void:
	if delta <= 0.0:
		return
	var v: float = s["speed"]
	var running: bool = s["running"]
	# ---- diesel: idle ~400 rpm, notch 8 ~1050 rpm; dynamic braking raises rpm a bit
	var target_rpm: float = 400.0 + float(s["notch"]) / 8.0 * 650.0
	target_rpm = maxf(target_rpm, 400.0 + float(s["dyn"]) * 220.0)
	var rate := 60.0 if target_rpm > rpm else 90.0      # rpm/s: slow climb like a real prime mover
	rpm = move_toward(rpm, target_rpm, rate * delta)
	var eng_load: float = s["power"]
	var eng_pitch := rpm / 600.0
	_lp("engine", 0.55 + 0.25 * eng_load, eng_pitch)
	_lp("engine_load", 0.05 + 0.55 * eng_load * eng_load, eng_pitch)
	var spool := clampf((rpm - 450.0) / 600.0, 0.0, 1.0)
	_lp("turbo", 0.006 + 0.05 * spool * (0.4 + 0.6 * eng_load), 0.45 + 0.35 * spool)
	# ---- wheels on rail
	var sp := clampf(v / 25.0, 0.0, 1.5)
	_lp("rumble", 0.75 * sp, 0.55 + 0.6 * clampf(v / 30.0, 0.0, 1.2))
	# ---- dynamic brake grid blowers
	var dyn: float = s["dyn"]
	_lp("dyn_fan", 0.22 * dyn, 0.6 + 0.25 * dyn)
	# ---- air: brake valve exhaust while brake pipe pressure is dropping, softer hiss while recharging
	var bp: float = s["bp"]
	var dbp := (bp - prev_bp) / delta
	prev_bp = bp
	var lbc: float = s["lbc"]
	var dl := (lbc - prev_lbc) / delta
	prev_lbc = lbc
	var em: bool = s["emergency"]
	var want_apply := clampf(-dbp / 4.5, 0.0, 1.0) if not em else 0.0
	want_apply = maxf(want_apply, clampf(dl / 20.0, 0.0, 1.0) * 0.5)
	var want_release := clampf(dbp / 2.2, 0.0, 1.0) * 0.35
	want_release = maxf(want_release, clampf(-dl / 12.0, 0.0, 1.0) * 0.45)
	hiss_apply = lerpf(hiss_apply, want_apply, 1.0 - exp(-12.0 * delta))
	hiss_release = lerpf(hiss_release, want_release, 1.0 - exp(-8.0 * delta))
	_lp("brake_apply", 0.55 * hiss_apply, 1.0)
	_lp("brake_release", 0.5 * hiss_release, 0.9)
	if em and not was_emergency:
		play("dump", 1.0)
	was_emergency = em
	# ---- brake shoe squeal at low speed under heavy braking
	var bc: float = s["bc"]
	var brake_force := clampf(bc / 64.0 + lbc / 90.0, 0.0, 1.2)
	var sq := 0.0
	if v > 0.25 and v < 9.0:
		sq = brake_force * clampf((9.0 - v) / 6.0, 0.0, 1.0) * clampf(v / 1.0, 0.0, 1.0)
	_lp("squeal", 0.18 * sq, 0.96 + 0.06 * sin(Time.get_ticks_msec() * 0.0007))
	# ---- horn with a quick attack and a short release
	var horn_on: bool = s["horn"]
	horn_amp = move_toward(horn_amp, 1.0 if horn_on else 0.0, (40.0 if horn_on else 8.0) * delta)
	_lp("horn", 0.85 * horn_amp, 1.0)
	# ---- bell
	if s["bell"] and running:
		bell_t -= delta
		if bell_t <= 0.0:
			bell_t = 0.55
			var b: AudioStreamPlayer = bell_players[bell_i]
			bell_i = (bell_i + 1) % bell_players.size()
			b.volume_db = linear_to_db(0.0001 if muted else 0.35)
			b.play()
	else:
		bell_t = 0.0
	_lp("alerter", 0.25 if s["alert"] > 0 else 0.0, 1.0)
	if not running:
		_lp("engine_load", 0.0)
		_lp("rumble", 0.0)
		_lp("squeal", 0.0)
