extends Node3D
## Switch Challenge - endless mode.
## Cab view down an endless made-up main line. Facing and trailing point switches
## come up; the player reads the target AND the points, stops short and lines the
## switch when it's wrong, and follows the yardmaster's route instructions.

# ---------------------------------------------------------------- constants
const G := 0.7175            # half track gauge (m)
const RW := 0.075            # rail width
const RH := 0.185            # rail height
const RAIL_Y := 0.195        # rail base height (top of tie plates)
const TOP_Y := 0.38          # top of rail
const OFF := 4.6             # siding / spur track-centre offset
const TL := 70.0             # turnout length (lateral transition)
const POINT_LEN := 7.0       # length of the movable point rails
const THROW := 0.13          # how far an open point stands off its stock rail
const CHUNK := 250.0
const EYE_H := 3.75          # engineer eye height above top of rail
const DIV_LIMIT_MPH := 25.0
const MPH := 2.23694
const CAR_LEN := 16.0
const LINE_RANGE := 160.0    # must be stopped within this many metres to line a switch
const BEHIND_KEEP := 450.0
const AHEAD_BUILD := 1600.0
const AHEAD_EVENTS := 2600.0
# train physics (from v11): ~1,250 t train, 430 kN tractive effort, 2.4 MW at the rail, 300 kN dynamic brake
const MASS := 1.25e6
const TE_MAX := 430e3
const P_MAX := 2.4e6
const DB_MAX := 300e3
const AUTO_STEPS := [0.0, 0.06, 0.2, 0.35, 0.5, 0.65, 0.86]
const IND_STEPS := [0.0, 0.25, 0.5, 0.75, 1.0]
const ALERT_WARN := 45.0
const ALERT_PENALTY := 55.0

# ---------------------------------------------------------------- data types
class Switch:
	var d: float = 0.0
	var facing: bool = true
	var side: int = 1
	var reversed: bool = false
	var orig_reversed: bool = false
	var lies: bool = false
	var ev = null
	var lined_by_player: bool = false
	var straight_rail: MeshInstance3D
	var curved_rail: MeshInstance3D
	var target_mat: StandardMaterial3D

class TrackEvent:
	var kind: String = "siding"   # siding | spur_facing | spur_trailing
	var industry: Array = []
	var side: int = 1
	var d_in: float = 0.0
	var d_out: float = 0.0
	var start: float = 0.0
	var end: float = 0.0
	var car_d: float = INF
	var required_siding: bool = false
	var switches: Array = []
	var nodes: Array = []

# ---------------------------------------------------------------- state
var events: Array = []
var chunks: Dictionary = {}
var next_event_d: float = 450.0
var front_d: float = 0.0
var speed: float = 0.0
var lever: int = 0            # 8..1 = notch, 0 = idle, -1 = DB setup, -2..-9 = dynamic brake 1..8
var auto_h: float = 0.0       # automatic brake handle 0 (release) .. 0.86 (full service)
var ind_h: float = 0.0        # independent brake handle 0..1
var emergency: bool = false
var er_psi: float = 90.0      # equalizing reservoir
var bp_psi: float = 90.0      # brake pipe
var bc_psi: float = 0.0       # car brake cylinders
var lbc_psi: float = 0.0      # locomotive brake cylinder
var power: float = 0.0        # 0..1 load on the main generator
var dyn: float = 0.0          # 0..1 dynamic brake effort
var prev_bct: float = 0.0
var bail_t: float = 0.0
var bailed: bool = false
var sand: bool = false
var horn: bool = false
var bell: bool = false
var alert_t: float = 0.0
var accel_now: float = 0.0
var joints: Array = []
var next_joint_d: float = 30.0
var snd
var route = null
var score: float = 0.0
var best: int = 0
var strikes: int = 0
var running: bool = false
var game_over: bool = false
var paused: bool = false
var lining_sw = null
var lining_timer: float = 0.0
var spur_stop_timer: float = 0.0
var overspeed_timer: float = 0.0
var zoomed: bool = false
var zoom_fov: float = 14.0
var look_yaw: float = 0.0
var look_pitch: float = -0.05
var recentre: bool = false
var aim_sw = null
var dragging: bool = false
var touches: Dictionary = {}
var pinch_prev: float = 0.0
var time_s: float = 0.0
var autopilot: String = ""
var auto_report: float = 0.0
var auto_games: int = 0
var rng := RandomNumberGenerator.new()
var shot_times: Array = []
var shot_dir: String = ""
var zoom_times: Array = []
var jump_to: float = -1.0

var cab: Node3D
var pivot: Node3D
var cam: Camera3D
var ground: MeshInstance3D
var far_ring: MultiMeshInstance3D
var art = preload("res://scripts/art.gd").new()
var cab_builder = preload("res://scripts/cab.gd").new()
var cab_model: Node3D
var hud
var mats: Dictionary = {}
var meshes: Dictionary = {}

# ================================================================ setup
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if "--autopilot" in args:
		autopilot = "smart"
	elif "--autopilot-dumb" in args:
		autopilot = "dumb"
	rng.randomize()
	for a in args:
		if a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
		elif a.begins_with("--jump="):
			jump_to = float(a.substr(7))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--shot-times="):
			for t in a.substr(13).split(","):
				shot_times.append(float(t))
		elif a.begins_with("--zoom-times="):
			for t in a.substr(13).split(","):
				zoom_times.append(float(t))
	art.setup()
	_make_materials()
	art.make_environment(self)
	_make_ground()
	_make_cab()
	_load_best()
	snd = preload("res://scripts/sound.gd").new()
	add_child(snd)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	reset_world()
	if autopilot != "":
		start_game()
	if jump_to >= 0.0 and not events.is_empty():
		front_d = events[0].start - jump_to
		_stream()

func _mat(c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _make_materials() -> void:
	mats["rail"] = _mat(Color(0.36, 0.24, 0.17))
	mats["railtop"] = _mat(Color(0.8, 0.8, 0.82), 0.25, 0.85)
	mats["point"] = _mat(Color(0.72, 0.72, 0.74), 0.3, 0.8)
	mats["tie"] = _mat(Color(0.24, 0.17, 0.11))
	mats["ballast"] = _mat(Color(0.3, 0.29, 0.27), 1.0)
	mats["pole"] = _mat(Color(0.33, 0.25, 0.17))
	mats["white"] = _mat(Color(0.92, 0.92, 0.9))
	mats["dark"] = _mat(Color(0.08, 0.08, 0.09))
	mats["loco"] = _mat(Color(0.05, 0.07, 0.12), 0.85, 0.0)
	mats["yellow"] = _mat(Color(0.95, 0.75, 0.1))
	mats["road"] = _mat(Color(0.19, 0.19, 0.2), 1.0)
	mats["building"] = _mat(Color(0.62, 0.55, 0.45))
	mats["roof"] = _mat(Color(0.25, 0.25, 0.27))
	mats["wire"] = _mat(Color(0.05, 0.05, 0.05))
	var veg := _mat(Color(1, 1, 1))
	veg.vertex_color_use_as_albedo = true
	mats["veg"] = veg
	var red := _mat(Color(0.9, 0.05, 0.05))
	red.emission_enabled = true
	red.emission = Color(0.8, 0.0, 0.0)
	mats["redlamp"] = red
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.2
	cone.height = 7.0
	cone.radial_segments = 8
	meshes["cone"] = cone
	var ball := SphereMesh.new()
	ball.radius = 2.6
	ball.height = 4.8
	ball.radial_segments = 8
	ball.rings = 4
	meshes["ball"] = ball
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.3
	trunk.height = 2.4
	trunk.radial_segments = 6
	meshes["trunk"] = trunk
	var tie := BoxMesh.new()
	tie.size = Vector3(2.6, 0.16, 0.24)
	meshes["tie"] = tie
	var pole := CylinderMesh.new()
	pole.top_radius = 0.12
	pole.bottom_radius = 0.16
	pole.height = 9.0
	pole.radial_segments = 6
	meshes["pole"] = pole

func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.3, 0.5, 0.8)
	psm.sky_horizon_color = Color(0.72, 0.79, 0.87)
	psm.ground_horizon_color = Color(0.62, 0.64, 0.62)
	psm.ground_bottom_color = Color(0.3, 0.3, 0.28)
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.79, 0.87)
	env.fog_density = 0.00035
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -35.0, 0.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

func _make_ground() -> void:
	ground = art.far_ground()
	add_child(ground)
	far_ring = art.far_tree_ring()
	add_child(far_ring)

func _make_cab() -> void:
	cab = Node3D.new()
	add_child(cab)
	pivot = Node3D.new()
	pivot.position = Vector3(0.85, EYE_H, 0.0)
	cab.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 3000.0
	pivot.add_child(cam)
	cam.current = true
	cab_model = cab_builder.build()
	cab_model.position = Vector3(0.0, EYE_H, -1.08)
	cab.add_child(cab_model)

func _cab_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := _box(cab, size, pos, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi

# ================================================================ game flow
func reset_world() -> void:
	for ev in events:
		_free_event(ev)
	events.clear()
	for k in chunks.keys():
		chunks[k].queue_free()
	chunks.clear()
	next_event_d = 450.0
	front_d = 0.0
	speed = 0.0
	lever = 0
	auto_h = 0.0
	ind_h = 0.0
	emergency = false
	er_psi = 90.0
	bp_psi = 90.0
	bc_psi = 0.0
	lbc_psi = 0.0
	power = 0.0
	dyn = 0.0
	prev_bct = 0.0
	bail_t = 0.0
	bailed = false
	sand = false
	horn = false
	bell = false
	alert_t = 0.0
	joints.clear()
	next_joint_d = 30.0
	route = null
	score = 0.0
	strikes = 0
	running = false
	game_over = false
	paused = false
	lining_sw = null
	lining_timer = 0.0
	spur_stop_timer = 0.0
	overspeed_timer = 0.0
	zoomed = false
	aim_sw = null
	recentre = false
	look_yaw = 0.0
	look_pitch = -0.05
	cam.fov = 70.0
	_stream()
	_place_cab(0.0)

func start_game() -> void:
	running = true
	game_over = false
	lever = 0
	auto_h = 0.0
	ind_h = 0.0
	snd.start()
	hud.on_start()

func restart() -> void:
	reset_world()
	start_game()

func toggle_pause() -> void:
	if not running or game_over:
		return
	paused = not paused
	hud.set_paused(paused)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED and running and not game_over and not paused:
		toggle_pause()

func line_max() -> int:
	return mini(60, 40 + 5 * int(front_d / 2500.0))

# ---------------------------------------------------------------- controls
func _can_control() -> bool:
	return running and not game_over

func _touch() -> void:
	alert_t = 0.0

func set_lever(v: int) -> void:
	if _can_control():
		lever = clampi(v, -9, 8)
		_touch()

func lever_up() -> void:
	set_lever(lever + 1)

func lever_down() -> void:
	set_lever(lever - 1)

func set_auto(h: float) -> void:
	if not _can_control():
		return
	_touch()
	h = clampf(h, 0.0, 0.86)
	if emergency:
		if h < 0.03 and speed < 0.1:
			emergency = false
			hud.toast("Emergency reset - recharging the brake pipe")
		elif h < 0.03:
			hud.toast("Can't recover the emergency until you're stopped")
			return
	auto_h = h

func auto_apply() -> void:
	for st in AUTO_STEPS:
		if st > auto_h + 0.01:
			set_auto(st)
			return

func auto_release() -> void:
	var lower := 0.0
	for st in AUTO_STEPS:
		if st < auto_h - 0.01:
			lower = st
	set_auto(lower)

func set_ind(h: float) -> void:
	if _can_control():
		ind_h = clampf(h, 0.0, 1.0)
		_touch()

func ind_apply() -> void:
	set_ind(ind_h + 0.25)

func ind_release() -> void:
	set_ind(ind_h - 0.25)

func bail() -> void:
	if _can_control():
		bail_t = 0.6
		_touch()

func emergency_brake() -> void:
	if _can_control() and not emergency:
		emergency = true
		lever = mini(lever, 0)
		_touch()
		hud.toast("EMERGENCY BRAKE!", Color(1, 0.3, 0.3))

func toggle_sand() -> void:
	if _can_control():
		sand = not sand
		_touch()

func set_horn(on: bool) -> void:
	horn = on and _can_control()
	if on:
		_touch()

func toggle_bell() -> void:
	if _can_control():
		bell = not bell
		_touch()

func lever_name() -> String:
	if lever > 0:
		return "N%d" % lever
	if lever == 0:
		return "IDLE"
	if lever == -1:
		return "DB SETUP"
	return "DB%d" % (-lever - 1)

func auto_name() -> String:
	if emergency:
		return "EMERGENCY"
	if auto_h < 0.03:
		return "RELEASE"
	if auto_h < 0.1:
		return "MINIMUM"
	if auto_h >= 0.85:
		return "FULL SERVICE"
	return "SERVICE %d LB" % int(90.0 - _er_target(auto_h))

func _er_target(h: float) -> float:
	if emergency:
		return 0.0
	if h < 0.03:
		return 90.0
	return 90.0 - (6.0 + (clampf(h, 0.06, 0.86) - 0.06) / 0.8 * 20.0)

func toggle_zoom() -> void:
	zoomed = not zoomed
	if zoomed:
		zoom_fov = 14.0
		var sw = next_switch()
		aim_sw = sw if sw != null and sw.d - front_d < 900.0 else null
		recentre = false
	else:
		aim_sw = null
		recentre = true

func _look(rel: Vector2) -> void:
	var k := 0.0045 * cam.fov / 70.0
	look_yaw = clampf(look_yaw - rel.x * k, -1.9, 1.9)
	look_pitch = clampf(look_pitch - rel.y * k, -0.75, 0.6)
	aim_sw = null
	recentre = false

func _set_zoom_fov(f: float) -> void:
	zoom_fov = clampf(f, 4.0, 70.0)
	zoomed = zoom_fov < 66.0
	if not zoomed:
		recentre = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_H and not event.echo:
		set_horn(event.pressed)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_UP:
				lever_up()
			KEY_S, KEY_DOWN:
				lever_down()
			KEY_D, KEY_RIGHT:
				auto_apply()
			KEY_A, KEY_LEFT:
				auto_release()
			KEY_BRACKETRIGHT:
				ind_apply()
			KEY_BRACKETLEFT:
				ind_release()
			KEY_B:
				bail()
			KEY_SPACE:
				emergency_brake()
			KEY_X:
				toggle_sand()
			KEY_G:
				toggle_bell()
			KEY_E, KEY_ENTER, KEY_L:
				line_switch()
			KEY_Z, KEY_TAB:
				toggle_zoom()
			KEY_C:
				look_yaw = 0.0
				look_pitch = -0.05
				aim_sw = null
			KEY_R:
				if game_over:
					restart()
			KEY_ESCAPE, KEY_P:
				toggle_pause()
	elif event is InputEventMouseButton:
		if event.device == -1:
			return   # emulated from touch; handled by screen events
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_fov((zoom_fov if zoomed else 70.0) - 6.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_fov((zoom_fov if zoomed else 70.0) + 6.0)
	elif event is InputEventMouseMotion:
		if dragging and event.device != -1:
			_look(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			pinch_prev = 0.0
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() == 1:
			_look(event.relative)
		elif touches.size() >= 2:
			var keys: Array = touches.keys()
			var p0: Vector2 = touches[keys[0]]
			var p1: Vector2 = touches[keys[1]]
			var dist := p0.distance_to(p1)
			if pinch_prev > 0.0:
				_set_zoom_fov((zoom_fov if zoomed else 70.0) + (pinch_prev - dist) * 0.12)
			pinch_prev = dist

# ================================================================ main loop
func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if paused:
		hud.refresh()
		return
	time_s += delta
	if autopilot != "":
		_autopilot(delta)
	if running and not game_over:
		_update_train(delta)
	_stream()
	_place_cab(delta)
	_update_camera(delta)
	var nsw = next_switch()
	var ntxt := "" if nsw == null else "SW %d FT" % int((nsw.d - front_d) * 3.281)
	cab_builder.update(lever, auto_h, ind_h, emergency, int(speed * MPH), line_max(), bp_psi, bc_psi, ntxt)
	_update_sound(delta)
	hud.refresh()
	if shot_dir != "":
		if not zoom_times.is_empty() and time_s >= zoom_times[0]:
			zoom_times.pop_front()
			toggle_zoom()
		if not shot_times.is_empty() and time_s >= shot_times[0]:
			var t: float = shot_times.pop_front()
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/shot_%04d.png" % [shot_dir, int(t * 10)])
			print("SHOT %s d=%.0f" % [str(t), front_d])
			if shot_times.is_empty():
				get_tree().quit()

func _update_train(delta: float) -> void:
	# --- automatic brake: equalizing reservoir -> brake pipe -> car cylinders (v11 rates)
	er_psi = _approach(er_psi, _er_target(auto_h), 5.0, 7.0, delta)
	if emergency:
		bp_psi = _approach(bp_psi, 0.0, 0.0, 70.0, delta)
	else:
		bp_psi = _approach(bp_psi, er_psi, 2.2, 4.5, delta)
	var red := 90.0 - bp_psi
	var bct := 77.0 if emergency else (0.0 if red < 5.0 else minf(64.0, red * 2.5))
	bc_psi = _approach(bc_psi, bct, 8.0, 3.2, delta)
	# --- independent brake, with bail-off of the automatic on the locomotive
	if bct > prev_bct + 0.5:
		bailed = false
	prev_bct = bct
	if bail_t > 0.0:
		bail_t -= delta
		bailed = true
	var lt := maxf(ind_h * 45.0, 0.0 if bailed else minf(bc_psi, 45.0))
	lbc_psi = _approach(lbc_psi, lt, 20.0, 12.0, delta)
	# --- main generator load and dynamic brake build up gradually
	var can_power := not emergency and bp_psi > 45.0 and lining_sw == null
	power = _approach(power, float(maxi(lever, 0)) / 8.0 if can_power else 0.0, 1.0 / 7.0, 1.0 / 3.0, delta)
	var db_notch := (-lever - 1) if lever <= -2 else 0
	dyn = _approach(dyn, float(db_notch) / 8.0, 1.0 / 5.0, 1.0 / 3.0, delta)
	# --- forces
	var v := speed
	var f_trac := minf(TE_MAX * power, P_MAX * power / maxf(v, 1.5)) * (1.1 if sand and v < 6.0 else 1.0)
	var db_shape := v / 4.0 if v < 4.0 else (1.0 if v < 11.0 else 11.0 / v)
	var a_db := DB_MAX * dyn * db_shape / MASS
	var a_br := bc_psi / 64.0 * 0.72 + lbc_psi / 45.0 * 0.14
	var a_res := 0.012 + 0.00022 * v * v
	var a := f_trac / MASS - a_br - a_res - a_db
	if lining_sw != null:
		a = minf(a, -2.5)
	speed = 0.0 if (v <= 0.01 and a <= 0.0) else maxf(0.0, v + a * delta)
	accel_now = a
	# --- alerter: any control input resets it
	if speed > 0.5:
		alert_t += delta
		if alert_t > ALERT_PENALTY:
			alert_t = 0.0
			auto_h = 0.86
			lever = mini(lever, 0)
			hud.toast("ALERTER PENALTY - brakes applied", Color(1, 0.4, 0.3))
	else:
		alert_t = minf(alert_t, 30.0)
	# --- lining in progress
	if lining_sw != null:
		lining_timer -= delta
		if lining_timer <= 0.0:
			_finish_lining()
	var d_prev := front_d
	front_d += speed * delta
	_joint_clacks(d_prev, front_d)
	score += speed * delta * (speed * MPH / 10.0) * 0.1
	_check_switches(d_prev, front_d)
	if game_over:
		return
	# --- overspeed
	var mph := speed * MPH
	if mph > line_max() + 5.0:
		overspeed_timer += delta
		if overspeed_timer > 6.0:
			overspeed_timer = 0.0
			_strike("OVERSPEED", "Track speed is %d MPH." % line_max())
	else:
		overspeed_timer = maxf(0.0, overspeed_timer - delta)
	# --- standing cars on a spur
	if route != null and route.kind == "spur_facing":
		if front_d >= route.car_d:
			front_d = route.car_d
			var hit := int(mph)
			speed = 0.0
			if hit >= 4:
				_end_game("COLLISION", "You ran into the industry spur and hit standing cars at %d MPH." % hit)
			else:
				_back_out()
			return
		if speed < 0.2 and lining_sw == null:
			spur_stop_timer += delta
			if spur_stop_timer > 1.2:
				_back_out()
		else:
			spur_stop_timer = 0.0

# ---------------------------------------------------------------- switches
func expected_reversed(sw) -> bool:
	var ev = sw.ev
	if sw.facing:
		return ev.required_siding if ev.kind == "siding" else false
	return route == ev

func route_name(sw, rev: bool) -> String:
	if not rev:
		return "MAIN"
	return "SIDING" if sw.ev.kind == "siding" else "SPUR"

func next_switch():
	if route != null and route.kind == "spur_facing":
		return null
	var best_sw = null
	for ev in events:
		if route != null and ev != route:
			continue
		for sw in ev.switches:
			if sw.d > front_d and (best_sw == null or sw.d < best_sw.d):
				best_sw = sw
	return best_sw

func can_line() -> bool:
	if not running or game_over or lining_sw != null:
		return false
	var sw = next_switch()
	return sw != null and speed < 0.3 and sw.d - front_d <= LINE_RANGE

func line_switch() -> void:
	if not can_line():
		if running and not game_over and lining_sw == null:
			var sw = next_switch()
			if sw != null and sw.d - front_d < 900.0:
				hud.toast("Stop within %d ft of the switch to line it" % int(LINE_RANGE * 3.281))
		return
	lining_sw = next_switch()
	lining_timer = 2.2
	hud.toast("Conductor is lining the switch...")

func _finish_lining() -> void:
	var sw = lining_sw
	lining_sw = null
	sw.reversed = not sw.reversed
	sw.lined_by_player = true
	_update_switch_visual(sw)
	hud.toast("Switch lined for the %s" % route_name(sw, sw.reversed))

# axle positions behind the nose (front truck, rear truck) and how loud each sounds in the cab
const AXLES := [[2.0, 1.0], [3.9, 0.9], [5.8, 0.8], [15.8, 0.5], [17.7, 0.45], [19.6, 0.4]]

func _update_sound(delta: float) -> void:
	var notch := maxi(lever, 0) if not emergency else 0
	snd.update(delta, {"speed": speed, "notch": notch, "power": power, "dyn": dyn, "bp": bp_psi, "bc": bc_psi,
		"lbc": lbc_psi, "emergency": emergency, "horn": horn and running, "bell": bell,
		"alert": 1 if (running and alert_t > ALERT_WARN) else 0, "running": running and not game_over})

func _joint_clacks(d_prev: float, d_now: float) -> void:
	if d_now <= d_prev:
		return
	var keep: Array = []
	for j in joints:
		var jd: float = j[0]
		for ax in AXLES:
			var off: float = ax[0]
			if jd > d_prev - off and jd <= d_now - off:
				var g: float = ax[1] * clampf(speed / 8.0, 0.25, 1.0) * (1.3 if j[1] else 0.7)
				snd.clack(g, j[1])
		if jd > d_now - 25.0:
			keep.append(j)
	joints = keep

func _approach(v: float, t: float, up: float, down: float, dt: float) -> float:
	return minf(t, v + up * dt) if v < t else maxf(t, v - down * dt)

func _check_switches(a: float, b: float) -> void:
	for ev in events:
		for sw in ev.switches:
			if sw.d > a and sw.d <= b:
				if route != null and (route.kind == "spur_facing" or sw.ev != route):
					continue
				_pass_switch(sw)
				if game_over:
					return

func _pass_switch(sw) -> void:
	var ev = sw.ev
	var mph := speed * MPH
	if lining_sw == sw:
		lining_sw = null
	if sw.facing:
		var div: bool = sw.reversed
		if div and mph > DIV_LIMIT_MPH + 5.0:
			_end_game("DERAILED", "You took the diverging route at %d MPH. The limit is 25 MPH." % int(mph))
			return
		if div:
			route = ev
		if ev.kind == "siding":
			if div == ev.required_siding:
				_reward(sw, div)
			else:
				_strike("WRONG ROUTE", "The yardmaster wanted you on the %s." % ("SIDING" if ev.required_siding else "MAIN"))
		elif div:
			if autopilot != "":
				print("AUTOTEST spur entered: mph %d lining %s lined_by_player %s orig %s rev %s" % [int(mph), str(lining_sw), str(sw.lined_by_player), str(sw.orig_reversed), str(sw.reversed)])
			hud.toast("You're lined into the occupied SPUR! STOP!", Color(1, 0.3, 0.3))
		else:
			_reward(sw, false)
	else:
		var on_div: bool = route == ev
		if sw.reversed != on_div:
			_end_game("RAN THROUGH SWITCH", "The trailing-point switch was lined for the %s, but you were on the %s." % [route_name(sw, sw.reversed), route_name(sw, on_div)])
			return
		if on_div and mph > DIV_LIMIT_MPH + 5.0:
			_end_game("DERAILED", "You came off the diverging route at %d MPH. The limit is 25 MPH." % int(mph))
			return
		if on_div:
			route = null
		_reward(sw, on_div)

func _reward(sw, expected_rev: bool) -> void:
	var pts := 150.0 if sw.facing else 100.0
	var msg := "Good move"
	if sw.lined_by_player and sw.orig_reversed != expected_rev:
		pts += 150.0
		msg = "Good catch! It was lined wrong"
		if sw.lies:
			pts += 200.0
			msg = "Sharp eyes! The target was wrong"
	pts *= 1.0 + speed * MPH / 40.0
	score += pts
	hud.toast("%s  +%d" % [msg, int(pts)], Color(0.6, 1.0, 0.6))

func _strike(title: String, msg: String) -> void:
	strikes += 1
	if strikes >= 3:
		_end_game(title, msg + "\nThat's three strikes.")
	else:
		hud.toast("STRIKE %d: %s\n%s" % [strikes, title, msg], Color(1.0, 0.7, 0.2))

func _back_out() -> void:
	var ev = route
	spur_stop_timer = 0.0
	_strike("WRONG TRACK", "Conductor walked the spur and backed you out.")
	if game_over:
		return
	var sw = ev.switches[0]
	route = null
	sw.reversed = false
	_update_switch_visual(sw)
	front_d = sw.d - 140.0
	speed = 0.0
	lever = 0
	auto_h = 0.2

func _end_game(title: String, msg: String) -> void:
	game_over = true
	running = false
	horn = false
	if title in ["COLLISION", "DERAILED", "RAN THROUGH SWITCH"]:
		snd.play("crash", 1.0)
	if autopilot != "":
		print("AUTOTEST END: %s - %s (at %.0f m, %d mph)" % [title, msg, front_d, int(speed * MPH)])
	lining_sw = null
	var final := int(score)
	var new_best := final > best
	if new_best:
		best = final
		_save_best()
	hud.show_game_over(title, msg, final, best, new_best)

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		best = int(cf.get_value("scores", "best", 0))

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("scores", "best", best)
	cf.save("user://save.cfg")

func yardmaster_info() -> Array:
	if not running:
		return ["", ""]
	if route != null and route.kind == "spur_facing":
		return ["Yardmaster: You're in the SPUR with standing cars ahead. STOP!", ""]
	var sw = next_switch()
	if sw == null or sw.d - front_d > 1700.0:
		return ["Yardmaster: Clear track ahead. Watch for switches.", ""]
	var ev = sw.ev
	var side_txt := "RIGHT" if sw.side > 0 else "LEFT"
	var ym := ""
	if sw.facing:
		if ev.kind == "siding":
			if ev.required_siding:
				ym = "Take the SIDING on the %s. Diverging limit 25 MPH." % side_txt
			else:
				ym = "Hold the MAIN past the siding on the %s." % side_txt
		else:
			ym = "Industry spur on the %s is OCCUPIED. Hold the MAIN." % side_txt
	else:
		if ev.kind == "siding":
			ym = "End of siding: switch must be lined for the %s." % ("SIDING" if route == ev else "MAIN")
		else:
			ym = "Spur joins from the %s (trailing point). It must be lined for the MAIN." % side_txt
	var ft := int((sw.d - front_d) * 3.281)
	var nxt := "Next switch: %d ft  -  %s POINT" % [ft, "FACING" if sw.facing else "TRAILING"]
	return ["Yardmaster: " + ym, nxt]

# ================================================================ track geometry
func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func div_x(ev, d: float) -> float:
	match ev.kind:
		"siding":
			return ev.side * OFF * minf(_smooth((d - ev.d_in) / TL), _smooth((ev.d_out - d) / TL))
		"spur_facing":
			return ev.side * OFF * _smooth((d - ev.d_in) / TL)
		_:
			return ev.side * OFF * _smooth((ev.d_out - d) / TL)

func track_x_at(d: float) -> float:
	if route == null:
		return 0.0
	return div_x(route, d)

func _place_cab(delta: float) -> void:
	var cd := front_d - 2.5
	var x := track_x_at(cd)
	var slope := (track_x_at(cd + 1.0) - track_x_at(cd - 1.0)) * 0.5
	var sway := sin(time_s * 1.7) * 0.004 * clampf(speed / 20.0, 0.0, 1.0)
	cab.position = Vector3(x, TOP_Y + absf(sin(time_s * 9.0)) * 0.006 * clampf(speed / 25.0, 0.0, 1.0), -cd)
	cab.rotation = Vector3(0.0, -atan(slope), sway)
	ground.position = Vector3(0.0, -3.0, -front_d)
	far_ring.position = Vector3(0.0, 0.0, -front_d)

func _update_camera(delta: float) -> void:
	var tfov := zoom_fov if zoomed else 70.0
	cam.fov = lerpf(cam.fov, tfov, 1.0 - exp(-8.0 * delta))
	if zoomed and aim_sw != null:
		var aim_d: float = aim_sw.d + (3.0 if aim_sw.facing else -3.0)
		var p := Vector3(0.0, RAIL_Y, -aim_d)
		var local: Vector3 = cab.global_transform.affine_inverse() * p - pivot.position
		if local.z < -1.0:
			var ty := atan2(-local.x, -local.z)
			var tp := atan2(local.y, Vector2(local.x, local.z).length())
			# frame roughly 30 m of track around the points, whatever the distance
			zoom_fov = clampf(rad_to_deg(2.0 * atan(15.0 / -local.z)), 4.0, 30.0)
			var k := 1.0 - exp(-6.0 * delta)
			look_yaw = lerp_angle(look_yaw, ty, k)
			look_pitch = lerpf(look_pitch, tp, k)
		else:
			aim_sw = null
	elif recentre:
		var k2 := 1.0 - exp(-3.0 * delta)
		look_yaw = lerpf(look_yaw, 0.0, k2)
		look_pitch = lerpf(look_pitch, -0.05, k2)
		if absf(look_yaw) < 0.01:
			recentre = false
	pivot.rotation = Vector3(look_pitch, look_yaw, 0.0)

# ================================================================ streaming
func _stream() -> void:
	while next_event_d < front_d + AHEAD_EVENTS:
		_gen_event()
	while next_joint_d < front_d + 300.0:
		joints.append([next_joint_d, false])
		next_joint_d += rng.randf_range(25.0, 90.0)
	var first := int(floor((front_d - BEHIND_KEEP) / CHUNK))
	var last := int(floor((front_d + AHEAD_BUILD) / CHUNK))
	for k in chunks.keys():
		if k < first:
			chunks[k].queue_free()
			chunks.erase(k)
	for i in range(first, last + 1):
		if not chunks.has(i):
			_build_chunk(i)
	var keep: Array = []
	for ev in events:
		if ev.end < front_d - BEHIND_KEEP and ev != route:
			_free_event(ev)
		else:
			keep.append(ev)
	events = keep

func _free_event(ev) -> void:
	for n in ev.nodes:
		if is_instance_valid(n):
			n.queue_free()
	ev.nodes.clear()

func _gen_event() -> void:
	var k := clampf(next_event_d / 18000.0, 0.0, 1.0)
	var p_wrong := 0.28 + 0.17 * k
	var p_lie := 0.03 + 0.09 * k
	var ev := TrackEvent.new()
	ev.side = 1 if rng.randf() < 0.5 else -1
	var r := rng.randf()
	ev.start = next_event_d
	if r < 0.45:
		ev.kind = "siding"
		ev.d_in = ev.start
		ev.d_out = ev.d_in + 2.0 * TL + rng.randf_range(380.0, 600.0)
		ev.end = ev.d_out
		ev.required_siding = rng.randf() < 0.45
		_add_switch(ev, ev.d_in, true, ev.required_siding, p_wrong, p_lie)
		_add_switch(ev, ev.d_out, false, ev.required_siding, p_wrong * 0.8, p_lie)
	elif r < 0.75:
		ev.kind = "spur_facing"
		ev.d_in = ev.start
		ev.end = ev.d_in + TL + rng.randf_range(150.0, 230.0)
		var ncars := rng.randi_range(2, 4)
		ev.car_d = ev.end - 8.0 - ncars * CAR_LEN
		_add_switch(ev, ev.d_in, true, false, p_wrong, p_lie)
	else:
		ev.kind = "spur_trailing"
		ev.d_out = ev.start + TL + rng.randf_range(150.0, 230.0)
		ev.end = ev.d_out
		_add_switch(ev, ev.d_out, false, false, p_wrong * 0.9, p_lie)
	events.append(ev)
	_build_event_visuals(ev)
	for sw in ev.switches:
		joints.append([sw.d, true])                                     # points
		joints.append([sw.d + (22.0 if sw.facing else -22.0), true])   # frog
	# leave at least a full-service stopping distance (plus reaction room) at track speed
	var v: float = float(mini(60, 40 + 5 * int(ev.end / 2500.0))) / MPH
	var stop_room: float = v * v / (2.0 * 0.62) + v * 8.0 + 250.0
	next_event_d = ev.end + maxf(lerpf(650.0, 300.0, k), stop_room) + rng.randf_range(0.0, 320.0)

func _add_switch(ev, d: float, facing: bool, required: bool, p_wrong: float, p_lie: float) -> void:
	var sw := Switch.new()
	sw.d = d
	sw.facing = facing
	sw.side = ev.side
	sw.ev = ev
	sw.reversed = required if rng.randf() >= p_wrong else not required
	sw.orig_reversed = sw.reversed
	sw.lies = rng.randf() < p_lie
	ev.switches.append(sw)

# ---------------------------------------------------------------- event visuals
func _build_event_visuals(ev) -> void:
	for sw in ev.switches:
		sw.straight_rail = MeshInstance3D.new()
		sw.straight_rail.material_override = mats["point"]
		add_child(sw.straight_rail)
		sw.curved_rail = MeshInstance3D.new()
		sw.curved_rail.material_override = mats["point"]
		add_child(sw.curved_rail)
		ev.nodes.append(sw.straight_rail)
		ev.nodes.append(sw.curved_rail)
		# switch stand with target, on the side away from the diverging route
		var sx: float = -sw.side * 3.0
		var sd: float = sw.d - 3.0 if sw.facing else sw.d + 3.0
		ev.nodes.append(_box(self, Vector3(0.7, 0.3, 0.7), Vector3(sx, RAIL_Y, -sd), mats["dark"]))
		ev.nodes.append(_box(self, Vector3(0.12, 1.9, 0.12), Vector3(sx, RAIL_Y + 0.95, -sd), mats["dark"]))
		ev.nodes.append(_box(self, Vector3(absf(sx) - 0.8, 0.06, 0.1), Vector3(sx * 0.6, RAIL_Y + 0.05, -sw.d), mats["dark"]))  # throw rod
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.38
		cm.bottom_radius = 0.38
		cm.height = 0.06
		cm.radial_segments = 20
		disc.mesh = cm
		disc.rotation.x = PI / 2.0
		disc.position = Vector3(sx, RAIL_Y + 2.05, -sd)
		var tm := StandardMaterial3D.new()
		tm.emission_enabled = true
		disc.material_override = tm
		sw.target_mat = tm
		add_child(disc)
		ev.nodes.append(disc)
		_update_switch_visual(sw)
	if ev.kind != "siding":
		ev.industry = art.INDUSTRIES[rng.randi() % art.INDUSTRIES.size()]
	if ev.kind == "spur_facing":
		var ck: String = ev.industry[2]
		var d0: float = ev.car_d
		var first := true
		while d0 + art.CAR_LEN[ck] <= ev.end - 6.0:
			_make_car(ev, d0, d0 + art.CAR_LEN[ck], ck, first)
			first = false
			d0 += art.CAR_LEN[ck]
		_make_bumper(ev, ev.end - 1.5)
		_make_building(ev, (ev.d_in + TL + ev.end) * 0.5, ev.end - ev.d_in - TL)
	elif ev.kind == "spur_trailing":
		var ck2: String = ev.industry[2]
		var n := rng.randi_range(1, 3)
		for i in n:
			var a2: float = ev.start + 6.0 + i * art.CAR_LEN[ck2]
			_make_car(ev, a2, a2 + art.CAR_LEN[ck2], ck2, i == 0)
		_make_bumper(ev, ev.start + 1.5)
		_make_building(ev, (ev.start + ev.d_out - TL) * 0.5, ev.d_out - TL - ev.start)

func _make_car(ev, a: float, b: float, kind: String, detailed: bool) -> void:
	var mid := (a + b) * 0.5
	var cols: Array = art.CAR_COLORS[kind]
	var car: Node3D = art.freight_car(kind, cols[rng.randi() % cols.size()], detailed)
	var slope := div_x(ev, mid + 1.0) - div_x(ev, mid - 1.0)
	car.position = Vector3(div_x(ev, mid), 0.0, -mid)
	car.rotation.y = -atan(slope * 0.5)
	add_child(car)
	ev.nodes.append(car)

func _make_bumper(ev, d: float) -> void:
	art.bumper(self, div_x(ev, d), d, 1.0 if ev.kind == "spur_facing" else -1.0)
	ev.nodes.append(get_child(get_child_count() - 1))

func _make_building(ev, mid: float, length: float) -> void:
	if length < 20.0:
		return
	var before := get_child_count()
	art.industry(self, ev.industry[1], float(ev.side), OFF, mid, length * 0.8)
	for i in range(before, get_child_count()):
		ev.nodes.append(get_child(i))

func _update_switch_visual(sw) -> void:
	var tip: float = sw.d
	var heel: float = sw.d + POINT_LEN if sw.facing else sw.d - POINT_LEN
	var s: float = sw.side
	var st_off := 0.0 if not sw.reversed else THROW
	var cv_off := 0.0 if sw.reversed else THROW
	_place_point(sw.straight_rail, Vector2(s * (G - RW - st_off), tip), Vector2(s * G, heel))
	_place_point(sw.curved_rail, Vector2(-s * (G - RW - cv_off), tip), Vector2(div_x(sw.ev, heel) - s * G, heel))
	var shown_rev: bool = sw.reversed != sw.lies
	var c := Color(0.9, 0.08, 0.06) if shown_rev else Color(0.1, 0.85, 0.2)
	sw.target_mat.albedo_color = c
	sw.target_mat.emission = c * 0.7

func _place_point(mi: MeshInstance3D, a: Vector2, b: Vector2) -> void:
	mi.mesh = art.point_rail_mesh(a, b)
	mi.material_override = art.mats["rail"]
	mi.position = Vector3.ZERO
	mi.rotation = Vector3.ZERO

func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p3)

func _rail_strip(body: SurfaceTool, top: SurfaceTool, pts: PackedVector3Array) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var right := dir.cross(Vector3.UP).normalized() * (RW * 0.5)
		var up := Vector3(0.0, RH, 0.0)
		_quad(body, a - right, b - right, b - right + up, a - right + up, -right.normalized())
		_quad(body, a + right, b + right, b + right + up, a + right + up, right.normalized())
		_quad(top, a - right + up, b - right + up, b + right + up, a + right + up, Vector3.UP)

func _ballast_strip(st: SurfaceTool, pts: PackedVector3Array, y_top: float) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var right := dir.cross(Vector3.UP).normalized()
		var t := Vector3(0.0, y_top, 0.0)
		_quad(st, a - right * 3.1, b - right * 3.1, b - right * 1.8 + t, a - right * 1.8 + t, (Vector3.UP - right * 0.5).normalized())
		_quad(st, a - right * 1.8 + t, b - right * 1.8 + t, b + right * 1.8 + t, a + right * 1.8 + t, Vector3.UP)
		_quad(st, a + right * 1.8 + t, b + right * 1.8 + t, b + right * 3.1, a + right * 3.1, (Vector3.UP + right * 0.5).normalized())

func _subtract(a: float, b: float, gaps: Array) -> Array:
	var res: Array = [[a, b]]
	for g in gaps:
		var nr: Array = []
		for iv in res:
			if g[1] <= iv[0] or g[0] >= iv[1]:
				nr.append(iv)
				continue
			if g[0] > iv[0]:
				nr.append([iv[0], g[0]])
			if g[1] < iv[1]:
				nr.append([g[1], iv[1]])
		res = nr
	return res

func _sample(ev, offset: float, a: float, b: float, y: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if ev == null:
		pts.append(Vector3(offset, y, -a))
		pts.append(Vector3(offset, y, -b))
		return pts
	var n := maxi(1, int(ceil((b - a) / 2.0)))
	for i in n + 1:
		var d := lerpf(a, b, float(i) / n)
		pts.append(Vector3(div_x(ev, d) + offset, y, -d))
	return pts

func _point_gap(sw) -> Array:
	var heel: float = sw.d + POINT_LEN if sw.facing else sw.d - POINT_LEN
	return [minf(sw.d, heel), maxf(sw.d, heel)]

func _line(ev, offset: float, a: float, b: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if ev == null:
		pts.append(Vector2(offset, a))
		pts.append(Vector2(offset, b))
		return pts
	var n := maxi(1, int(ceil((b - a) / 2.0)))
	for k in n + 1:
		var d := lerpf(a, b, float(k) / n)
		pts.append(Vector2(div_x(ev, d) + offset, d))
	return pts

func _build_chunk(i: int) -> void:
	var c0 := i * CHUNK
	var c1 := c0 + CHUNK
	var node := Node3D.new()
	add_child(node)
	chunks[i] = node
	var rails := SurfaceTool.new()
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bal := SurfaceTool.new()
	bal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ties: Array = []
	var plates: Array = []
	var overlapping: Array = []
	for ev in events:
		if ev.end > c0 - 5.0 and ev.start < c1 + 5.0:
			overlapping.append(ev)
	# ---- main line
	for rs in [-1, 1]:
		var gaps: Array = []
		for ev in overlapping:
			for sw in ev.switches:
				if sw.side == rs:
					gaps.append(_point_gap(sw))
		for iv in _subtract(c0, c1, gaps):
			art.rail_line(rails, _line(null, rs * G, iv[0], iv[1]))
	art.ballast_line(bal, _line(null, 0.0, c0, c1))
	var tsp: float = art.TIE_SP
	var d: float = ceilf(c0 / tsp) * tsp
	while d < c1:
		ties.append([Vector3(0.0, 0.0, -d), 0.0, 2.6])
		plates.append([Vector3(-G, 0.0, -d), 0.0])
		plates.append([Vector3(G, 0.0, -d), 0.0])
		d += tsp
	# ---- diverging tracks
	for ev in overlapping:
		var a := maxf(c0, ev.start)
		var b := minf(c1, ev.end)
		if b <= a:
			continue
		var s: int = ev.side
		art.ballast_line(bal, _line(ev, 0.0, a, b), -0.004)
		for rs in [-1, 1]:
			var gaps2: Array = []
			if rs == -s:
				for sw in ev.switches:
					gaps2.append(_point_gap(sw))
			for iv in _subtract(a, b, gaps2):
				art.rail_line(rails, _line(ev, rs * G, iv[0], iv[1]))
		var dd: float = ceilf(a / tsp) * tsp
		while dd < b:
			var x := div_x(ev, dd)
			var rot := -atan((div_x(ev, dd + 0.5) - div_x(ev, dd - 0.5)))
			if absf(x) > 2.2:
				ties.append([Vector3(x, 0.0, -dd), rot, 2.6])
				plates.append([Vector3(x - G, 0.0, -dd), rot])
				plates.append([Vector3(x + G, 0.0, -dd), rot])
			elif absf(x) > 0.05:
				# long switch timbers under the turnout
				ties.append([Vector3(x * 0.5, 0.0, -dd), 0.0, 2.6 + absf(x)])
			dd += tsp
	var rail_mi := MeshInstance3D.new()
	rail_mi.mesh = rails.commit()
	rail_mi.material_override = art.mats["rail"]
	node.add_child(rail_mi)
	var bal_mi := MeshInstance3D.new()
	bal_mi.mesh = bal.commit()
	bal_mi.material_override = art.mats["ballast"]
	bal_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(bal_mi)
	node.add_child(art.tie_multimesh(ties))
	node.add_child(art.plate_multimesh(plates))
	node.add_child(art.ground_strip(c0, c1))
	_build_scenery(node, i, c0, c1, overlapping)

func _build_scenery(node: Node3D, i: int, c0: float, c1: float, overlapping: Array) -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = hash(i * 7919 + 13)
	var crossing_d := -1.0
	if i >= 2 and overlapping.is_empty() and srng.randf() < 0.35:
		crossing_d = c0 + CHUNK * 0.5
	var blocked := func(x: float, d: float) -> bool:
		if absf(x) < 9.5:
			return true
		if absf(x + 9.5) < 2.5:
			return true
		if crossing_d > 0.0 and absf(d - crossing_d) < 16.0:
			return true
		for ev in overlapping:
			if d > ev.start - 25.0 and d < ev.end + 25.0 and signf(x) == ev.side and absf(x) < OFF + 32.0:
				return true
		return false
	art.foliage(node, c0, c1, blocked, 1.0, srng)
	art.pole_line(node, c0, c1, -9.5, func(pd: float) -> bool: return crossing_d > 0.0 and absf(pd - crossing_d) < 8.0)
	# ---- mileposts
	var m := int(ceil(c0 / 1609.34))
	while m * 1609.34 < c1:
		var md := m * 1609.34
		var clear := true
		for ev in overlapping:
			if md > ev.start - 20.0 and md < ev.end + 20.0 and ev.side == 1:
				clear = false
		if clear and m > 0:
			art.box(node, Vector3(0.08, 2.0, 0.08), Vector3(3.2, 0.6, -md), art.mats["white"])
			var lbl := Label3D.new()
			lbl.text = str(m)
			lbl.font_size = 96
			lbl.pixel_size = 0.0035
			lbl.modulate = Color(0.05, 0.05, 0.05)
			lbl.outline_size = 0
			lbl.position = Vector3(3.2, 1.45, -md + 0.05)
			var plate := art.box(node, Vector3(0.6, 0.3, 0.03), Vector3(3.2, 1.45, -md + 0.02), art.mats["white"])
			plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(lbl)
		m += 1
	if crossing_d > 0.0:
		_build_crossing(node, crossing_d, srng)

func _build_crossing(node: Node3D, dc: float, srng: RandomNumberGenerator) -> void:
	var road := art.road_strip(0.0, -220.0, 220.0, 8.0)
	road.rotation.y = PI / 2.0
	road.position = Vector3(0.0, -0.39, -dc)
	node.add_child(road)
	art.box(node, Vector3(5.0, 0.2, 8.0), Vector3(0.0, 0.2, -dc), art.mats["road"], false)
	for k in 2:
		var s := 1.0 if k == 0 else -1.0
		var px := s * 4.6
		var pz := -dc + s * 5.4
		art.box(node, Vector3(0.12, 4.2, 0.12), Vector3(px, 1.65, pz), art.mats["white"])
		var xb1 := art.box(node, Vector3(1.4, 0.22, 0.03), Vector3(px, 3.4, pz + s * 0.07), art.mats["white"])
		xb1.rotation = Vector3(0.0, 0.0, PI / 4.0)
		var xb2 := art.box(node, Vector3(1.4, 0.22, 0.03), Vector3(px, 3.4, pz + s * 0.07), art.mats["white"])
		xb2.rotation = Vector3(0.0, 0.0, -PI / 4.0)
		art.box(node, Vector3(1.0, 0.1, 0.1), Vector3(px, 2.6, pz), art.mats["black"])
		for lx in [-0.4, 0.4]:
			art.box(node, Vector3(0.3, 0.3, 0.12), Vector3(px + lx, 2.6, pz + s * 0.08), art.mats["black"])
			art.box(node, Vector3(0.22, 0.22, 0.04), Vector3(px + lx, 2.6, pz + s * 0.15), art.mats["redlamp"], false)
		# gate arm
		var arm := art.box(node, Vector3(0.1, 0.1, 0.1), Vector3(px, 1.2, pz), art.mats["white"])
		arm.scale = Vector3(1, 1, 1)
		# a car waiting at the crossing
		var car_mat := art.mat(Color(srng.randf(), srng.randf(), srng.randf()), 0.3, 0.4)
		var cx := s * srng.randf_range(11.0, 16.0)
		# car sitting on its wheels on the road surface (road top is at -0.39)
		var cz := -dc - s * 2.0
		art.box(node, Vector3(4.4, 0.75, 1.85), Vector3(cx, -0.39 + 0.3 + 0.375, cz), car_mat)
		art.box(node, Vector3(2.3, 0.6, 1.7), Vector3(cx + s * 0.25, -0.39 + 0.3 + 0.75 + 0.3, cz), art.mats["black"])
		for wx in [-1.4, 1.4]:
			for wz in [-0.8, 0.8]:
				var wh := art.cyl(node, 0.33, 0.33, 0.22, Vector3(cx + wx, -0.39 + 0.33, cz + wz), art.mats["black"], 12)
				wh.rotation.x = PI / 2.0
	# whistle post ahead of the crossing
	art.box(node, Vector3(0.08, 2.2, 0.08), Vector3(3.2, 0.7, -(dc - 400.0)), art.mats["white"])
	var w := Label3D.new()
	w.text = "W"
	w.font_size = 120
	w.pixel_size = 0.004
	w.modulate = Color(0.05, 0.05, 0.05)
	w.outline_size = 0
	w.position = Vector3(3.2, 1.6, -(dc - 400.0) + 0.05)
	node.add_child(w)
	art.box(node, Vector3(0.5, 0.5, 0.03), Vector3(3.2, 1.6, -(dc - 400.0) + 0.02), art.mats["white"])

# ================================================================ test autopilot
func _autopilot(delta: float) -> void:
	auto_report += delta
	if game_over:
		print("AUTOTEST game over after %.0f m, score %d, strikes %d" % [front_d, int(score), strikes])
		auto_games += 1
		if auto_games >= 3:
			get_tree().quit(1 if autopilot == "smart" else 0)
		else:
			restart()
		return
	if auto_report > 60.0:
		auto_report = 0.0
		print("AUTOTEST t=%.0f  d=%.0f m  %d mph  lever %d auto %.2f  score %d  strikes %d  events %d chunks %d" % [time_s, front_d, int(speed * MPH), lever, auto_h, int(score), strikes, events.size(), chunks.size()])
	if autopilot == "dumb":
		lever = 6
		auto_h = 0.0
		return
	var desired := float(line_max()) / MPH
	if route != null:
		desired = 20.0 / MPH
	var sw = next_switch()
	if sw != null:
		var dist: float = sw.d - front_d
		var need_rev := expected_reversed(sw)
		if sw.reversed != need_rev:
			if lining_sw == null:
				var stop_d := speed * speed / (2.0 * 0.62) + speed * 8.0 + 60.0
				if dist < stop_d:
					desired = 0.0
				if speed < 0.3 and dist <= LINE_RANGE:
					line_switch()
		elif need_rev:
			var slow_d := (speed * speed - 64.0) / (2.0 * 0.55) + speed * 8.0 + 120.0
			if dist < maxf(slow_d, 150.0):
				desired = minf(desired, 20.0 / MPH)
	_touch()
	if desired <= 0.0:
		lever = -9 if speed > 4.0 else 0
		auto_h = 0.86
		ind_h = 1.0 if speed < 1.0 else 0.0
	elif speed < desired - 0.8:
		lever = 8
		auto_h = 0.0
		ind_h = 0.0
	elif speed > desired + 0.8:
		lever = -9
		auto_h = 0.5 if speed > desired + 3.0 else 0.0
		ind_h = 0.0
	else:
		lever = 3
		auto_h = 0.0
		ind_h = 0.0
