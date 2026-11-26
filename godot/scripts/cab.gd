extends RefCounted
## Locomotive + cab interior, ported from v11's modern wide-body (ES44C4) unit.
## Coordinates match v11: origin at the engineer's eye level, cab front at z = 0,
## +z is toward the rear of the locomotive, -z is forward (the nose).

var m: Dictionary = {}
var lever_thr: MeshInstance3D
var lever_auto: MeshInstance3D
var wipers: Array = []
var ptc_label: Label3D
var gauge_label: Label3D

func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.roughness = rough
	s.metallic = metal
	return s

func _unshaded(c: Color) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return s

func _tex_mat(path: String, scale: Vector3, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_texture = load(path)
	s.uv1_triplanar = true
	s.uv1_scale = scale
	s.roughness = rough
	s.metallic = metal
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s

func _materials() -> void:
	m["paint"] = _mat(Color("2a2f36"), 0.8, 0.05)
	m["hood"] = _tex_mat("res://textures/hood.png", Vector3(1.0 / 5.5, 1.0 / 1.8, 1.0 / 5.5), 0.78, 0.08)
	m["cab_in"] = _mat(Color("282e35"), 0.85, 0.12)
	m["cab_wall"] = _mat(Color("363e45"), 0.88, 0.08)
	m["floor"] = _tex_mat("res://textures/cab_floor.png", Vector3(1.2, 1.2, 1.2), 0.96, 0.05)
	m["console"] = _mat(Color("1d2228"), 0.72, 0.25)
	m["desk"] = _mat(Color("2e353d"), 0.65, 0.18)
	m["seat"] = _mat(Color("242629"), 0.85, 0.05)
	m["seat_trim"] = _mat(Color("3b3f45"), 0.75)
	m["cooler"] = _mat(Color("1e5c99"), 0.45, 0.1)
	m["cooler_lid"] = _mat(Color("e6e8eb"), 0.5)
	m["door"] = _mat(Color("313840"), 0.8, 0.2)
	m["deck"] = _mat(Color("34373b"), 0.9, 0.25)
	m["handrail"] = _mat(Color("e2c021"), 0.45, 0.2)
	m["brass"] = _mat(Color("b08d3c"), 0.35, 0.8)
	m["mirror_frame"] = _mat(Color("16181c"), 0.5, 0.6)
	m["red"] = _mat(Color("c92a22"), 0.4)
	m["yellow"] = _mat(Color("e0b51c"), 0.52)
	m["steel_dark"] = _mat(Color("262422"), 0.72, 0.35)
	m["black"] = _mat(Color("111214"), 0.6)
	m["alerter"] = _unshaded(Color("f5c724"))
	m["horn_btn"] = _unshaded(Color("d93829"))
	m["sand_btn"] = _unshaded(Color("3b82f6"))
	m["dome"] = _unshaded(Color("ffecc2"))
	m["screen"] = _unshaded(Color("0b1320"))
	m["mirror_glass"] = _mat(Color("c8d6e0"), 0.05, 0.9)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.77, 0.86, 0.14)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.no_depth_test = false
	m["glass"] = glass
	var visor := StandardMaterial3D.new()
	visor.albedo_color = Color(0.09, 0.13, 0.11, 0.72)
	visor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m["visor"] = visor
	var ditch := _unshaded(Color("fff6d8"))
	m["ditch"] = ditch
	var fan := StandardMaterial3D.new()
	fan.albedo_texture = load("res://textures/fan.png")
	fan.roughness = 0.8
	m["fan"] = fan

# ---------------------------------------------------------------- primitives
func box(p: Node, w: float, h: float, d: float, mat: Material, x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(x, y, z)
	p.add_child(mi)
	return mi

func cyl(p: Node, rt: float, rb: float, h: float, mat: Material, pos: Vector3, segs: int = 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	p.add_child(mi)
	return mi

func tube(p: Node, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := cyl(p, r, r, a.distance_to(b), mat, (a + b) * 0.5, 8)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.basis = Basis(x, y, x.cross(y))
	return mi

func quad(p: Node, w: float, h: float, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi

# ---------------------------------------------------------------- locomotive
func build() -> Node3D:
	_materials()
	var L := Node3D.new()
	var deck_y := -2.05
	var front_len := 4.2
	var rear_len := 13.8
	var w := 3.18
	var total := front_len + rear_len
	box(L, w, 0.12, total, m["deck"], 0, deck_y, (rear_len - front_len) / 2.0)
	for s in [-1.0, 1.0]:
		box(L, 0.05, 0.05, total, m["yellow"], s * w / 2.0, deck_y + 0.07, (rear_len - front_len) / 2.0)
	_deck_end(L, deck_y, -front_len, w, -1.0)
	_deck_end(L, deck_y, rear_len, w, 1.0)
	for s in [-1.0, 1.0]:
		cyl(L, 0.12, 0.12, 0.12, m["paint"], Vector3(s * (w / 2.0 - 0.85), deck_y + 0.12, -front_len + 0.45))
		cyl(L, 0.13, 0.13, 0.03, m["steel_dark"], Vector3(s * (w / 2.0 - 0.85), deck_y + 0.19, -front_len + 0.45))
		# ditch lights
		var sx: float = s * (w / 2.0 - 0.3)
		box(L, 0.28, 0.28, 0.2, m["black"], sx, deck_y + 0.25, -front_len + 0.12)
		var lamp := cyl(L, 0.1, 0.1, 0.02, m["ditch"], Vector3(sx, deck_y + 0.25, -front_len + 0.015), 16)
		lamp.rotation.x = PI / 2.0
	# wide-body nose
	var hm: Material = m["hood"]
	box(L, 2.96, 1.02, 1.85, hm, 0, deck_y + 0.56, -0.92)
	var slope := box(L, 2.96, 0.08, 1.45, hm, 0, deck_y + 0.92, -2.42)
	slope.rotation.x = -0.2
	box(L, 2.96, 0.78, 1.4, hm, 0, deck_y + 0.45, -2.42)
	box(L, 2.98, 0.06, 0.08, m["steel_dark"], 0, deck_y + 1.07, -1.78)
	for z in [-0.5, -1.6]:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.055
		tm.outer_radius = 0.085
		t.mesh = tm
		t.material_override = m["steel_dark"]
		t.position = Vector3(0, deck_y + 1.08, z)
		t.rotation = Vector3(0, 0, PI / 2.0)
		L.add_child(t)
	cyl(L, 0.14, 0.18, 0.2, m["brass"], Vector3(-0.55, deck_y + 0.98, -2.6), 16)   # bell
	box(L, 0.6, 0.18, 0.22, m["black"], 0, deck_y + 0.86, -3.13)                   # number board / headlight housing
	box(L, 0.16, 0.5, 0.16, m["black"], 0.85, deck_y + 0.3, -3.1)
	for s in [-1.0, 1.0]:
		tube(L, Vector3(s * 0.95, deck_y + 0.3, -3.16), Vector3(s * 0.95, deck_y + 0.85, -3.16), 0.02, m["handrail"])
	# long hood behind the cab
	var r_len := 10.2
	var r_start := 2.75
	var r_h := 1.65
	box(L, 1.85, r_h, r_len - 2.6, hm, 0, deck_y + r_h / 2.0 + 0.06, r_start + (r_len - 2.6) / 2.0)
	box(L, 2.55, r_h + 0.12, 2.6, hm, 0, deck_y + (r_h + 0.12) / 2.0 + 0.06, r_start + r_len - 1.3)
	for z in [r_start + r_len - 1.9, r_start + r_len - 0.7]:
		cyl(L, 0.58, 0.58, 0.02, m["fan"], Vector3(0, deck_y + r_h + 0.19, z), 24)
	_railings(L, deck_y, -0.05, -front_len + 0.15, [-1.52, 1.52], 0.45)
	_railings(L, deck_y, 2.75, rear_len - 0.15, [-1.52, 1.52], 0.45)
	box(L, 3.14, 0.62, 0.12, m["paint"], 0, -0.86, 0.05)   # cab front wall below the windshields
	_cab_interior(L, 3.16)
	for c in _all_meshes(L):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return L

func _all_meshes(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		out.append_array(_all_meshes(c))
	return out

func _railings(p: Node, deck_y: float, z0: float, z1: float, xs: Array, step_gap_x: float) -> void:
	var top := deck_y + 1.05
	var mid := deck_y + 0.55
	var dir := signf(z1 - z0)
	var dist := absf(z1 - z0)
	var steps := maxi(1, int(ceil(dist / 1.6)))
	for x in xs:
		tube(p, Vector3(x, top, z0), Vector3(x, top, z1), 0.025, m["handrail"])
		tube(p, Vector3(x, mid, z0), Vector3(x, mid, z1), 0.025, m["handrail"])
		for i in steps + 1:
			var z := z0 + dir * dist * i / steps
			tube(p, Vector3(x, deck_y, z), Vector3(x, top, z), 0.03, m["handrail"])
		var gx: float = signf(x) * step_gap_x
		tube(p, Vector3(x, top, z1), Vector3(gx, top, z1), 0.025, m["handrail"])
		tube(p, Vector3(x, mid, z1), Vector3(gx, mid, z1), 0.025, m["handrail"])
		tube(p, Vector3(gx, deck_y, z1), Vector3(gx, top, z1), 0.03, m["handrail"])

func _deck_end(p: Node, deck_y: float, z_end: float, w: float, dir_z: float) -> void:
	box(p, w + 0.04, 0.05, 0.12, m["yellow"], 0, deck_y + 0.07, z_end - dir_z * 0.05)
	box(p, w, 0.45, 0.16, m["paint"], 0, deck_y - 0.3, z_end - dir_z * 0.08)
	box(p, 0.36, 0.28, 0.75, m["steel_dark"], 0, deck_y - 0.34, z_end + dir_z * 0.38)    # coupler
	for s in [-1.0, 1.0]:
		for i in 3:
			box(p, 0.55, 0.04, 0.3, m["yellow"], s * (w / 2.0 - 0.35), deck_y - 0.35 - i * 0.38, z_end - dir_z * 0.25)
		tube(p, Vector3(s * (w / 2.0 - 0.05), deck_y - 1.2, z_end - dir_z * 0.15), Vector3(s * (w / 2.0 - 0.05), deck_y + 0.05, z_end - dir_z * 0.15), 0.022, m["handrail"])

func _seat(p: Node, x: float, floor_y: float, z: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, floor_y, z)
	p.add_child(g)
	cyl(g, 0.08, 0.12, 0.48, m["steel_dark"], Vector3(0, 0.24, 0), 12)
	box(g, 0.52, 0.11, 0.5, m["seat"], 0, 0.5, 0)
	for s in [-1.0, 1.0]:
		box(g, 0.07, 0.06, 0.38, m["seat_trim"], s * 0.28, 0.68, 0.02)
	var back := box(g, 0.48, 0.62, 0.1, m["seat"], 0, 0.82, 0.22)
	back.rotation.x = -0.1
	box(g, 0.28, 0.18, 0.09, m["seat_trim"], 0, 1.18, 0.25)

func _cab_interior(p: Node, w: float) -> void:
	var cab_len := 2.75
	var floor_y := -1.35
	var ceil_y := 0.68
	var sill_y := -0.58
	var half_w := w / 2.0
	box(p, w - 0.08, 0.08, cab_len, m["floor"], 0, floor_y, cab_len / 2.0)
	box(p, w + 0.08, 0.14, cab_len + 0.2, m["paint"], 0, ceil_y + 0.07, cab_len / 2.0 - 0.05)
	box(p, w - 0.1, 0.05, cab_len, m["cab_in"], 0, ceil_y - 0.01, cab_len / 2.0)
	box(p, 0.32, 0.04, 0.32, m["dome"], 0, ceil_y - 0.03, 1.35)
	for vx in [-0.82, 0.82]:
		var visor := box(p, 0.68, 0.22, 0.02, m["visor"], vx, ceil_y - 0.13, 0.12)
		visor.rotation.x = 0.28
	# windshield frames
	for s in [-1.0, 1.0]:
		box(p, 0.14, ceil_y - sill_y, 0.16, m["cab_in"], s * (half_w - 0.07), (ceil_y + sill_y) / 2.0, 0.04)
		box(p, 0.16, sill_y - floor_y, cab_len, m["paint"], s * (half_w - 0.08), (sill_y + floor_y) / 2.0, cab_len / 2.0)
		box(p, 0.16, ceil_y - sill_y, 0.35, m["paint"], s * (half_w - 0.08), (ceil_y + sill_y) / 2.0, cab_len - 0.18)
	box(p, 0.11, ceil_y - sill_y, 0.14, m["cab_in"], 0, (ceil_y + sill_y) / 2.0, 0.03)   # centre mullion
	for wx in [-0.74, 0.74]:
		quad(p, 1.32, ceil_y - sill_y - 0.06, m["glass"], Vector3(wx, (ceil_y + sill_y) / 2.0, 0.02), Vector3.ZERO)
	for s in [-1.0, 1.0]:
		quad(p, cab_len - 0.55, ceil_y - sill_y - 0.06, m["glass"], Vector3(s * (half_w - 0.06), (ceil_y + sill_y) / 2.0, cab_len / 2.0), Vector3(0, PI / 2.0, 0))
	# back bulkhead
	var back_z := cab_len
	box(p, w, 0.88, 0.14, m["cab_wall"], 0, floor_y + 0.44, back_z)
	box(p, w, 0.35, 0.14, m["cab_wall"], 0, ceil_y - 0.17, back_z)
	box(p, 1.05, ceil_y - floor_y - 0.08, 0.24, m["console"], 0, (ceil_y + floor_y) / 2.0, back_z - 0.12)
	box(p, 0.96, 1.15, 0.03, m["cab_wall"], 0, -0.35, back_z - 0.245)
	cyl(p, 0.08, 0.08, 0.52, m["red"], Vector3(-0.62, -0.82, back_z - 0.14), 12)    # fire extinguisher
	for s in [-1.0, 1.0]:
		box(p, 0.36, ceil_y - floor_y, 0.14, m["cab_wall"], s * (half_w - 0.18), (ceil_y + floor_y) / 2.0, back_z)
	# doors
	var door_z := back_z - 0.44
	for s in [-1.0, 1.0]:
		box(p, 0.08, ceil_y - floor_y - 0.12, 0.72, m["door"], s * (half_w - 0.04), (ceil_y + floor_y) / 2.0, door_z)
		box(p, 0.04, 0.56, 0.44, m["glass"], s * (half_w - 0.03), 0.12, door_z)
		box(p, 0.12, 0.04, 0.16, m["brass"], s * (half_w - 0.08), -0.38, door_z - 0.22 * s)
	# step-down into the nose, cooler, restroom shell
	var nose_floor := floor_y - 0.32
	box(p, 0.72, 0.16, 0.32, m["floor"], -0.22, floor_y - 0.16, -0.18)
	box(p, 1.55, 0.08, 1.45, m["floor"], 0, nose_floor, -0.85)
	box(p, 0.44, 0.42, 0.64, m["cooler"], -0.52, nose_floor + 0.24, -0.68)
	box(p, 0.46, 0.06, 0.66, m["cooler_lid"], -0.52, nose_floor + 0.47, -0.68)
	box(p, 0.96, 1.12, 1.25, m["cab_wall"], 0.28, nose_floor + 0.56, -0.85)
	box(p, 0.06, 0.98, 0.56, m["door"], -0.21, nose_floor + 0.52, -0.78)
	# engineer's station (right)
	var eng_x := 0.86
	_seat(p, eng_x, floor_y, 1.18)
	var desk_y := -0.66
	var eng_desk_z := 0.46
	box(p, 1.05, 0.68, 0.62, m["console"], eng_x, floor_y + 0.34, eng_desk_z)
	box(p, 1.08, 0.05, 0.66, m["desk"], eng_x, desk_y, eng_desk_z)
	var ptc := quad(p, 0.36, 0.27, m["screen"], Vector3(eng_x - 0.12, desk_y + 0.16, eng_desk_z - 0.14), Vector3(-0.26, 0, 0))
	ptc_label = Label3D.new()
	ptc_label.font_size = 28
	ptc_label.pixel_size = 0.0011
	ptc_label.modulate = Color(0.45, 1.0, 0.6)
	ptc_label.outline_size = 0
	ptc_label.position = Vector3(0, 0, 0.004)
	ptc_label.shaded = false
	ptc_label.double_sided = false
	ptc.add_child(ptc_label)
	cyl(p, 0.065, 0.065, 0.045, m["alerter"], Vector3(eng_x + 0.28, desk_y + 0.045, eng_desk_z - 0.12), 16)
	var side_x := eng_x - 0.54
	var side_z := 0.96
	box(p, 0.28, 0.72, 0.86, m["console"], side_x, floor_y + 0.36, side_z)
	var gauge := quad(p, 0.56, 0.54, m["screen"], Vector3(side_x + 0.145, desk_y + 0.06, side_z), Vector3(0, PI / 2.0, 0))
	gauge_label = Label3D.new()
	gauge_label.font_size = 26
	gauge_label.pixel_size = 0.0012
	gauge_label.modulate = Color(1.0, 0.85, 0.4)
	gauge_label.outline_size = 0
	gauge_label.position = Vector3(0, 0, 0.004)
	gauge_label.shaded = false
	gauge_label.double_sided = false
	gauge.add_child(gauge_label)
	var sand := cyl(p, 0.045, 0.045, 0.04, m["sand_btn"], Vector3(side_x + 0.155, desk_y - 0.18, side_z - 0.22), 14)
	sand.rotation.z = -PI / 2.0
	lever_thr = box(p, 0.04, 0.18, 0.04, m["seat_trim"], side_x + 0.08, desk_y + 0.1, side_z - 0.14)
	lever_auto = box(p, 0.04, 0.16, 0.04, m["red"], side_x + 0.08, desk_y + 0.1, side_z + 0.08)
	box(p, 0.035, 0.14, 0.035, m["sand_btn"], side_x + 0.08, desk_y + 0.09, side_z + 0.24)
	# conductor's station (left): two tandem seats, desk, radio, horn button
	var cond_x := -0.86
	_seat(p, cond_x, floor_y, 1.18)
	_seat(p, cond_x, floor_y, 1.92)
	var cond_desk_z := 0.48
	box(p, 0.98, 0.66, 0.56, m["console"], cond_x, floor_y + 0.33, cond_desk_z)
	box(p, 1.02, 0.05, 0.6, m["desk"], cond_x, desk_y, cond_desk_z)
	quad(p, 0.36, 0.27, m["screen"], Vector3(cond_x + 0.14, desk_y + 0.16, cond_desk_z - 0.12), Vector3(-0.26, 0, 0))
	cyl(p, 0.055, 0.055, 0.045, m["horn_btn"], Vector3(cond_x - 0.22, desk_y + 0.045, cond_desk_z - 0.08), 16)
	box(p, 0.24, 0.1, 0.16, m["console"], cond_x - 0.24, desk_y + 0.07, cond_desk_z + 0.14)
	box(p, 0.06, 0.14, 0.05, m["black"], cond_x - 0.36, desk_y + 0.09, cond_desk_z + 0.14)
	# wipers
	for wx in [-0.72, 0.72]:
		var piv := Node3D.new()
		piv.position = Vector3(wx, sill_y + 0.04, -0.04)
		p.add_child(piv)
		box(piv, 0.025, 0.56, 0.025, m["black"], 0, 0.28, 0)
		box(piv, 0.02, 0.48, 0.03, m["black"], 0, 0.32, -0.015)
		piv.rotation.z = 1.25 if wx > 0 else -1.25
		wipers.append(piv)
	# exterior side mirrors
	for side in [-1.0, 1.0]:
		var mg := Node3D.new()
		mg.position = Vector3(side * (half_w + 0.18), -0.05, 0.22)
		p.add_child(mg)
		tube(mg, Vector3(-side * 0.18, 0.26, 0), Vector3(0, 0.26, 0), 0.016, m["mirror_frame"])
		tube(mg, Vector3(-side * 0.18, -0.26, 0), Vector3(0, -0.26, 0), 0.016, m["mirror_frame"])
		var housing := box(mg, 0.14, 0.54, 0.045, m["mirror_frame"], 0, 0, 0)
		housing.rotation.y = side * -0.34
		var g2 := quad(mg, 0.115, 0.5, m["mirror_glass"], Vector3(0, 0, 0.025), Vector3(0, side * -0.34, 0))
		g2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Called every frame with the game state so levers and screens move.
func update(throttle: int, brake: int, emergency: bool, mph: int, limit: int, bp: float, bc: float, next_txt: String) -> void:
	if lever_thr:
		lever_thr.rotation.x = -0.6 + throttle * 0.15
	if lever_auto:
		lever_auto.rotation.x = -0.5 + (1.4 if emergency else brake * 0.2)
	if ptc_label:
		ptc_label.text = "PTC  %d / %d MPH\n%s" % [mph, limit, next_txt]
	if gauge_label:
		gauge_label.text = "BP %d\nBC %d\nN%d" % [int(bp), int(bc), throttle]
