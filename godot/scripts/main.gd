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
var BEHIND_KEEP := 450.0     # how much world to keep behind the front (more on the title screen)
const AHEAD_BUILD := 1600.0
const AHEAD_EVENTS := 2600.0
# ---------------------------------------------------------------- train consist
# per-unit figures live in LOCOS; the consist sets car count, loading and power.
const CAR_T_LOADED := 120.0     # tonnes per loaded car
const CAR_T_EMPTY := 30.0       # tonnes per empty car
const CAR_LEN_M := 18.3         # ~60 ft average car over the couplers
const LOCO_T := {"modern": 195.0, "sd70ace": 192.0, "classic": 113.0, "classic_lhf": 113.0}
const LOCO_LEN_M := {"modern": 22.3, "sd70ace": 22.6, "classic": 18.0, "classic_lhf": 18.0}
const LOAD_KINDS := ["loaded", "mixed", "empty"]
const DPU_KINDS := ["none", "mid", "rear"]
var consist := {"cars": 40, "load": "loaded", "units": 2, "dpu": "none"}
var MASS := 1.25e6              # kg, whole train
var train_len := 320.0          # m, nose to rear car
var tons := 1250
var car_brake_f := 9.0e5        # N from car brakes at full service (64 psi)
var loco_brake_f := 1.75e5      # N from locomotive brake cylinders at 45 psi
var aero_k := 275.0             # N per (m/s)^2
var roll_a := 0.012             # m/s^2 rolling resistance
var bp_k := 1.0                 # brake pipe propagation factor (long trains are slower)
var restrict_until := -1.0      # front_d where the rear clears the last diverging turnout
var restrict_timer := 0.0
var counter_mode := 0           # 0 off, 1 rear-clear countdown, 2 count up
var counter_d0 := 0.0
const LOCOS := {
	"modern": {"te": 430e3, "p": 2.4e6, "db": 300e3, "split": true, "brake": "CCB", "name": "ES44AC"},
	"sd70ace": {"te": 425e3, "p": 2.35e6, "db": 300e3, "split": true, "brake": "CCB", "name": "SD70ACe"},
	"classic": {"te": 265e3, "p": 1.15e6, "db": 160e3, "split": true, "brake": "26L", "name": "GP38-2"},
	"classic_lhf": {"te": 265e3, "p": 1.15e6, "db": 160e3, "split": true, "brake": "26L", "name": "GP38-2 LHF"},
}
var TE_MAX := 430e3
var P_MAX := 2.4e6
var DB_MAX := 300e3
var has_db: bool = true
var split_db: bool = false
var classic_db: bool = false
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
	var name: String = ""
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
var xings
const PLACE_NAMES := ["Bramwell", "Cedar Fork", "Dunmore", "Halsey", "Kittrell Mill", "Lowry", "Marsden", "Nolan", "Oakhurst", "Pruitt", "Quarry Jct", "Rendle", "Sutter", "Tillery", "Varner", "Whitlow", "Yates", "Ashby", "Corbin", "Fenwick", "Grover", "Iverson"]
const ROAD_NAMES := ["Mill Rd", "Church St", "Old 301", "Depot St", "Farm Rd 1104", "Pine St", "Brook Rd", "Halifax Rd", "Cedar Ln", "Quarry Rd", "Main St", "Railroad Ave", "Courthouse Rd", "Hundred Rd"]
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
var consist_override: Dictionary = {}
var debug_eye_x := INF
var debug_look := Vector2(INF, 0)   # --look=yaw,pitch holds the view for screenshots
var jump_to: float = -1.0
var jump_xing: float = -1.0
var xing_cam: bool = false
var quality_override: int = -1

var cab: Node3D
var pivot: Node3D
var cam: Camera3D
var ground: MeshInstance3D
var far_ring: MultiMeshInstance3D
var art = preload("res://scripts/art.gd").new()
var cab_builder = preload("res://scripts/cab.gd").new()
var cab_model: Node3D
var loco_model: String = "modern"
var loco_override: String = ""
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
		elif a.begins_with("--quality="):
			quality_override = int(a.substr(10))
		elif a == "--xing-cam":
			xing_cam = true
		elif a.begins_with("--jump-xing="):
			jump_xing = float(a.substr(12))
		elif a.begins_with("--loco="):
			loco_override = a.substr(7)
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--shot-times="):
			for t in a.substr(13).split(","):
				shot_times.append(float(t))
		elif a.begins_with("--consist="):
			var cs := a.substr(10).split(",")
			consist_override = {"cars": int(cs[0]), "load": cs[1], "units": int(cs[2]), "dpu": cs[3] if cs.size() > 3 else "none"}
		elif a.begins_with("--layout="):
			debug_layout = a.substr(9)
		elif a.begins_with("--eye-x="):
			debug_eye_x = float(a.substr(8))
		elif a.begins_with("--look="):
			var lk := a.substr(7).split(",")
			debug_look = Vector2(float(lk[0]), float(lk[1]))
		elif a.begins_with("--zoom-times="):
			for t in a.substr(13).split(","):
				zoom_times.append(float(t))
	art.setup()
	art.quality = 1 if OS.has_feature("mobile") else 2
	_load_best()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			art.quality = int(a.substr(10))
	_make_materials()
	art.make_environment(self)
	_make_ground()
	_load_best()
	if loco_override != "":
		loco_model = loco_override
	if not consist_override.is_empty():
		consist = consist_override
	packs = preload("res://scripts/packs.gd").new()
	add_child(packs)
	packs.mount_all()
	_make_cab()
	snd = preload("res://scripts/sound.gd").new()
	add_child(snd)
	xings = preload("res://scripts/crossings.gd").new()
	add_child(xings)
	xings.setup(art, self)
	hud = preload("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	cine = preload("res://scripts/cinematic.gd").new()
	add_child(cine)
	cine.setup(self)
	title = preload("res://scripts/title.gd").new()
	title.game = self
	add_child(title)
	_setup_audio_buses()
	_apply_settings()
	reset_world()
	if autopilot != "" or (shot_dir != "" and not "--title" in OS.get_cmdline_user_args()):
		start_game()
	else:
		enter_title()
	if jump_xing >= 0.0:
		var guard := 0
		while xings.list.is_empty() and guard < 40:
			front_d += 250.0
			_stream()
			guard += 1
		if not xings.list.is_empty():
			front_d = xings.list[0]["d"] - jump_xing
			_stream()
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
	cam.fov = cab_fov()
	cam.near = 0.05
	cam.far = 3000.0
	pivot.add_child(cam)
	cam.current = true
	_build_cab_model()

func _apply_loco_spec() -> void:
	if not LOCOS.has(loco_model):
		loco_model = "modern"
	var sp: Dictionary = LOCOS[loco_model]
	split_db = sp["split"] and cab_layout() != "desktop"
	has_db = classic_db if loco_model.begins_with("classic") else true
	_apply_consist()

func powered_units() -> int:
	return int(consist["units"]) + (0 if consist["dpu"] == "none" else 1)

## Turn the consist settings into mass, length, forces and brake behaviour.
func _apply_consist() -> void:
	var sp: Dictionary = LOCOS[loco_model]
	var n: int = consist["cars"]
	var loaded := n
	if consist["load"] == "empty":
		loaded = 0
	elif consist["load"] == "mixed":
		loaded = n / 2
	var empty := n - loaded
	var units := powered_units()
	var lt: float = LOCO_T[loco_model]
	var t := loaded * CAR_T_LOADED + empty * CAR_T_EMPTY + units * lt
	tons = int(t)
	MASS = t * 1000.0
	train_len = n * CAR_LEN_M + units * float(LOCO_LEN_M[loco_model])
	TE_MAX = float(sp["te"]) * units
	P_MAX = float(sp["p"]) * units
	DB_MAX = float(sp["db"]) * units
	# car brakes are rigged for the empty weight, so empties stop much harder per ton
	car_brake_f = loaded * CAR_T_LOADED * 1000.0 * 0.6 + empty * CAR_T_EMPTY * 1000.0 * 0.95
	loco_brake_f = units * lt * 1000.0 * 0.9
	aero_k = 30.0 + 4.0 * n + 25.0 * units
	roll_a = 0.010 + 0.006 * (float(empty) / maxf(1.0, float(n)))
	# a DPU sends brake pipe changes from its own end too, roughly halving the run
	var eff := train_len * (0.5 if consist["dpu"] != "none" else 1.0)
	bp_k = clampf(600.0 / maxf(eff, 100.0), 0.3, 1.4)

## Full-service braking deceleration of the whole train (m/s^2).
func service_decel() -> float:
	return (car_brake_f + loco_brake_f) / MASS

## Distance needed to stop from v with a full service, including brake pipe lag.
func stop_distance(v: float) -> float:
	var lag := 6.0 + 7.0 * (1.0 / bp_k - 1.0)
	return v * v / (2.0 * service_decel() * 0.9) + v * lag

func set_consist(key: String, value) -> void:
	consist[key] = value
	consist["cars"] = clampi(int(consist["cars"]), 5, 150)
	consist["units"] = clampi(int(consist["units"]), 1, 4)
	_apply_consist()
	_save_best()
	if not running and not title_mode:
		reset_world()
	if title_mode and key == "units":
		cine.build_train()

func consist_text() -> String:
	var dpu: String = consist["dpu"]
	return "%d cars %s  -  %d unit%s%s  -  %s t  -  %s ft" % [consist["cars"], str(consist["load"]).to_upper(), consist["units"],
		"" if int(consist["units"]) == 1 else "s", "" if dpu == "none" else " + DPU " + dpu.to_upper(), _commas(tons), _commas(int(train_len * 3.281))]

func cycle_counter() -> void:
	counter_mode = (counter_mode + 1) % 3
	counter_d0 = front_d
	if counter_mode == 1:
		hud.toast("Counter set: %s ft to rear clearing" % _commas(int(train_len * 3.281)))
	elif counter_mode == 2:
		hud.toast("Counter reset: counting up from 0 ft")
	else:
		hud.toast("Counter off")

## Counter readout in feet (countdown to the rear clearing, or distance run).
func counter_ft() -> int:
	if counter_mode == 1:
		return int(maxf(0.0, train_len - (front_d - counter_d0)) * 3.281)
	if counter_mode == 2:
		return int((front_d - counter_d0) * 3.281)
	return 0

func _build_cab_model() -> void:
	_apply_loco_spec()
	if cab_model:
		cab_model.queue_free()
	cab_model = cab_builder.build(loco_model, has_db, false, cab_layout())
	var e: Vector3 = cab_builder.eye
	cab_model.position = Vector3(0.0, EYE_H, -e.z)
	pivot.position = Vector3(e.x if debug_eye_x == INF else debug_eye_x, EYE_H + e.y, 0.0)
	cab.add_child(cab_model)

func set_loco(kind: String) -> void:
	if kind == loco_model:
		return
	loco_model = kind
	_save_best()
	_build_cab_model()
	hud.configure_controls()
	if title_mode:
		cine.build_train()

func set_classic_db(on: bool) -> void:
	classic_db = on
	_save_best()
	_build_cab_model()
	hud.configure_controls()

func cycle_quality(dir: int = 1) -> void:
	art.apply_quality((art.quality + dir + 4) % 4)
	_save_best()
	# rebuild scenery so tree density matches the new setting
	for k in chunks.keys():
		chunks[k].queue_free()
	chunks.clear()
	_stream()

func quality_name() -> String:
	return art.QUALITY_NAMES[art.quality]

func alerter_reset() -> void:
	if running and not game_over:
		alert_t = 0.0
		snd.play("click", 0.6)

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
	restrict_until = -1.0
	restrict_timer = 0.0
	counter_mode = 0
	zoomed = false
	aim_sw = null
	recentre = false
	look_yaw = 0.0
	look_pitch = -0.05
	cam.fov = cab_fov()
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
		if title_mode:
			title.back()
		else:
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
	if not _can_control():
		return
	v = clampi(v, -9 if has_db else 0, 8)
	lever = v
	_touch()

## classic units: separate throttle and dynamic brake handles with an interlock
func set_throttle(n: int) -> void:
	if not _can_control():
		return
	if lever < 0 and n > 0:
		hud.toast("Put the dynamic brake handle in OFF first")
		return
	lever = clampi(n, 0, 8) if lever >= 0 else lever
	_touch()

func set_db(n: int) -> void:
	# n = -1 OFF, 0 SETUP, 1..8 braking
	if not _can_control() or not has_db:
		return
	if lever > 0 and n >= 0:
		hud.toast("Throttle must be in IDLE to use dynamic brake")
		return
	lever = 0 if n < 0 else -1 - n
	_touch()

func lever_up() -> void:
	set_lever(lever + 1)

func lever_down() -> void:
	set_lever(lever - 1)

func set_auto(h: float) -> void:
	if not _can_control():
		return
	_touch()
	h = clampf(h, 0.0, 0.95)
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
	if auto_h >= 0.93:
		return "HANDLE OFF" if LOCOS[loco_model]["brake"] == "26L" else "CONT OFF"
	if auto_h >= 0.88:
		return "SUPPRESSION"
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
	zoom_fov = clampf(f, 4.0, cab_fov())
	zoomed = zoom_fov < 66.0
	if not zoomed:
		recentre = false

var _tap_start := Vector2.ZERO

func _try_pick(screen_pos: Vector2) -> void:
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.has("collider") and hit["collider"].has_meta("action"):
		if hit["collider"].get_meta("action") == "alerter":
			alerter_reset()
			hud.toast("Alerter reset")

# ---------------------------------------------------------------- controller
const PAD_REPEAT_FIRST := 0.4
const PAD_REPEAT_EVERY := 0.16
var pad_held: Dictionary = {}     # repeating button -> seconds until next repeat
var pad_y_t := -1.0               # how long Y (emergency) has been held
var pad_lt := false
var pad_rt := false

func _pad_action(btn: int) -> void:
	match btn:
		JOY_BUTTON_DPAD_UP:
			lever_up()
		JOY_BUTTON_DPAD_DOWN:
			lever_down()
		JOY_BUTTON_DPAD_RIGHT:
			auto_apply()
		JOY_BUTTON_DPAD_LEFT:
			auto_release()
		JOY_BUTTON_RIGHT_SHOULDER:
			ind_apply()
		JOY_BUTTON_LEFT_SHOULDER:
			ind_release()

func _pad_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var btn: int = event.button_index
		if not event.pressed:
			pad_held.erase(btn)
			if btn == JOY_BUTTON_Y:
				pad_y_t = -1.0
			return true
		if title_mode:
			return false
		if btn == JOY_BUTTON_START:
			if game_over:
				restart()
			elif not running:
				start_game()
			else:
				toggle_pause()
			return true
		if not running or game_over or paused:
			return false   # let the menus use the D-pad and A
		match btn:
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
				_pad_action(btn)
				pad_held[btn] = PAD_REPEAT_FIRST
			JOY_BUTTON_A:
				line_switch()
			JOY_BUTTON_B:
				alerter_reset()
			JOY_BUTTON_X:
				toggle_bell()
			JOY_BUTTON_Y:
				pad_y_t = 0.0
			JOY_BUTTON_BACK:
				cycle_counter()
			JOY_BUTTON_LEFT_STICK:
				toggle_sand()
			JOY_BUTTON_RIGHT_STICK:
				toggle_zoom()
		return true
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var on: bool = event.axis_value > 0.45
			if on != pad_rt:
				pad_rt = on
				set_horn(on)
			return true
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			var on2: bool = event.axis_value > 0.6
			if on2 and not pad_lt and running:
				bail()
			pad_lt = on2
			return true
	return false

## Held D-pad / bumpers repeat, Y must be held to dump the air, right stick looks around.
func _pad_process(delta: float) -> void:
	if not running or game_over or paused:
		pad_held.clear()
		pad_y_t = -1.0
		return
	for btn in pad_held.keys():
		pad_held[btn] -= delta
		if pad_held[btn] <= 0.0:
			pad_held[btn] = PAD_REPEAT_EVERY
			_pad_action(btn)
	if pad_y_t >= 0.0:
		pad_y_t += delta
		if pad_y_t > 0.45:
			pad_y_t = -1.0
			emergency_brake()
	if Input.get_connected_joypads().is_empty():
		return
	var lx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ly := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(lx) > 0.18 or absf(ly) > 0.18:
		aim_sw = null
		recentre = false
		look_yaw = clampf(look_yaw - lx * 1.8 * delta, -1.9, 1.9)
		look_pitch = clampf(look_pitch - ly * 1.2 * delta, -0.75, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if _pad_input(event):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_tap_start = event.position
		elif event.position.distance_to(_tap_start) < 12.0:
			_try_pick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		if event.pressed:
			_tap_start = event.position
		elif event.position.distance_to(_tap_start) < 6.0:
			_try_pick(event.position)
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
			KEY_Q:
				alerter_reset()
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
			KEY_F:
				cycle_counter()
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
			_set_zoom_fov((zoom_fov if zoomed else cab_fov()) - 6.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_fov((zoom_fov if zoomed else cab_fov()) + 6.0)
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
				_set_zoom_fov((zoom_fov if zoomed else cab_fov()) + (pinch_prev - dist) * 0.12)
			pinch_prev = dist

# ================================================================ main loop
func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if paused:
		hud.refresh()
		return
	time_s += delta
	_pad_process(delta)
	if fps_label:
		fps_label.visible = bool(settings["show_fps"])
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if title_mode:
		_title_process(delta)
		_shots()
		return
	if autopilot != "":
		_autopilot(delta)
	if running and not game_over:
		_update_train(delta)
	_stream()
	xings.update(delta, front_d, speed, horn and running, train_len, time_s)
	_place_cab(delta)
	_update_camera(delta)
	if xing_cam and not xings.list.is_empty():
		var cz: float = -float(xings.list[0]["d"])
		cam.global_transform = Transform3D(Basis(), Vector3(-16.0, 3.2, cz + 13.0)).looking_at(Vector3(0.0, 1.0, cz), Vector3.UP)
	var nsw = next_switch()
	var te_kn := minf(TE_MAX * power, P_MAX * power / maxf(speed, 1.5)) / 1000.0
	var nft := -1.0
	var nkind := ""
	var ntext := ""
	if nsw != null and nsw.d - front_d < 3300.0:
		nft = (nsw.d - front_d) * 3.281
		nkind = ("FACING" if nsw.facing else "TRAILING") + " SW"
		var yi: Array = yardmaster_info()
		ntext = str(yi[0]).replace("Yardmaster: ", "").left(38)
	cab_builder.update({"lever": lever, "auto_h": auto_h, "ind_h": ind_h, "emergency": emergency,
		"mph": int(round(speed * MPH)), "limit": line_max(), "er": er_psi, "bp": bp_psi, "bc": bc_psi,
		"lbc": lbc_psi, "te_kn": te_kn, "db_kn": DB_MAX * dyn / 1000.0, "flow": maxf(0.0, (90.0 - bp_psi) * (1.0 if auto_h < 0.03 else 0.2)),
		"alert": running and alert_t > ALERT_WARN, "sand": sand, "bell": bell, "lever_name": lever_name(),
		"next_ft": nft, "next_kind": nkind, "next_txt": ntext, "ahead": ptc_ahead(), "mp": front_d / 1609.34,
		"model": LOCOS[loco_model]["name"], "te_max_kn": TE_MAX / 1000.0, "db_max_kn": DB_MAX / 1000.0,
		"consist": "%d CARS  %s T  %s FT" % [consist["cars"], _commas(tons), _commas(int(train_len * 3.281))],
		"dpu": consist["dpu"], "counter": counter_mode, "counter_ft": counter_ft(),
		"rear_turnout": rear_on_turnout()})
	_update_sound(delta)
	hud.refresh()
	_shots()

func _shots() -> void:
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
		bp_psi = _approach(bp_psi, 0.0, 0.0, 70.0 * clampf(bp_k, 0.6, 1.2), delta)
	else:
		bp_psi = _approach(bp_psi, er_psi, 2.2 * bp_k, 4.5 * bp_k, delta)
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
	var db_notch := (-lever - 1) if (lever <= -2 and has_db) else 0
	dyn = _approach(dyn, float(db_notch) / 8.0, 1.0 / 5.0, 1.0 / 3.0, delta)
	# --- forces
	var v := speed
	var f_trac := minf(TE_MAX * power, P_MAX * power / maxf(v, 1.5)) * (1.1 if sand and v < 6.0 else 1.0)
	var db_shape := v / 4.0 if v < 4.0 else (1.0 if v < 11.0 else 11.0 / v)
	var a_db := DB_MAX * dyn * db_shape / MASS
	var a_br := (bc_psi / 64.0 * car_brake_f + lbc_psi / 45.0 * loco_brake_f) / MASS
	var a_res := roll_a + aero_k * v * v / MASS
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
	# the rear of the train is still on a diverging turnout until it clears
	if front_d < restrict_until and mph > DIV_LIMIT_MPH + 5.0:
		restrict_timer += delta
		if restrict_timer > 3.0:
			restrict_timer = 0.0
			restrict_until = -1.0
			_strike("OVERSPEED ON TURNOUT", "Hold 25 MPH until the rear of the train clears the turnout.")
	else:
		restrict_timer = maxf(0.0, restrict_timer - delta)
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
			_restrict_from(sw.d)
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
			_restrict_from(sw.d)
		_reward(sw, on_div)

func _restrict_from(d: float) -> void:
	restrict_until = d + train_len
	restrict_timer = 0.0

## True while the rear of the train is still on a diverging turnout.
func rear_on_turnout() -> bool:
	return front_d < restrict_until

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

func ptc_ahead() -> Array:
	var items: Array = []
	var horizon := 3219.0   # 2 miles
	for ev in events:
		if route != null and ev != route:
			continue
		for sw in ev.switches:
			var dd: float = sw.d - front_d
			if dd > 0.0 and dd < horizon:
				var t := ""
				if ev.kind == "siding":
					var sft := int((ev.d_out - ev.d_in) * 3.281)
					t = ("%s SDG %s FT %s" % [ev.name.to_upper(), _commas(sft), "FITS" if siding_fits(ev) else "NO FIT"]) if sw.facing else ("%s SDG END" % ev.name.to_upper())
				elif ev.kind == "spur_facing":
					t = "SPUR %s" % (ev.industry[0].to_upper() if not ev.industry.is_empty() else "")
				else:
					t = "SPUR SW (TRAIL)"
				items.append([dd, ("FACING " if sw.facing else "TRAIL ") + t])
	for c in xings.list:
		var dx: float = c["d"] - front_d
		if dx > 0.0 and dx < horizon:
			items.append([dx, "XING  " + str(c["name"]).to_upper()])
	var mp := ceilf(front_d / 1609.34)
	while mp * 1609.34 - front_d < horizon:
		items.append([mp * 1609.34 - front_d, "MP %d" % int(mp)])
		mp += 1.0
	items.sort_custom(func(a, b): return a[0] < b[0])
	return items

## Clearance length of a siding (between the fouling points) against our train.
func siding_clear_m(ev) -> float:
	return ev.d_out - ev.d_in - 60.0

func siding_fits(ev) -> bool:
	return train_len <= siding_clear_m(ev)

func _commas(n: int) -> String:
	var t := str(n)
	return t if t.length() <= 3 else t.left(t.length() - 3) + "," + t.right(3)

func crossing_result(road: String, grade: int, blasts: int) -> void:
	if not running or game_over:
		return
	if autopilot != "":
		print("AUTOTEST crossing %s grade %d blasts %d" % [road, grade, blasts])
	if grade == 2:
		var pts := 250.0 * (1.0 + speed * MPH / 40.0)
		score += pts
		hud.toast("Proper horn at %s!  +%d" % [road, int(pts)], Color(0.6, 1.0, 0.6))
	elif grade == 1:
		score += 40.0
		hud.toast("Horn at %s - use long, long, short, long  +40" % road, Color(1.0, 0.9, 0.5))
	else:
		score = maxf(0.0, score - 150.0)
		hud.toast("No horn at %s crossing!  -150" % road, Color(1.0, 0.5, 0.3))

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
	profile["runs"] = int(profile["runs"]) + 1
	profile["miles"] = float(profile["miles"]) + front_d / 1609.34
	DirAccess.remove_absolute(RUN_SAVE)
	_save_best()
	var new_best := final > best
	if new_best:
		best = final
		_save_best()
	hud.show_game_over(title, msg, final, best, new_best)

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://save.cfg") == OK:
		best = int(cf.get_value("scores", "best", 0))
		loco_model = str(cf.get_value("settings", "loco", "modern"))
		classic_db = bool(cf.get_value("settings", "classic_db", false))
		art.quality = int(cf.get_value("settings", "quality", art.quality))
		for k in settings.keys():
			settings[k] = cf.get_value("options", k, settings[k])
		for k in profile.keys():
			profile[k] = cf.get_value("profile", k, profile[k])
		var c = cf.get_value("settings", "consist", {})
		if c is Dictionary and not c.is_empty():
			for k in consist.keys():
				if c.has(k):
					consist[k] = c[k]

func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("scores", "best", best)
	cf.set_value("settings", "loco", loco_model)
	cf.set_value("settings", "classic_db", classic_db)
	cf.set_value("settings", "quality", art.quality)
	cf.set_value("settings", "consist", consist)
	for k in settings.keys():
		cf.set_value("options", k, settings[k])
	for k in profile.keys():
		cf.set_value("profile", k, profile[k])
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
				ym = "Take the SIDING at %s (%s). Diverging limit 25 MPH." % [ev.name, side_txt]
			elif not siding_fits(ev):
				ym = "Hold the MAIN at %s - your train won't fit the %s ft siding." % [ev.name, _commas(int(siding_clear_m(ev) * 3.281))]
			else:
				ym = "Hold the MAIN at %s (siding on the %s)." % [ev.name, side_txt]
		else:
			ym = "%s spur on the %s is OCCUPIED. Hold the MAIN." % [ev.industry[0] if not ev.industry.is_empty() else "Industry", side_txt]
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
	var tfov := zoom_fov if zoomed else cab_fov()
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
	elif debug_look.x != INF:
		look_yaw = debug_look.x
		look_pitch = debug_look.y
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
		next_joint_d += jrng.randf_range(25.0, 90.0)
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
		ev.d_out = ev.d_in + 2.0 * TL + rng.randf_range(1000.0, 2900.0)
		ev.end = ev.d_out
		ev.required_siding = rng.randf() < 0.45 and siding_fits(ev)
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
	if title_mode:
		ev.required_siding = false
		for sw in ev.switches:
			sw.reversed = false
			sw.orig_reversed = false
			sw.lies = false
	ev.name = PLACE_NAMES[rng.randi() % PLACE_NAMES.size()]
	events.append(ev)
	_build_event_visuals(ev)
	for sw in ev.switches:
		joints.append([sw.d, true])                                     # points
		joints.append([sw.d + (22.0 if sw.facing else -22.0), true])   # frog
	# leave at least a full-service stopping distance (plus reaction room) at track speed
	var v: float = float(mini(60, 40 + 5 * int(ev.end / 2500.0))) / MPH
	var stop_room: float = stop_distance(v) + 250.0
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
	bal.generate_tangents()
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
	if i >= 2 and srng.randf() < 0.5:
		var cd := c0 + CHUNK * 0.5
		var clear_x := true
		for ev in overlapping:
			if cd > ev.start - 80.0 and cd < ev.end + 80.0:
				clear_x = false
		if clear_x:
			crossing_d = cd
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
	var zone := zone_at(i)
	var zdens := {"woods": 1.7, "fields": 0.45, "farm": 0.55, "town": 0.35, "residential": 0.75, "industrial": 0.3}
	art.foliage(node, c0, c1, blocked, art.foliage_density() * float(zdens[zone]), srng)
	_zone_buildings(node, i, c0, c1, zone, blocked, srng)
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

## Scenery runs in stretches of a few chunks: woods, open fields, farms,
## small towns, residential edges and industrial areas.
const ZONES := ["woods", "fields", "farm", "residential", "town", "industrial", "fields", "woods", "farm"]
func zone_at(i: int) -> String:
	if i < 2:
		return "fields"
	var block := int(floor(i / 3.0))
	var h := absi(hash(block * 92821 + 7))
	return ZONES[h % ZONES.size()]

func _zone_buildings(node: Node3D, i: int, c0: float, c1: float, zone: String, blocked: Callable, srng: RandomNumberGenerator) -> void:
	var free := func(x: float, d: float, r: float) -> bool:
		for k in [-r, 0.0, r]:
			if blocked.call(x + k, d) or blocked.call(x, d + k):
				return false
		return true
	match zone:
		"residential":
			for side in [-1.0, 1.0]:
				var d := c0 + srng.randf_range(5.0, 20.0)
				while d < c1 - 10.0:
					var x: float = side * srng.randf_range(26.0, 34.0)
					if free.call(x, d, 9.0):
						art.house(node, x, d, srng)
						if srng.randf() < 0.6 and free.call(side * 52.0, d, 9.0):
							art.house(node, side * srng.randf_range(48.0, 58.0), d + srng.randf_range(-6.0, 6.0), srng)
					d += srng.randf_range(16.0, 24.0)
		"town":
			var side := 1.0 if (i % 2 == 0) else -1.0
			if free.call(side * 24.0, c0 + 125.0, 30.0):
				art.storefronts(node, side * 22.0, c0 + 15.0, c1 - 15.0, srng)
			var d2 := c0 + 20.0
			while d2 < c1 - 10.0:
				if free.call(-side * 30.0, d2, 9.0):
					art.house(node, -side * srng.randf_range(28.0, 36.0), d2, srng)
				d2 += srng.randf_range(18.0, 26.0)
			if i % 3 == 0 and free.call(-side * 60.0, c0 + 120.0, 10.0):
				art.water_tower(node, -side * 60.0, c0 + 120.0, PLACE_NAMES[absi(hash(i)) % PLACE_NAMES.size()])
			elif i % 3 == 1 and free.call(side * 70.0, c0 + 90.0, 12.0):
				art.church(node, side * 70.0, c0 + 90.0)
		"farm":
			var fs := -1.0 if srng.randf() < 0.5 else 1.0
			var fx := fs * srng.randf_range(70.0, 110.0)
			if free.call(fx, c0 + 125.0, 20.0):
				art.farmstead(node, fx, c0 + 125.0, srng)
		"industrial":
			var is_ := -1.0 if srng.randf() < 0.5 else 1.0
			if free.call(is_ * 45.0, c0 + 120.0, 30.0):
				art.factory(node, is_ * 48.0, c0 + 120.0, srng)
		_:
			pass

func _build_crossing(node: Node3D, dc: float, srng: RandomNumberGenerator) -> void:
	xings.add(node, dc, ROAD_NAMES[srng.randi() % ROAD_NAMES.size()], srng)
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
	if route != null or rear_on_turnout():
		desired = 20.0 / MPH
	var sw = next_switch()
	if sw != null:
		var dist: float = sw.d - front_d
		var need_rev := expected_reversed(sw)
		if sw.reversed != need_rev:
			if lining_sw == null:
				var stop_d := stop_distance(speed) + 60.0
				if dist < stop_d:
					desired = 0.0
				if speed < 0.3 and dist <= LINE_RANGE:
					line_switch()
		elif need_rev:
			var slow_d := (speed * speed - 64.0) / (2.0 * service_decel() * 0.8) + speed * 8.0 + 150.0
			if dist < maxf(slow_d, 150.0):
				desired = minf(desired, 20.0 / MPH)
	_touch()
	var xc: Dictionary = xings.whistle_post_ahead(front_d)
	horn = false
	if not xc.is_empty():
		var ah: float = xc["d"] - front_d
		if ah < 395.0:
			if not xc.has("ap_t0"):
				xc["ap_t0"] = time_s
			var t: float = time_s - xc["ap_t0"]
			# long 2s, gap 1s, long 2s, gap 1s, short 0.5s, gap 0.8s, long held into the crossing
			horn = (t < 2.0) or (t > 3.0 and t < 5.0) or (t > 6.0 and t < 6.5) or (t > 7.3)
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


# ================================================================ title screen, settings, profile, saves
const RUN_SAVE := "user://run.cfg"
var title_mode := false
var packs
var cine
var title
var fps_label: Label
var settings := {"cab_layout": {}, "title_video": true, "vol_master": 1.0, "vol_engine": 0.9, "vol_horn": 1.0, "vol_ambient": 0.9, "fov": 70.0, "fullscreen": false, "show_fps": false}
var profile := {"name": "Engineer", "runs": 0, "miles": 0.0}
var run_seed := 0
var jrng := RandomNumberGenerator.new()

var debug_layout := ""
func cab_layout() -> String:
	if debug_layout != "":
		return debug_layout
	var d: Dictionary = settings["cab_layout"]
	var opts: Array = cab_builder.LAYOUTS.get(loco_model, [""])
	var v: String = d.get(loco_model, opts[0])
	return v if v in opts else opts[0]

func cycle_cab_layout(dir: int) -> void:
	var opts: Array = cab_builder.LAYOUTS.get(loco_model, [""])
	var i := opts.find(cab_layout())
	var d: Dictionary = settings["cab_layout"]
	d[loco_model] = opts[(i + dir + opts.size()) % opts.size()]
	if loco_model.begins_with("classic"):
		d["classic"] = d[loco_model]
		d["classic_lhf"] = d[loco_model]
	_save_best()
	_build_cab_model()
	hud.configure_controls()

## Called when a content pack finishes installing, so the HD cab shows up right away.
func on_pack_installed() -> void:
	_build_cab_model()
	hud.configure_controls()

func cab_fov() -> float:
	return float(settings["fov"])

func _setup_audio_buses() -> void:
	for b in ["Engine", "Horn", "Ambient"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	snd.assign_buses()
	xings.bus_name = "Ambient"
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.position = Vector2(8, 4)
	fps_label.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(fps_label)
	add_child(layer)

func _bus_vol(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))

func _apply_settings() -> void:
	_bus_vol("Master", settings["vol_master"])
	# outside the cab on the title screen the locomotive is heard from a distance
	_bus_vol("Engine", float(settings["vol_engine"]) * (0.3 if title_mode else 1.0))
	_bus_vol("Horn", float(settings["vol_horn"]) * (0.7 if title_mode else 1.0))
	_bus_vol("Ambient", settings["vol_ambient"])
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and (settings["fullscreen"] or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(want)
	if not zoomed and not title_mode:
		cam.fov = cab_fov()

func set_setting(key: String, v) -> void:
	settings[key] = v
	_apply_settings()
	if key == "title_video" and title_mode:
		title.start_video()
		get_viewport().disable_3d = title.video_on()
	_save_best()

func set_profile_name(n: String) -> void:
	profile["name"] = n.strip_edges() if n.strip_edges() != "" else "Engineer"
	_save_best()

func title_toast(msg: String) -> void:
	title.toast(msg)

# ---------------------------------------------------------------- flow
func enter_title() -> void:
	title_mode = true
	running = false
	game_over = false
	paused = false
	horn = false
	hud.visible = false
	hud.set_paused(false)
	hud.over_panel.visible = false
	BEHIND_KEEP = 1100.0
	reset_world()
	front_d = 400.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--title-start-d="):
			front_d = float(a.substr(16))
	_stream()
	speed = cine.SPEED
	snd.start()
	cine.start()
	if "--record" in OS.get_cmdline_user_args():
		hud.visible = false
	else:
		title.open()
	# with title videos installed, the live 3D cinematic is only a fallback
	get_viewport().disable_3d = title.video_on() and not "--keep3d" in OS.get_cmdline_user_args()
	_apply_settings()

func _leave_title() -> void:
	title_mode = false
	cine.stop()
	title.close()
	hud.visible = true
	BEHIND_KEEP = 450.0
	horn = false
	cam.current = true
	get_viewport().disable_3d = false
	_apply_settings()

func start_switch_challenge() -> void:
	_leave_title()
	rng.randomize()
	run_seed = rng.randi()
	rng.seed = run_seed
	reset_world()
	start_game()

func go_to_main_menu() -> void:
	snd.update(0.016, {"speed": 0.0, "notch": 0, "power": 0.0, "dyn": 0.0, "bp": 90.0, "bc": 0.0, "lbc": 0.0,
		"emergency": false, "horn": false, "bell": false, "alert": 0, "running": false})
	enter_title()

func _title_process(delta: float) -> void:
	var d_prev := front_d
	speed = cine.SPEED
	front_d += speed * delta
	_stream()
	_joint_clacks(d_prev, front_d)
	# blow for the crossings just like a real engineer would
	var xc: Dictionary = xings.whistle_post_ahead(front_d)
	horn = false
	if not xc.is_empty():
		var ah: float = xc["d"] - front_d
		if ah < 395.0:
			if not xc.has("ap_t0"):
				xc["ap_t0"] = time_s
			var t: float = time_s - xc["ap_t0"]
			horn = (t < 2.0) or (t > 3.0 and t < 5.0) or (t > 6.0 and t < 6.5) or (t > 7.3 and ah > 0.0)
	xings.update(delta, front_d, speed, horn, cine.train_len, time_s)
	_place_cab(delta)
	cine.update(delta)
	snd.update(delta, {"speed": speed, "notch": 6, "power": 0.75, "dyn": 0.0, "bp": 90.0, "bc": 0.0, "lbc": 0.0,
		"emergency": false, "horn": horn, "bell": false, "alert": 0, "running": true})

# ---------------------------------------------------------------- save / continue
func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE)

func save_run() -> void:
	var cf := ConfigFile.new()
	cf.set_value("run", "seed", run_seed)
	cf.set_value("run", "d", front_d)
	cf.set_value("run", "score", score)
	cf.set_value("run", "strikes", strikes)
	cf.set_value("run", "time", time_s)
	cf.set_value("run", "loco", loco_model)
	cf.set_value("run", "classic_db", classic_db)
	cf.set_value("run", "consist", consist)
	cf.save(RUN_SAVE)
	hud.toast("Game saved at MP %.1f" % (front_d / 1609.34), Color(0.6, 1.0, 0.6))

func continue_run() -> void:
	var cf := ConfigFile.new()
	if cf.load(RUN_SAVE) != OK:
		return
	loco_model = str(cf.get_value("run", "loco", loco_model))
	classic_db = bool(cf.get_value("run", "classic_db", classic_db))
	var c = cf.get_value("run", "consist", consist)
	if c is Dictionary:
		consist = c
	_leave_title()
	_build_cab_model()
	hud.configure_controls()
	run_seed = int(cf.get_value("run", "seed", 0))
	rng.seed = run_seed
	reset_world()
	# rebuild the line from the saved milepost onward, stopped on the main
	var d: float = cf.get_value("run", "d", 0.0)
	for ev in events:
		_free_event(ev)
	events.clear()
	for k in chunks.keys():
		chunks[k].queue_free()
	chunks.clear()
	joints.clear()
	front_d = d
	next_event_d = d + 600.0
	next_joint_d = d + 20.0
	_stream()
	start_game()
	score = cf.get_value("run", "score", 0.0)
	strikes = int(cf.get_value("run", "strikes", 0))
	hud.toast("Welcome back, %s. Picking up at MP %.1f" % [profile["name"], d / 1609.34], Color(0.6, 1.0, 0.6))
