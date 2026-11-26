extends Node
## Live grade crossings: signals with flashers + gates + bells, road traffic that
## stops and queues, and scoring of the engineer's horn sequence
## (long, long, short, long - last long held until the train occupies the crossing).

const WHISTLE_POST := 400.0   # metres before the crossing (about 1/4 mile)
const ROAD_HALF := 4.0        # half road width
const LANE := 1.9             # lane centre offset from road centre line

var art
var game
var list: Array = []          # one Dictionary per crossing
var mats: Dictionary = {}
var bell_stream: AudioStream

func setup(a, g) -> void:
	art = a
	game = g
	bell_stream = load("res://audio/crossing_bell.wav")
	mats["arm"] = _tex_mat("res://textures/gate_arm.png", Vector3(1, 1, 1), 0.5)
	mats["cb1"] = _tex_mat("res://textures/crossbuck1.png", Vector3(1, 1, 1), 0.6)
	mats["cb2"] = _tex_mat("res://textures/crossbuck2.png", Vector3(1, 1, 1), 0.6)
	mats["panel"] = art.mats["concrete"]
	mats["rxr"] = _tex_mat("res://textures/road_rxr.png", Vector3(1, 1, 1), 0.9)
	mats["rxr"].cull_mode = BaseMaterial3D.CULL_DISABLED
	art.mats["road"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["mast"] = art.mat(Color(0.62, 0.63, 0.64), 0.45, 0.6)
	mats["concrete"] = art.mats["concrete"]
	mats["housing"] = art.mat(Color(0.06, 0.06, 0.06), 0.7)
	mats["lamp_off"] = art.mat(Color(0.25, 0.04, 0.03), 0.3)
	var on := StandardMaterial3D.new()
	on.albedo_color = Color(1.0, 0.12, 0.06)
	on.emission_enabled = true
	on.emission = Color(1.0, 0.1, 0.04)
	on.emission_energy_multiplier = 3.0
	mats["lamp_on"] = on
	mats["glass_car"] = art.mat(Color(0.05, 0.07, 0.09), 0.1, 0.6)
	var hl := StandardMaterial3D.new()
	hl.albedo_color = Color(1, 0.97, 0.85)
	hl.emission_enabled = true
	hl.emission = Color(1, 0.95, 0.8)
	mats["headlight"] = hl
	var tl := StandardMaterial3D.new()
	tl.albedo_color = Color(0.8, 0.05, 0.03)
	tl.emission_enabled = true
	tl.emission = Color(0.6, 0.02, 0.01)
	mats["taillight"] = tl

func _tex_mat(path: String, uv: Vector3, rough: float, tri: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.roughness = rough
	m.uv1_scale = uv
	m.uv1_triplanar = tri
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _b(p: Node, w: float, h: float, d: float, m: Material, pos: Vector3, shadow: bool = true) -> MeshInstance3D:
	return art.box(p, Vector3(w, h, d), pos, m, shadow)

# ================================================================ building
func _road_strip(parent: Node3D, x0: float, x1: float, y0: float, y1: float, z_c: float, mat: Material, u_len: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := [Vector3(x0, y0, z_c + ROAD_HALF), Vector3(x1, y1, z_c + ROAD_HALF), Vector3(x1, y1, z_c - ROAD_HALF), Vector3(x0, y0, z_c - ROAD_HALF)]
	var lx := absf(x1 - x0) / u_len
	var uv := [Vector2(1, 0), Vector2(1, lx), Vector2(0, lx), Vector2(0, 0)]
	var e1: Vector3 = c[1] - c[0]
	var e3: Vector3 = c[3] - c[0]
	var nrm: Vector3 = e1.cross(e3).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	for j in art.quad_order(c, nrm):
		st.set_normal(nrm)
		st.set_uv(uv[j])
		st.add_vertex(c[j])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Builds a crossing at track distance dc on chunk node `parent`.
func add(parent: Node3D, dc: float, road_name: String, srng: RandomNumberGenerator) -> void:
	var z := -dc
	var g := Node3D.new()
	parent.add_child(g)
	var road_y := -0.39
	# road: plain far sections, RXR-marked approach, ramps up onto the crossing
	for s in [-1.0, 1.0]:
		var far_m: Material = art.mats["road"]
		if s > 0.0:
			_road_strip(g, s * 45.0, s * 240.0, road_y, road_y, z, far_m, 12.0)
			_road_strip(g, s * 7.0, s * 45.0, road_y, road_y, z, mats["rxr"], 38.0)
		else:
			_road_strip(g, s * 240.0, s * 45.0, road_y, road_y, z, far_m, 12.0)
			_road_strip(g, s * 45.0, s * 7.0, road_y, road_y, z, mats["rxr"], 38.0)
		_road_strip(g, s * 3.3, s * 7.0, 0.34, road_y, z, art.mats["road"], 12.0)
	# concrete crossing panels between and outside the rails (rail heads stick up 2 cm)
	_b(g, 6.6, 0.3, ROAD_HALF * 2.0, mats["panel"], Vector3(0.0, 0.21, z), false)
	_b(g, 0.2, 0.05, ROAD_HALF * 2.0, art.mats["black"], Vector3(-0.62, 0.345, z), false)   # flangeway seals
	_b(g, 0.2, 0.05, ROAD_HALF * 2.0, art.mats["black"], Vector3(0.62, 0.345, z), false)
	var c := {"d": dc, "node": g, "name": road_name, "active": false, "t_active": 0.0, "gate": 0.0,
		"lamps": [], "arms": [], "cars": [], "spawn_t": srng.randf_range(0.0, 4.0), "rng": srng,
		"horn": [], "horn_on": false, "horn_t0": 0.0, "scored": false, "bell": null, "flash": 0.0}
	# signal masts on the right-hand side of each approach
	for dir in [1.0, -1.0]:
		_signal(g, c, Vector3(-dir * 6.2, 0.0, z + dir * (ROAD_HALF + 1.4)), dir)
	var bell := AudioStreamPlayer3D.new()
	bell.stream = bell_stream
	bell.position = Vector3(-6.0, 4.0, z + ROAD_HALF + 1.4)
	bell.unit_size = 12.0
	bell.max_distance = 600.0
	bell.volume_db = -4.0
	g.add_child(bell)
	c["bell"] = bell
	# road name sign
	var lbl := Label3D.new()
	lbl.text = road_name.to_upper()
	lbl.font_size = 64
	lbl.pixel_size = 0.006
	lbl.modulate = Color(1, 1, 1)
	lbl.outline_size = 0
	lbl.position = Vector3(9.5, 2.6, z + ROAD_HALF + 0.9)
	lbl.rotation.y = PI / 2.0
	g.add_child(lbl)
	var plate := _b(g, 2.6, 0.5, 0.03, art.mat(Color(0.05, 0.35, 0.15), 0.6), Vector3(9.5, 2.6, z + ROAD_HALF + 0.88), false)
	plate.rotation.y = PI / 2.0
	_b(g, 0.06, 2.8, 0.06, mats["mast"], Vector3(9.5, 1.0, z + ROAD_HALF + 0.88))
	list.append(c)

## One signal mast: base, mast, crossbuck, flasher pair, bell, gate mechanism + arm.
## dir = +1 serves traffic moving +x (it faces -x), -1 serves traffic moving -x.
func _signal(g: Node3D, c: Dictionary, base: Vector3, dir: float) -> void:
	var face := -dir    # flashers point back toward oncoming cars
	_b(g, 0.9, 0.5, 0.9, mats["concrete"], base + Vector3(0, -0.2, 0))
	art.cyl(g, 0.09, 0.11, 4.6, base + Vector3(0, 2.25, 0), mats["mast"], 10)
	# crossbuck (two boards crossed at 90 degrees)
	for k in 2:
		var b := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2.2, 0.38)
		b.mesh = qm
		b.material_override = mats["cb1"] if k == 0 else mats["cb2"]
		b.position = base + Vector3(face * 0.13, 4.2, 0)
		b.rotation = Vector3(0, face * PI / 2.0, (PI / 4.0) * (1 if k == 0 else -1))
		g.add_child(b)
	# flasher cross-arm with two lights + hoods + black backgrounds
	_b(g, 0.08, 0.08, 1.5, mats["mast"], base + Vector3(face * 0.1, 3.25, 0))
	for lz in [-0.55, 0.55]:
		var lp := base + Vector3(face * 0.2, 3.25, lz)
		var back: MeshInstance3D = art.cyl(g, 0.34, 0.34, 0.03, lp, mats["housing"], 18)
		back.rotation.z = PI / 2.0
		var lamp: MeshInstance3D = art.cyl(g, 0.17, 0.17, 0.06, lp + Vector3(face * 0.04, 0, 0), mats["lamp_off"], 16)
		lamp.rotation.z = PI / 2.0
		var hood: MeshInstance3D = art.cyl(g, 0.2, 0.2, 0.22, lp + Vector3(face * 0.13, 0.03, 0), mats["housing"], 12)
		hood.rotation.z = PI / 2.0
		hood.scale = Vector3(1, 1, 0.6)
		c["lamps"].append(lamp)
	art.cyl(g, 0.16, 0.12, 0.2, base + Vector3(0, 4.62, 0), art.mats["black"], 12)     # bell
	# gate mechanism and arm (arm reaches across the approach lane to the centre line)
	_b(g, 0.45, 0.7, 0.35, art.mats["black"], base + Vector3(0, 1.1, 0))
	var pv := Node3D.new()
	pv.position = base + Vector3(face * 0.3, 1.1, 0)
	g.add_child(pv)
	var arm_len := ROAD_HALF + 1.4 + 0.3
	var arm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.14, arm_len)
	arm.mesh = bm
	var am: StandardMaterial3D = mats["arm"].duplicate()
	am.uv1_scale = Vector3(1, 1, 1)
	arm.material_override = am
	arm.position = Vector3(0, 0, -dir * arm_len / 2.0)
	pv.add_child(arm)
	for k in 3:
		var al: MeshInstance3D = _b(pv, 0.06, 0.12, 0.12, mats["lamp_off"], Vector3(0, 0.12, -dir * (1.2 + k * 1.6)), false)
		c["lamps"].append(al)
	_b(pv, 0.4, 0.4, 0.2, mats["concrete"], Vector3(0, 0, dir * 0.4))    # counterweight
	c["arms"].append([pv, dir])
	_set_gate(c, 0.0)

func _set_gate(c: Dictionary, down: float) -> void:
	# down = 0 (raised, vertical) .. 1 (lowered, horizontal)
	for a in c["arms"]:
		var pv: Node3D = a[0]
		var dir: float = a[1]
		pv.rotation = Vector3(dir * (1.0 - down) * 1.45, 0, 0)

# ================================================================ traffic
func _make_vehicle(parent: Node3D, rng: RandomNumberGenerator) -> Node3D:
	var v := Node3D.new()
	var kind := rng.randi() % 4
	var paint: StandardMaterial3D = art.mat(Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.75), rng.randf_range(0.25, 0.95)), 0.35, 0.45)
	var length := 4.6
	match kind:
		0:   # sedan
			_b(v, length, 0.62, 1.8, paint, Vector3(0, 0.62, 0))
			_b(v, 2.4, 0.5, 1.62, paint, Vector3(-0.2, 1.18, 0))
			_b(v, 2.3, 0.4, 1.66, mats["glass_car"], Vector3(-0.2, 1.17, 0), false)
		1:   # pickup
			length = 5.6
			_b(v, length, 0.75, 1.95, paint, Vector3(0, 0.75, 0))
			_b(v, 2.0, 0.65, 1.85, paint, Vector3(0.9, 1.45, 0))
			_b(v, 1.9, 0.5, 1.9, mats["glass_car"], Vector3(0.9, 1.47, 0), false)
			_b(v, 2.5, 0.35, 1.85, art.mats["black"], Vector3(-1.4, 1.2, 0))
		2:   # SUV
			length = 4.9
			_b(v, length, 0.85, 1.9, paint, Vector3(0, 0.8, 0))
			_b(v, 3.3, 0.65, 1.8, paint, Vector3(-0.3, 1.55, 0))
			_b(v, 3.2, 0.5, 1.84, mats["glass_car"], Vector3(-0.3, 1.55, 0), false)
		_:   # box truck
			length = 7.5
			_b(v, 2.0, 1.6, 2.2, paint, Vector3(2.6, 1.35, 0))
			_b(v, 0.1, 0.7, 2.0, mats["glass_car"], Vector3(3.62, 1.65, 0), false)
			_b(v, 5.4, 2.6, 2.4, art.mat(Color(0.92, 0.92, 0.9), 0.7), Vector3(-1.0, 1.95, 0))
	var half := length / 2.0
	for wx in [-half + 0.85, half - 0.85]:
		for wz in [-0.88, 0.88]:
			var wh: MeshInstance3D = art.cyl(v, 0.36, 0.36, 0.24, Vector3(wx, 0.36, wz), art.mats["black"], 12)
			wh.rotation.x = PI / 2.0
	for lz in [-0.6, 0.6]:
		_b(v, 0.05, 0.14, 0.32, mats["headlight"], Vector3(half + 0.01, 0.75, lz), false)
		_b(v, 0.05, 0.14, 0.28, mats["taillight"], Vector3(-half - 0.01, 0.75, lz), false)
	v.set_meta("len", length)
	parent.add_child(v)
	return v

func _update_traffic(c: Dictionary, delta: float) -> void:
	var rng: RandomNumberGenerator = c["rng"]
	var z := -float(c["d"])
	var g: Node3D = c["node"]
	c["spawn_t"] -= delta
	if c["spawn_t"] <= 0.0 and c["cars"].size() < 8:
		c["spawn_t"] = rng.randf_range(3.0, 9.0)
		var dir := 1.0 if rng.randf() < 0.5 else -1.0
		var v := _make_vehicle(g, rng)
		v.rotation.y = 0.0 if dir > 0.0 else PI
		var car := {"node": v, "dir": dir, "x": -dir * 230.0, "v": rng.randf_range(11.0, 17.0), "vmax": rng.randf_range(11.0, 17.0), "len": float(v.get_meta("len"))}
		car["v"] = car["vmax"]
		c["cars"].append(car)
	var keep: Array = []
	for car in c["cars"]:
		var dir: float = car["dir"]
		var front: float = car["x"] * dir + car["len"] / 2.0     # distance travelled along its direction
		var stop_at := INF
		if c["active"] and front < -8.5 * 1.0 + 0.5:
			stop_at = -8.5     # stop line
		# don't run into the car ahead in the same lane
		for other in c["cars"]:
			if other == car or other["dir"] != dir:
				continue
			var o_back: float = other["x"] * dir - other["len"] / 2.0
			if o_back > front - 0.1 and o_back - 2.5 < stop_at:
				stop_at = o_back - 2.5
		var target: float = car["vmax"]
		if stop_at < INF:
			var gap: float = stop_at - front
			target = clampf(gap * 0.6, 0.0, car["vmax"]) if gap > 0.3 else 0.0
		var cv: float = car["v"]
		car["v"] = move_toward(cv, target, (6.0 if target < cv else 2.5) * delta)
		car["x"] += dir * car["v"] * delta
		var n: Node3D = car["node"]
		n.position = Vector3(car["x"], -0.39 + (0.73 if absf(car["x"]) < 3.3 else (clampf((7.0 - absf(car["x"])) / 3.7, 0.0, 1.0) * 0.73)), z + dir * LANE)
		if absf(car["x"]) > 240.0 and car["x"] * dir > 0.0:
			n.queue_free()
		else:
			keep.append(car)
	c["cars"] = keep

# ================================================================ per frame
func update(delta: float, front_d: float, speed: float, horn: bool, train_len: float, t_now: float) -> void:
	var keep: Array = []
	for c in list:
		if not is_instance_valid(c["node"]):
			continue
		keep.append(c)
		var dc: float = c["d"]
		var ahead := dc - front_d
		if ahead > 2500.0 or ahead < -train_len - 400.0:
			continue
		# activation: constant warning time (~25 s) or when the train is close; clear after the rear passes
		var warn := maxf(speed * 25.0, 60.0)
		var want: bool = (ahead < warn and ahead > -train_len)
		if want and not c["active"]:
			c["t_active"] = 0.0
		c["active"] = want
		c["t_active"] += delta
		var gate_target := 1.0 if (c["active"] and c["t_active"] > 4.0) else 0.0
		c["gate"] = move_toward(c["gate"], gate_target, delta / 9.0)
		_set_gate(c, c["gate"])
		c["flash"] += delta
		var phase := int(c["flash"] * 1.0 * 2.0) % 2
		var lamps: Array = c["lamps"]
		for i in lamps.size():
			var on: bool = c["active"] and ((i % 2) == phase)
			lamps[i].material_override = mats["lamp_on"] if on else mats["lamp_off"]
		var bell: AudioStreamPlayer3D = c["bell"]
		if c["active"] and not bell.playing:
			bell.play()
		elif not c["active"] and bell.playing:
			bell.stop()
		_update_traffic(c, delta)
		# horn sequence between the whistle post and the crossing
		if not c["scored"] and ahead <= WHISTLE_POST and ahead > 15.0:
			if horn and not c["horn_on"]:
				c["horn_on"] = true
				c["horn_t0"] = t_now
			elif not horn and c["horn_on"]:
				c["horn_on"] = false
				c["horn"].append(t_now - c["horn_t0"])
		elif not c["scored"] and ahead <= 15.0:
			c["scored"] = true
			var held: bool = horn and c["horn_on"]
			var blasts: Array = c["horn"].duplicate()
			if held:
				blasts.append(t_now - c["horn_t0"])
			game.crossing_result(c["name"], _grade(blasts, held), blasts.size())
	list = keep

## 2 = proper (long, long, short, long held into the crossing), 1 = horn used, 0 = silent
func _grade(blasts: Array, held: bool) -> int:
	if blasts.is_empty():
		return 0
	if blasts.size() >= 4 and held:
		var n := blasts.size()
		var l1: float = blasts[n - 4]
		var l2: float = blasts[n - 3]
		var s1: float = blasts[n - 2]
		var l3: float = blasts[n - 1]
		if l1 >= 0.9 and l2 >= 0.9 and s1 >= 0.12 and s1 < 0.9 and l3 >= 0.9:
			return 2
	return 1

func whistle_post_ahead(front_d: float) -> Dictionary:
	for c in list:
		var ahead: float = c["d"] - front_d
		if ahead > 0.0 and ahead < 2500.0:
			return c
	return {}
