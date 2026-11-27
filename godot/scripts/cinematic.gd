extends Node3D
## Title-screen cinematic: a freight train rolling down the main line, filmed by a
## rotating set of ten camera shots. The train never stops, so the shots cut together
## in any order and it always looks like one long run through the countryside.

const CabBuilder = preload("res://scripts/cab.gd")
const SPEED := 15.5             # m/s, about 35 mph
const SHOT_LEN := 9.5
const FADE := 0.8
const UNIT_LEN := {"modern": 18.0, "sd70ace": 18.0, "classic": 18.2, "classic_lhf": 19.4}
const REAR_LEN := {"modern": 13.8, "sd70ace": 13.8, "classic": 13.6, "classic_lhf": 4.6}
const SHOT_COUNT := 10

var game
var cam: Camera3D
var attrs: CameraAttributesPractical
var units: Array = []           # [node, distance back from front_d]
var cars: Array = []            # [node, distance back from front_d]
var eot_lamp: MeshInstance3D
var train_len := 300.0
var shot := -1
var shot_t := 0.0
var shot_d0 := 0.0
var order: Array = []
var fade_alpha := 1.0
var active := false
var first := true
var xing_d := -1.0
var test_order: Array = []      # --cine-order=3,5,... for screenshots
var shot_len := SHOT_LEN
var recording := false          # --record: no fades, the video player crossfades instead

func setup(g) -> void:
	game = g
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cine-order="):
			for x in a.substr(13).split(","):
				test_order.append(int(x))
		elif a.begins_with("--cine-len="):
			shot_len = float(a.substr(11))
		elif a == "--record":
			recording = true
	cam = Camera3D.new()
	cam.near = 0.1
	cam.far = 4000.0
	add_child(cam)
	attrs = CameraAttributesPractical.new()
	cam.attributes = attrs

func start() -> void:
	active = true
	visible = true
	first = true
	build_train()
	cam.current = true
	order.clear()
	shot = -1
	_next_shot()

func stop() -> void:
	active = false
	visible = false
	_clear()

func _clear() -> void:
	for u in units:
		u[0].queue_free()
	for c in cars:
		c[0].queue_free()
	units.clear()
	cars.clear()

## Trailing units (exterior only), a mixed manifest of cars and an EOT on the rear.
func build_train() -> void:
	_clear()
	var kind: String = game.loco_model
	var n_units := clampi(int(game.consist["units"]), 2, 3)
	var e: Vector3 = game.cab_builder.eye
	var ul: float = float(UNIT_LEN.get(kind, 18.0)) + 1.0
	for k in range(1, n_units):
		var cb = CabBuilder.new()
		var model: Node3D = cb.build(kind, true, true)
		var u := Node3D.new()
		model.position = Vector3(0.0, game.EYE_H, -e.z)
		u.add_child(model)
		add_child(u)
		units.append([u, 2.5 + k * ul])
	var back := 2.5 + (n_units - 1) * ul - e.z + float(REAR_LEN.get(kind, 13.8)) + 1.0
	var r := RandomNumberGenerator.new()
	r.seed = 1947
	var blocks := [["hop", 7], ["box", 5], ["tank", 6], ["hop", 5], ["box", 7]]
	for b in blocks:
		var k2: String = b[0]
		var cols: Array = game.art.CAR_COLORS[k2]
		for i in int(b[1]):
			var len: float = game.art.CAR_LEN[k2]
			var car: Node3D = game.art.freight_car(k2, cols[r.randi() % cols.size()], true)
			add_child(car)
			cars.append([car, back + len / 2.0])
			back += len + 0.9
	# end-of-train device on the last coupler, flashing red marker
	var eot := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.35, 0.45)
	body.mesh = bm
	body.material_override = game.art.mat(Color(0.85, 0.65, 0.1), 0.6)
	body.position = Vector3(0.25, 1.35, 0.1)
	eot.add_child(body)
	eot_lamp = MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.09
	lm.height = 0.18
	eot_lamp.mesh = lm
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1, 0.1, 0.05)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1, 0.1, 0.05)
	lamp_mat.emission_energy_multiplier = 6.0
	eot_lamp.material_override = lamp_mat
	eot_lamp.position = Vector3(0.25, 1.62, 0.2)
	eot.add_child(eot_lamp)
	add_child(eot)
	cars.append([eot, back - 0.5])
	train_len = back

func _next_shot() -> void:
	if not test_order.is_empty():
		order = [test_order.pop_front()]
	if order.is_empty():
		for i in SHOT_COUNT:
			order.append(i)
		order.shuffle()
		if order[0] == shot:
			order.append(order.pop_front())
	shot = order.pop_front()
	shot_t = 0.0
	shot_d0 = game.front_d
	xing_d = -1.0
	if shot == 9:
		for c in game.xings.list:
			var ahead: float = c["d"] - game.front_d
			if ahead > 90.0 and ahead < 160.0:
				xing_d = c["d"]
				break
		if xing_d < 0.0:
			shot = 0

func update(delta: float) -> void:
	if not active:
		return
	var f: float = game.front_d
	var tm: float = game.time_s
	for u in units:
		u[0].position = Vector3(0.0, game.TOP_Y, -(f - u[1]))
		u[0].rotation.z = sin(tm * 1.7 + u[1]) * 0.004
	for i in cars.size():
		var c: Array = cars[i]
		c[0].position = Vector3(0.0, 0.0, -(f - c[1]))
		c[0].rotation.z = sin(tm * 1.3 + i * 0.7) * 0.006
	if eot_lamp:
		eot_lamp.visible = int(tm * 1.0) % 2 == 0
	shot_t += delta
	if shot_t >= shot_len:
		_next_shot()
	var fin := 2.5 if first else FADE
	fade_alpha = clampf(maxf(1.0 - shot_t / fin, (shot_t - (shot_len - FADE)) / FADE), 0.0, 1.0)
	if first and shot_t > fin:
		first = false
	if recording:
		fade_alpha = 0.0
	var s: Array = _shot(shot, shot_t / shot_len, f)
	var pos: Vector3 = s[0]
	# a touch of handheld drift so nothing feels locked off
	pos += Vector3(sin(tm * 0.53) * 0.08, sin(tm * 0.71) * 0.05, 0.0)
	var target: Vector3 = s[1]
	cam.global_transform = Transform3D(Basis(), pos).looking_at(target, Vector3.UP)
	cam.fov = s[2]
	var dof: float = s[3]
	attrs.dof_blur_far_enabled = false   # Godot's far blur smears the whole frame on many GPUs; revisit later
	attrs.dof_blur_far_distance = maxf(dof, 1.0)
	attrs.dof_blur_far_transition = maxf(dof, 1.0) * 0.8
	attrs.dof_blur_amount = 0.06

func _p(d: float, x: float, y: float) -> Vector3:
	return Vector3(x, y, -d)

## [camera position, look-at target, fov, far-blur distance (0 = off)]
func _shot(i: int, u: float, f: float) -> Array:
	var L := train_len
	match i:
		0:   # low trackside: the train comes at you and thunders past
			return [_p(shot_d0 + 115.0, 6.5, 1.25), _p(f - 8.0, 0.0, 2.6), 36.0, 450.0]
		1:   # drone pacing alongside, slowly sliding back down the train
			return [_p(f - 30.0 - u * 45.0, -40.0, 19.0), _p(f - 70.0 - u * 40.0, 0.0, 2.0), 34.0, 0.0]
		2:   # hero shot just ahead of the nose, low
			return [_p(f + 22.0 - u * 9.0, 5.8 - u * 2.0, 1.5), _p(f - 6.0, 0.0, 3.3), 44.0, 140.0]
		3:   # rail-level, cars rolling past the lens
			var cd := f - 45.0 - u * 70.0
			return [_p(cd, 2.7, 0.7), _p(cd - 30.0, 0.3, 1.0), 50.0, 70.0]
		4:   # long lens across the fields
			return [_p(shot_d0 + 110.0, 150.0, 26.0), _p(f - 70.0, 0.0, 3.0), 13.0, 0.0]
		5:   # high aerial tracking shot
			return [_p(f - 30.0 + u * 30.0, 22.0, 78.0), _p(f - 140.0, 0.0, 0.0), 42.0, 0.0]
		6:   # the rear end and the EOT going away from you
			return [_p(shot_d0 - L - 25.0, -3.0, 1.7), _p(f - L + 4.0, 0.0, 2.0), 24.0, 600.0]
		7:   # riding the roof of the second unit, looking back over the train
			return [_p(f - 28.0 - u * 6.0, 0.5, 6.4), _p(f - 200.0, 0.0, 3.6), 56.0, 0.0]
		8:   # wide establishing shot, the whole train in the landscape
			return [_p(shot_d0 + 320.0, -240.0, 48.0), _p(f - L * 0.45, 0.0, 0.0), 27.0, 0.0]
		_:   # standing by the crossing gates as it comes through
			return [_p(xing_d + 18.0, 15.0, 1.6), _p(f - 4.0, 0.0, 2.6), 34.0, 300.0]
