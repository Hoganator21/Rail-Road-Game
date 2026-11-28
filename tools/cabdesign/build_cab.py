"""SD70ACe cab interior, design prototype.

Built in Blender from script so it can be re-run after every design change.
Coordinates: helper g(x, y, z) takes GAME coordinates (x right, y up, -z forward,
eye at (0.86, 0, 1.12), cab front wall at z=0) and returns Blender coordinates.
"""
import math
import sys
import bpy
import bmesh
from mathutils import Vector, Euler

TEX = "/home/claude/rail-road-game/godot/textures/"
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/cab"
VIEW = sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else "eng"
LAYOUT = sys.argv[sys.argv.index("--") + 4] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 4 else "stand"
SAMPLES = int(sys.argv[sys.argv.index("--") + 3]) if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 3 else 48


def g(x, y, z):
    return Vector((x, -z, y))


# ------------------------------------------------------------------ scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
col = scene.collection


# ------------------------------------------------------------------ materials
_mats = {}


def mat_tex(name, img, scale=1.0, rough=0.7, metal=0.0, tint=None, bump=0.0):
    """Box-projected image texture (triplanar-like) for unwrapped design boxes."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(TEX + img, check_existing=True)
    im.projection = "BOX"
    im.projection_blend = 0.25
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], im.inputs["Vector"])
    if tint:
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[7].default_value = (*tint, 1.0)
        nt.links.new(im.outputs["Color"], mix.inputs[6])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    else:
        nt.links.new(im.outputs["Color"], bsdf.inputs["Base Color"])
    # roughness varies with the grime in the texture
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = rough + 0.12
    rr.inputs["To Max"].default_value = rough - 0.12
    nt.links.new(im.outputs["Color"], rr.inputs["Value"])
    nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = metal
    if bump > 0:
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        bp.inputs["Distance"].default_value = 0.002
        nt.links.new(im.outputs["Color"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    _mats[name] = m
    return m


def mat_col(name, c, rough=0.6, metal=0.0, emit=0.0, alpha=1.0, trans=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*c, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    if trans > 0:
        b.inputs["Transmission Weight"].default_value = trans
        b.inputs["IOR"].default_value = 1.52
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    _mats[name] = m
    return m


def mat_img(name, img, rough=0.6, emit=0.0):
    """UV-mapped image (decals, gauge faces, screens, overhead panel)."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    im = nt.nodes.new("ShaderNodeTexImage")
    im.image = bpy.data.images.load(img if img.startswith("/") else TEX + img, check_existing=True)
    im.interpolation = "Cubic"
    nt.links.new(im.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(im.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        nt.links.new(im.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit
    _mats[name] = m
    return m


TAN = (0.80, 0.71, 0.55)
M = {}
M["wall"] = mat_tex("wall", "cab_wall_tan.png", 1.6, 0.62, 0.05, bump=0.15)
M["ceil"] = mat_tex("ceil", "ceiling_tan.png", 1.4, 0.85, bump=0.25)
M["stand"] = mat_tex("stand", "stand_brown.png", 1.5, 0.45, 0.25, bump=0.12)
M["console"] = mat_tex("console", "console_black.png", 2.5, 0.5, 0.2)
M["floor"] = mat_tex("floor", "cab_mat.png", 3.0, 0.9, bump=0.6)
M["seat"] = mat_tex("seat", "seat_black.png", 3.5, 0.8, bump=0.3, tint=(4.5, 4.5, 4.8))
M["vinyl"] = mat_col("vinyl", (0.025, 0.025, 0.027), 0.45)
M["rubber"] = mat_col("rubber", (0.012, 0.012, 0.012), 0.75)
M["chrome"] = mat_col("chrome", (0.85, 0.85, 0.83), 0.12, 1.0)
M["steel"] = mat_col("steel", (0.45, 0.44, 0.42), 0.35, 0.9)
M["cast"] = mat_col("cast", (0.05, 0.05, 0.055), 0.55, 0.6)
M["black"] = mat_col("black", (0.015, 0.015, 0.017), 0.5)
M["red"] = mat_col("red", (0.55, 0.04, 0.03), 0.35)
M["red_radio"] = mat_col("red_radio", (0.62, 0.1, 0.06), 0.4)
M["yellow"] = mat_col("yellow", (0.85, 0.62, 0.05), 0.4)
M["alerter"] = mat_col("alerter", (1.0, 0.75, 0.1), 0.3, emit=0.6)
M["knob_red"] = mat_col("knob_red", (0.6, 0.03, 0.02), 0.25)
M["grip"] = mat_col("grip", (0.02, 0.02, 0.02), 0.3)
M["glass"] = mat_col("glass", (0.6, 0.66, 0.7), 0.03, alpha=0.08)
M["bottle"] = mat_col("bottle", (0.9, 0.95, 1.0), 0.05, trans=1.0)
M["dome"] = mat_col("dome", (1.0, 0.95, 0.85), 0.3, emit=3.0)
M["lcd"] = mat_col("lcd", (0.35, 0.9, 0.35), 0.3, emit=2.0)
M["led_red"] = mat_col("led_red", (1.0, 0.12, 0.05), 0.3, emit=4.0)
M["paper"] = mat_img("paper", "paper.png", 0.8)
M["overhead"] = mat_img("overhead", "overhead_tan.png", 0.65)
M["g_speed"] = mat_img("g_speed", "gauge_speed.png", 0.4)
M["g_er"] = mat_img("g_er", "gauge_air_er.png", 0.4)
M["g_mr"] = mat_img("g_mr", "gauge_air_mr.png", 0.4)
M["fkeys"] = mat_img("fkeys", "fkeys.png", 0.6)
M["switches"] = mat_img("switches", "switch_panel.png", 0.5)
M["hood"] = mat_tex("hood", "hood.png", 0.4, 0.6, 0.1)
M["handrail"] = mat_col("handrail", (0.85, 0.66, 0.05), 0.45)
M["deck"] = mat_col("deck", (0.08, 0.08, 0.085), 0.8, 0.3)


# ------------------------------------------------------------------ mesh helpers
def finish(o, mat, bevel=0.0, segs=3, smooth=True):
    o.data.materials.clear()
    o.data.materials.append(mat)
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
        b.harden_normals = True
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
        if bevel > 0:
            o.modifiers.new("wn", "WEIGHTED_NORMAL").keep_sharp = True
    return o


def box(name, size_game, pos_game, mat, bevel=0.006, rot_game=(0, 0, 0), parent=None):
    """size/pos in game coordinates (w, h, d) / (x, y, z)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size_game[0], size_game[2], size_game[1])
    bpy.ops.object.transform_apply(scale=True)
    o.location = g(*pos_game)
    o.rotation_euler = Euler((rot_game[0], -rot_game[2], rot_game[1]), "XYZ") if any(rot_game) else Euler((0, 0, 0))
    if parent:
        o.parent = parent
    return finish(o, mat, bevel)


def cyl(name, r, h, pos_game, mat, axis="y", segs=32, bevel=0.0, r2=None):
    """Cylinder along a game axis."""
    bpy.ops.mesh.primitive_cone_add(vertices=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = bpy.context.active_object
    o.name = name
    o.location = g(*pos_game)
    if axis == "y":
        o.rotation_euler = (0, 0, 0)
    elif axis == "x":
        o.rotation_euler = (0, math.pi / 2, 0)
    else:   # z (fore-aft)
        o.rotation_euler = (math.pi / 2, 0, 0)
    return finish(o, mat, bevel)


def sphere(name, r, pos_game, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=24, ring_count=12)
    o = bpy.context.active_object
    o.name = name
    o.location = g(*pos_game)
    return finish(o, mat)


def tube(name, a, b, r, mat, segs=16):
    a = g(*a)
    b = g(*b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=segs, radius=r, depth=d.length)
    o = bpy.context.active_object
    o.name = name
    o.location = (a + b) / 2
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return finish(o, mat)


def plane(name, w, h, pos_game, mat, rot_game=(0, 0, 0)):
    """Quad in the game XY plane facing +z (toward the seats), then rotated."""
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = (w, h, 1)
    bpy.ops.object.transform_apply(scale=True)
    # plane is in blender XY facing +Z; turn it to face game +z (= blender -Y)
    o.rotation_euler = Euler((math.pi / 2 + rot_game[0], -rot_game[2], rot_game[1]), "XYZ")
    o.location = g(*pos_game)
    return finish(o, mat, smooth=False)


def rounded_rect_cutter(name, w, h, r, depth, pos_game):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = (w, depth, h)
    bpy.ops.object.transform_apply(scale=True)
    o.location = g(*pos_game)
    bv = o.modifiers.new("round", "BEVEL")
    bv.width = r
    bv.segments = 10
    bv.affect = "EDGES"
    # only the 4 edges parallel to the depth axis (blender Y)
    bpy.ops.object.modifier_apply(modifier="round") if False else None
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    edges = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().y) > 0.9]
    bmesh.ops.bevel(bm, geom=edges, offset=r, segments=10, affect="EDGES", profile=0.5)
    bm.to_mesh(me)
    bm.free()
    o.modifiers.clear()
    return o


def cut(target, cutter):
    m = target.modifiers.new("cut_" + cutter.name, "BOOLEAN")
    m.object = cutter
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    cutter.hide_render = True
    cutter.hide_viewport = True


def gasket(name, w, h, r, pos_game, thick=0.035, depth=0.06):
    outer = rounded_rect_cutter(name, w + 2 * thick, h + 2 * thick, r + thick, depth, pos_game)
    inner = rounded_rect_cutter(name + "_in", w, h, r, depth * 2, pos_game)
    finish(outer, M["rubber"], smooth=True)
    cut(outer, inner)
    return outer


# ------------------------------------------------------------------ cab shell
W = 3.16
HW = W / 2
CAB_LEN = 2.8
FLOOR = -1.35
CEIL = 0.62
SILL = -0.21        # pane bottom 45 in above the cab floor; 17 in tall pane (0.43 m)
TOP = 0.22
WIN_W = 1.31         # 51.5 in wide
WIN_XS = (-0.8, 0.8)
DOOR_W = 0.62
WELL = FLOOR - 0.42          # two steps down into the nose stairwell
DOOR_TOP = SILL - 0.05       # the nose door sits under the windshields
WELL_X = 0.36                # half width of the stairwell
WELL_Z = 0.62                # how far back from the front wall the well reaches

flr = box("floor", (W, 0.06, CAB_LEN), (0, FLOOR - 0.03, CAB_LEN / 2), M["floor"], 0.0)
cut(flr, box("well_cut", (2 * WELL_X, 0.4, WELL_Z * 2), (0, FLOOR, 0.0), M["floor"], 0.0))
box("ceiling", (W, 0.05, CAB_LEN), (0, CEIL + 0.025, CAB_LEN / 2), M["ceil"], 0.0)
for rz in (0.75, 1.55, 2.3):
    box("rib", (W, 0.035, 0.07), (0, CEIL - 0.02, rz), M["wall"], 0.01)
# front wall with two rounded windshield openings
front = box("front_wall", (W, CEIL - WELL, 0.1), (0, (CEIL + WELL) / 2, 0.0), M["wall"], 0.0)
for i, x in enumerate(WIN_XS):
    c = rounded_rect_cutter("win_cut%d" % i, WIN_W, TOP - SILL, 0.1, 0.4, (x, (TOP + SILL) / 2, 0.0))
    cut(front, c)
    gasket("gasket%d" % i, WIN_W, TOP - SILL, 0.1, (x, (TOP + SILL) / 2, 0.03))
    gl = box("windshield%d" % i, (WIN_W + 0.02, TOP - SILL + 0.02, 0.012), (x, (TOP + SILL) / 2, -0.01), M["glass"], 0.0)
# side walls with sliding windows
SIDE_SILL = -0.32   # side sliding windows stay larger
for s in (-1, 1):
    sw = box("side_wall%d" % s, (0.1, CEIL - FLOOR, CAB_LEN), (s * (HW - 0.05), (CEIL + FLOOR) / 2, CAB_LEN / 2), M["wall"], 0.0)
    c = rounded_rect_cutter("sidecut%d" % s, 1.4, TOP - SIDE_SILL, 0.08, 0.5, (s * (HW - 0.05), (TOP + SIDE_SILL) / 2, 1.0))
    c.rotation_euler = (0, 0, math.pi / 2)
    cut(sw, c)
    g2 = gasket("sidegasket%d" % s, 1.4, TOP - SIDE_SILL, 0.08, (s * (HW - 0.09), (TOP + SIDE_SILL) / 2, 1.0), 0.03, 0.05)
    g2.rotation_euler = (0, 0, math.pi / 2)
    box("sideglass%d" % s, (0.012, TOP - SIDE_SILL + 0.02, 1.42), (s * (HW - 0.02), (TOP + SIDE_SILL) / 2, 1.0), M["glass"], 0.0)
    box("sidetrack%d" % s, (0.07, 0.025, 1.45), (s * (HW - 0.12), SIDE_SILL - 0.02, 1.0), M["chrome"], 0.004)
    box("sidelatch%d" % s, (0.03, 0.12, 0.03), (s * (HW - 0.12), (TOP + SIDE_SILL) / 2, 0.32), M["chrome"], 0.005)
# ---- stairwell: two steps down to the nose door, which sits under the windshields
box("well_floor", (2 * WELL_X, 0.05, WELL_Z / 2), (0, WELL - 0.025, WELL_Z / 4), M["floor"], 0.0)
box("well_step", (2 * WELL_X, 0.05, WELL_Z / 2), (0, FLOOR - 0.21 - 0.025, WELL_Z * 0.75), M["floor"], 0.0)
box("well_riser1", (2 * WELL_X, 0.21, 0.03), (0, FLOOR - 0.105, WELL_Z), M["steel"], 0.004)
box("well_riser2", (2 * WELL_X, 0.21, 0.03), (0, FLOOR - 0.315, WELL_Z / 2), M["steel"], 0.004)
for sx in (-1, 1):
    box("well_side", (0.04, 0.45, WELL_Z), (sx * WELL_X, FLOOR - 0.2, WELL_Z / 2), M["stand"], 0.006)
    box("step_edge", (2 * WELL_X, 0.012, 0.04), (0, FLOOR - 0.005 - (0.21 if sx > 0 else 0.0), WELL_Z if sx < 0 else WELL_Z / 2), M["yellow"], 0.003)
dc = box("door_cut", (DOOR_W, DOOR_TOP - WELL + 0.05, 0.4), (0, (DOOR_TOP + WELL) / 2 - 0.02, 0.0), M["wall"], 0.0)
cut(front, dc)
leaf = box("door_leaf", (DOOR_W - 0.03, DOOR_TOP - WELL - 0.03, 0.045), (0, (DOOR_TOP + WELL) / 2, -0.02), M["wall"], 0.012)
dw = rounded_rect_cutter("door_win_cut", 0.3, 0.3, 0.04, 0.3, (0, DOOR_TOP - 0.28, -0.02))
cut(leaf, dw)
box("door_glass", (0.32, 0.32, 0.01), (0, DOOR_TOP - 0.28, -0.02), M["glass"], 0.0)
gasket("door_gasket", 0.3, 0.3, 0.04, (0, DOOR_TOP - 0.28, 0.005), 0.022, 0.04)
for gx, gy, gw, gh in ((-DOOR_W / 2 + 0.01, (DOOR_TOP + WELL) / 2, 0.012, DOOR_TOP - WELL), (DOOR_W / 2 - 0.01, (DOOR_TOP + WELL) / 2, 0.012, DOOR_TOP - WELL), (0, DOOR_TOP - 0.01, DOOR_W, 0.012)):
    box("door_seam", (gw, gh, 0.03), (gx, gy, 0.002), M["black"], 0.0)
box("door_handle", (0.035, 0.16, 0.05), (0.22, WELL + 0.75, 0.03), M["chrome"], 0.01)
box("door_kick", (DOOR_W - 0.08, 0.25, 0.01), (0, WELL + 0.15, 0.005), M["steel"], 0.005)
box("door_caution", (0.2, 0.1, 0.004), (0, WELL + 0.95, 0.003), M["yellow"], 0.0)
for hy in (WELL + 0.2, DOOR_TOP - 0.2):
    box("hinge", (0.04, 0.12, 0.05), (-DOOR_W / 2 + 0.03, hy, 0.03), M["steel"], 0.008)
# yellow/black striped grab bar across the top of the well, at windshield sill height
n_str = 12
for k in range(n_str):
    xa = -WELL_X + 2 * WELL_X * k / n_str
    tube("grab%d" % k, (xa, SILL - 0.12, 0.09), (xa + 2 * WELL_X / n_str, SILL - 0.12, 0.09), 0.022, M["yellow"] if k % 2 == 0 else M["black"])
for sx in (-1, 1):
    box("grab_mount", (0.05, 0.08, 0.1), (sx * (WELL_X + 0.02), SILL - 0.12, 0.06), M["steel"], 0.01)
box("center_post", (0.28, TOP - SILL + 0.1, 0.07), (0, (TOP + SILL) / 2, 0.03), M["wall"], 0.015)
box("sill_shelf", (W - 0.2, 0.03, 0.14), (0, SILL - 0.015, 0.07), M["wall"], 0.008)
box("back_wall", (W, CEIL - FLOOR, 0.1), (0, (CEIL + FLOOR) / 2, CAB_LEN), M["wall"], 0.0)

# ------------------------------------------------------------------ overhead console (angled face like the photos)
ov_bot = TOP + 0.06    # strip of wall between the glass and the console
box("overhead_body", (W - 0.12, CEIL - ov_bot, 0.46), (0, (CEIL + ov_bot) / 2, 0.29), M["wall"], 0.02)
face_h = CEIL - ov_bot + 0.1
face_y = (CEIL + ov_bot) / 2 - 0.05
fc = box("overhead_face", (W - 0.14, face_h, 0.04), (0, face_y, 0.53), M["wall"], 0.015, rot_game=(0.28, 0, 0))
px_per_m = 512.0 / face_h
for k, (a, b, xc) in enumerate(((0, 560, -0.95), (560, 1330, 0.02), (1330, 2048, 0.98))):
    p = plane("ohpanel%d" % k, (b - a) / px_per_m, face_h, (xc, face_y, 0.0), M["overhead"])
    p.parent = fc
    p.matrix_parent_inverse = fc.matrix_world.inverted()
    p.location = fc.location + (fc.rotation_euler.to_matrix() @ Vector((xc, -0.022, 0)))
    p.rotation_euler = (fc.rotation_euler.x + math.pi / 2, 0, 0)
    uv = p.data.uv_layers.active.data
    for li, loop in enumerate(p.data.loops):
        u, v = uv[li].uv
        uv[li].uv = (a / 2048 + u * (b - a) / 2048, v)

# sun visors (padded, folded up under the overhead)
for i, x in enumerate(WIN_XS):
    vx = x + (0.2 if i else -0.2)
    v = box("visor%d" % i, (0.52, 0.035, 0.28), (vx, TOP - 0.05, 0.25), M["vinyl"], 0.012, rot_game=(-0.25, 0, 0))
    tube("visor_rod%d" % i, (vx - 0.28, TOP - 0.03, 0.12), (vx - 0.28, TOP + 0.04, 0.12), 0.008, M["steel"])
# dome lights
for z in (1.0, 1.95):
    box("dome_base", (0.36, 0.05, 0.22), (0.1, CEIL - 0.03, z), M["black"], 0.01)
    box("dome_lens", (0.3, 0.025, 0.16), (0.1, CEIL - 0.065, z), M["dome"], 0.008)
# wipers hanging outside the glass
for i, x in enumerate(WIN_XS):
    side = -1 if x < 0 else 1
    wx = x + side * WIN_W * 0.4
    # pantograph arm parked along the outer edge of the glass, blade nearly vertical
    wx = x + side * (WIN_W / 2 - 0.12)
    tube("wiper_arm%d" % i, (wx, TOP + 0.02, -0.08), (wx - side * 0.07, SILL + 0.2, -0.08), 0.006, M["black"])
    tube("wiper_arm2_%d" % i, (wx - side * 0.05, TOP + 0.02, -0.08), (wx - side * 0.11, SILL + 0.22, -0.08), 0.004, M["black"])
    box("wiper_blade%d" % i, (0.018, (TOP - SILL) * 0.55, 0.015), (wx - side * 0.09, (TOP + SILL) / 2 - 0.08, -0.095), M["rubber"], 0.004, rot_game=(0, 0, side * 0.08))
    box("wiper_motor%d" % i, (0.1, 0.07, 0.08), (wx, TOP + 0.03, 0.07), M["black"], 0.012)

def layout_stand():
    # ------------------------------------------------------------------ AAR control stand (engineer's left)
    SX, SZ = 0.6, 0.45
    TOPY = -0.36
    box("stand_body", (0.42, TOPY - FLOOR, 1.0), (SX, (TOPY + FLOOR) / 2, SZ + 0.18), M["stand"], 0.035)
    box("stand_cap", (0.44, 0.03, 1.02), (SX, TOPY + 0.01, SZ + 0.18), M["cast"], 0.01)
    # gauge housing angled toward the engineer
    gh = box("gauge_housing", (0.52, 0.22, 0.12), (SX + 0.05, TOPY + 0.05, SZ - 0.2), M["stand"], 0.03, rot_game=(-0.35, 0.55, 0))
    gmat = gh.matrix_world.copy()
    bpy.context.view_layer.update()
    gm = gh.matrix_world


    def on_housing(local):
        return gm @ Vector(local)


    for k, (gx, gmat_key) in enumerate(((-0.165, "g_speed"), (0.0, "g_er"), (0.165, "g_mr"))):
        # local coords of the housing (blender): x across, -y toward the engineer (front face)
        cpos = on_housing((gx, -0.065, 0.0))
        bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.068, depth=0.03, location=cpos)
        can = bpy.context.active_object
        can.rotation_euler = gh.rotation_euler.copy()
        can.rotation_euler.rotate_axis("X", math.pi / 2)
        finish(can, M["black"], 0.004)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.008, major_segments=48, minor_segments=12, location=on_housing((gx, -0.082, 0.0)))
        ring = bpy.context.active_object
        ring.rotation_euler = gh.rotation_euler.copy()
        ring.rotation_euler.rotate_axis("X", math.pi / 2)
        finish(ring, M["chrome"])
        bpy.ops.mesh.primitive_circle_add(vertices=48, radius=0.064, fill_type="NGON", location=on_housing((gx, -0.081, 0.0)))
        face = bpy.context.active_object
        face.rotation_euler = gh.rotation_euler.copy()
        face.rotation_euler.rotate_axis("X", math.pi / 2)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.uv.cube_project()
        bpy.ops.object.mode_set(mode="OBJECT")
        # simple planar UV for the disc
        for li, loop in enumerate(face.data.loops):
            co = face.data.vertices[loop.vertex_index].co
            face.data.uv_layers.active.data[li].uv = (co.x / 0.128 + 0.5, co.y / 0.128 + 0.5)
        finish(face, M[gmat_key], smooth=False)
    # red radio on top of the stand
    box("radio", (0.22, 0.09, 0.15), (SX - 0.08, TOPY + 0.07, SZ + 0.2), M["red_radio"], 0.012, rot_game=(0, 0.5, 0))
    box("radio_lcd", (0.09, 0.03, 0.004), (SX - 0.05, TOPY + 0.09, SZ + 0.27), M["lcd"], 0.0, rot_game=(0, 0.5, 0))
    # right face of the stand: notch plate, throttle, dynamic brake, reverser, CCB valves
    FX = SX + 0.21
    box("notch_plate", (0.015, 0.07, 0.3), (FX, -0.5, SZ - 0.07), M["cast"], 0.006)
    for i in range(9):
        a = i / 8.0 * 0.9
        box("notch%d" % i, (0.02, 0.02, 0.008), (FX + 0.012, -0.46, SZ - 0.05 - math.sin(a) * 0.13), M["chrome"], 0.002)


    def lever(name, base, length, knob_mat, knob_r, yaw=0.0, grip=False):
        end = (base[0] + math.cos(yaw) * length, base[1] + 0.02, base[2] - math.sin(yaw) * length)
        cyl(name + "_collar", 0.024, 0.03, (base[0] + 0.012, base[1], base[2]), M["cast"], axis="x", segs=24, bevel=0.003)
        tube(name + "_shaft", base, end, 0.011, M["chrome"])
        if grip:
            tube(name + "_grip", end, (end[0] + 0.07, end[1] + 0.005, end[2]), 0.02, knob_mat)
        else:
            sphere(name + "_knob", knob_r, end, knob_mat)


    lever("throttle", (FX, -0.5, SZ - 0.05), 0.17, M["grip"], 0.02, yaw=0.15, grip=True)
    lever("dynbrake", (FX, -0.42, SZ + 0.12), 0.14, M["grip"], 0.024)
    lever("reverser", (FX, -0.62, SZ - 0.22), 0.09, M["black"], 0.018)
    box("ccb_shelf", (0.22, 0.04, 0.5), (FX + 0.1, -0.72, SZ), M["cast"], 0.008)
    for k, (dz, knob, ln) in enumerate(((-0.1, M["knob_red"], 0.2), (0.15, M["chrome"], 0.16))):
        box("valve%d" % k, (0.2, 0.1, 0.2), (FX + 0.1, -0.65, SZ + dz), M["cast"], 0.02)
        cyl("valve_dome%d" % k, 0.09, 0.035, (FX + 0.1, -0.585, SZ + dz), M["cast"], bevel=0.008)
        lever("brake%d" % k, (FX + 0.1, -0.55, SZ + dz), ln, knob, 0.03, yaw=-0.25)
    plane("switchpanel", 0.34, 0.18, (FX + 0.002, -0.88, SZ), M["switches"], rot_game=(0, math.pi / 2, 0))
    # handset with coiled cord on the back of the stand
    box("handset_cradle", (0.08, 0.22, 0.05), (SX, -0.6, SZ + 0.34), M["black"], 0.01)
    box("handset", (0.05, 0.22, 0.04), (SX, -0.6, SZ + 0.375), M["vinyl"], 0.015)
    for k in range(28):
        t = k / 28.0
        sphere("cord%d" % k, 0.009, (SX + math.sin(t * 60) * 0.016, -0.73 - t * 0.35, SZ + 0.38 + math.cos(t * 60) * 0.016), M["black"])

    # ------------------------------------------------------------------ engineer's front desk with displays
    DESK = -0.56     # desk front edge ~31 in off the floor
    DX = 1.19
    box("desk_body", (0.68, DESK - FLOOR, 0.52), (DX, (DESK + FLOOR) / 2, 0.31), M["stand"], 0.03)
    box("desk_top", (0.72, 0.04, 0.56), (DX, DESK + 0.02, 0.31), M["console"], 0.012)
    dp = box("display_pod", (0.68, 0.3, 0.1), (DX, DESK + 0.2, 0.12), M["stand"], 0.025, rot_game=(-0.5, 0, 0))
    for k, (dx, img) in enumerate(((-0.165, "/tmp/cabdesign/scr_eng.png"), (0.165, "/tmp/cabdesign/scr_ptc.png"))):
        a = -0.5
        nrm = (0.0, -math.sin(a), math.cos(a))          # game-space normal of the tilted pod face
        c0 = (DX + dx, DESK + 0.2 + nrm[1] * 0.06, 0.12 + nrm[2] * 0.06)
        bez = box("bezel%d" % k, (0.31, 0.25, 0.03), c0, M["black"], 0.012, rot_game=(a, 0, 0))
        scr = plane("screen%d" % k, 0.27, 0.2, (c0[0], c0[1] + nrm[1] * 0.017, c0[2] + nrm[2] * 0.017), mat_img("scr%d" % k, img, 0.2, emit=1.4), rot_game=(a, 0, 0))
        fk = plane("fkeys%d" % k, 0.26, 0.028, (c0[0], c0[1] - 0.135 * math.cos(a) + nrm[1] * 0.017, c0[2] - 0.135 * math.sin(a) + nrm[2] * 0.017), M["fkeys"], rot_game=(a, 0, 0))
    # alerter + water bottle + track warrant
    box("alerter_base", (0.12, 0.03, 0.09), (0.95, DESK + 0.055, 0.5), M["cast"], 0.01)
    cyl("alerter", 0.032, 0.03, (0.95, DESK + 0.085, 0.5), M["alerter"], bevel=0.006)
    cyl("bottle", 0.032, 0.2, (1.45, DESK + 0.14, 0.48), M["bottle"], bevel=0.01)
    cyl("bottle_cap", 0.014, 0.025, (1.45, DESK + 0.255, 0.48), M["red"])
    p = plane("warrant", 0.2, 0.27, (1.2, DESK + 0.045, 0.45), M["paper"], rot_game=(-math.pi / 2, -0.15, 0))



def layout_console():
    """EMD desk console across the engineer's front (UP 4450 / SD70M style):
    brown housing, black angled gauge panel, controls on the desk top."""
    x0, x1 = 0.42, 1.52
    cx = (x0 + x1) / 2
    w = x1 - x0
    top = -0.56
    box("con_body", (w, top - FLOOR, 0.62), (cx, (top + FLOOR) / 2, 0.38), M["stand"], 0.03)
    box("con_desk", (w + 0.04, 0.04, 0.64), (cx, top + 0.02, 0.4), M["stand"], 0.015)
    box("con_left_wall", (0.06, 0.42, 0.62), (x0 + 0.03, top + 0.2, 0.38), M["stand"], 0.02)
    # raised black gauge panel along the windshield side, tilted toward the engineer
    a = -0.55
    gp = box("con_gauge_panel", (w - 0.1, 0.3, 0.06), (cx + 0.02, top + 0.2, 0.15), M["cast"], 0.02, rot_game=(a, 0, 0))
    nrm = (0.0, -math.sin(a), math.cos(a))
    for k, (gx, key) in enumerate(((0.8, "g_speed"), (0.98, "g_er"), (1.14, "g_mr"), (1.3, "g_er"), (1.45, "g_mr"))):
        r = 0.07 if k == 0 else 0.058
        c = (gx, top + 0.2 + nrm[1] * 0.035, 0.15 + nrm[2] * 0.035)
        can = cyl("cg_can%d" % k, r * 1.08, 0.03, c, M["black"], axis="z", segs=40, bevel=0.004)
        can.rotation_euler.x += a
        ring = cyl("cg_ring%d" % k, r * 1.14, 0.012, (c[0], c[1] + nrm[1] * 0.012, c[2] + nrm[2] * 0.012), M["chrome"], axis="z", segs=48, bevel=0.004)
        ring.rotation_euler.x += a
        bpy.ops.mesh.primitive_circle_add(vertices=48, radius=r * 0.95, fill_type="NGON", location=g(c[0], c[1] + nrm[1] * 0.02, c[2] + nrm[2] * 0.02))
        face = bpy.context.active_object
        face.rotation_euler = Euler((math.pi / 2 + a, 0, 0), "XYZ")
        for li, loop in enumerate(face.data.loops):
            co = face.data.vertices[loop.vertex_index].co
            face.data.uv_layers.active.data[li].uv = (co.x / (2 * r * 0.95) + 0.5, co.y / (2 * r * 0.95) + 0.5)
        finish(face, M[key], smooth=False)
    for k in range(6):   # indicator lamps along the top of the panel
        box("lamp%d" % k, (0.025, 0.025, 0.02), (0.8 + k * 0.05, top + 0.33, 0.1), M["led_red"] if k % 3 == 0 else M["lcd"], 0.004, rot_game=(a, 0, 0))
    plane("con_switches", 0.2, 0.18, (0.6, top + 0.2 + nrm[1] * 0.035, 0.15 + nrm[2] * 0.035), M["switches"], rot_game=(a, 0, 0))
    # desk-top controls: throttle/dynamic, reverser, 26L automatic + independent
    box("thr_base", (0.14, 0.05, 0.22), (0.85, top + 0.05, 0.42), M["cast"], 0.015)
    tube("thr_shaft", (0.85, top + 0.07, 0.44), (0.85, top + 0.2, 0.40), 0.011, M["chrome"])
    sphere("thr_knob", 0.026, (0.85, top + 0.21, 0.40), M["grip"])
    box("rev_base", (0.08, 0.04, 0.1), (0.7, top + 0.04, 0.45), M["cast"], 0.01)
    tube("rev_shaft", (0.7, top + 0.06, 0.45), (0.7, top + 0.14, 0.42), 0.009, M["chrome"])
    box("brake_base", (0.26, 0.07, 0.22), (1.28, top + 0.06, 0.42), M["cast"], 0.02)
    cyl("brake_dome", 0.1, 0.04, (1.24, top + 0.11, 0.42), M["cast"], bevel=0.008)
    tube("auto_shaft", (1.24, top + 0.13, 0.42), (1.2, top + 0.25, 0.36), 0.012, M["chrome"])
    sphere("auto_knob", 0.03, (1.2, top + 0.26, 0.36), M["knob_red"])
    tube("ind_shaft", (1.38, top + 0.12, 0.45), (1.4, top + 0.22, 0.4), 0.011, M["chrome"])
    sphere("ind_knob", 0.026, (1.4, top + 0.23, 0.4), M["grip"])
    box("alerter_base", (0.12, 0.03, 0.09), (1.05, top + 0.055, 0.55), M["cast"], 0.01)
    cyl("alerter", 0.032, 0.03, (1.05, top + 0.085, 0.55), M["alerter"], bevel=0.006)
    box("cupholder", (0.12, 0.02, 0.12), (0.5, top + 0.045, 0.55), M["cast"], 0.01)
    # handset on the console's left side, PTC display hung above the left corner
    box("handset_cradle", (0.05, 0.22, 0.08), (x0 - 0.01, top - 0.15, 0.5), M["black"], 0.01)
    box("handset", (0.04, 0.22, 0.05), (x0 - 0.04, top - 0.15, 0.5), M["vinyl"], 0.015)
    for k in range(28):
        t = k / 28.0
        sphere("cord%d" % k, 0.009, (x0 - 0.04 + math.cos(t * 60) * 0.016, top - 0.28 - t * 0.35, 0.5 + math.sin(t * 60) * 0.016), M["black"])
    bez = box("ptc_box", (0.36, 0.28, 0.05), (1.55, top + 0.62, 0.15), M["black"], 0.015, rot_game=(-0.2, -0.45, 0))
    scr = plane("ptc_scr", 0.3, 0.22, (1.535, top + 0.625, 0.175), mat_img("scr1", "/tmp/cabdesign/scr_ptc.png", 0.2, emit=1.4), rot_game=(-0.2, -0.45, 0))


def layout_desktop():
    """Modern desktop cab: one wide desk, two displays, throttle and brakes on desk wings."""
    x0, x1 = 0.42, 1.52
    cx = (x0 + x1) / 2
    top = -0.56
    box("dt_body", (x1 - x0, top - FLOOR, 0.55), (cx, (top + FLOOR) / 2, 0.32), M["stand"], 0.03)
    box("dt_top", (x1 - x0 + 0.04, 0.04, 0.6), (cx, top + 0.02, 0.33), M["console"], 0.012)
    box("dt_wing_l", (0.24, 0.1, 0.5), (x0 + 0.14, top + 0.06, 0.72), M["stand"], 0.03)
    box("dt_wing_r", (0.26, 0.1, 0.55), (x1 - 0.12, top + 0.06, 0.74), M["stand"], 0.03)
    a = -0.5
    nrm = (0.0, -math.sin(a), math.cos(a))
    box("dt_pod", (x1 - x0 - 0.06, 0.3, 0.1), (cx, top + 0.2, 0.12), M["stand"], 0.025, rot_game=(a, 0, 0))
    for k, (dx, img) in enumerate(((-0.2, "/tmp/cabdesign/scr_eng.png"), (0.2, "/tmp/cabdesign/scr_ptc.png"))):
        c0 = (cx + dx, top + 0.2 + nrm[1] * 0.06, 0.12 + nrm[2] * 0.06)
        box("dt_bezel%d" % k, (0.34, 0.26, 0.03), c0, M["black"], 0.012, rot_game=(a, 0, 0))
        plane("dt_screen%d" % k, 0.3, 0.22, (c0[0], c0[1] + nrm[1] * 0.017, c0[2] + nrm[2] * 0.017), mat_img("scr%d" % k, img, 0.2, emit=1.4), rot_game=(a, 0, 0))
    # throttle / dynamic brake controller on the left wing
    box("dt_thr_base", (0.12, 0.04, 0.3), (x0 + 0.14, top + 0.13, 0.72), M["cast"], 0.012)
    tube("dt_thr", (x0 + 0.14, top + 0.15, 0.74), (x0 + 0.14, top + 0.3, 0.7), 0.012, M["chrome"])
    tube("dt_thr_grip", (x0 + 0.1, top + 0.3, 0.7), (x0 + 0.18, top + 0.3, 0.7), 0.02, M["grip"])
    # automatic + independent brake controller on the right wing
    box("dt_brk_base", (0.2, 0.05, 0.32), (x1 - 0.12, top + 0.14, 0.74), M["cast"], 0.012)
    tube("dt_auto", (x1 - 0.16, top + 0.16, 0.68), (x1 - 0.16, top + 0.32, 0.64), 0.012, M["chrome"])
    sphere("dt_auto_k", 0.03, (x1 - 0.16, top + 0.33, 0.64), M["knob_red"])
    tube("dt_ind", (x1 - 0.07, top + 0.16, 0.82), (x1 - 0.07, top + 0.29, 0.78), 0.011, M["chrome"])
    sphere("dt_ind_k", 0.026, (x1 - 0.07, top + 0.3, 0.78), M["grip"])
    box("alerter_base", (0.12, 0.03, 0.09), (cx, top + 0.055, 0.52), M["cast"], 0.01)
    cyl("alerter", 0.032, 0.03, (cx, top + 0.085, 0.52), M["alerter"], bevel=0.006)
    box("dt_switch", (0.3, 0.02, 0.1), (cx + 0.25, top + 0.05, 0.52), M["console"], 0.008)
    box("handset_cradle", (0.05, 0.2, 0.08), (x0 - 0.0, top - 0.15, 0.6), M["black"], 0.01)


if LAYOUT == "console":
    layout_console()
elif LAYOUT == "desktop":
    layout_desktop()
else:
    layout_stand()

# ------------------------------------------------------------------ conductor side
box("cdesk_body", (1.07, -0.58 - FLOOR, 0.6), (-0.98, (-0.58 + FLOOR) / 2, 0.36), M["stand"], 0.03)
box("cdesk_top", (1.1, 0.04, 0.64), (-0.98, -0.56, 0.36), M["console"], 0.012)
box("cdisplay_pod", (0.62, 0.3, 0.1), (-1.15, -0.37, 0.13), M["stand"], 0.025, rot_game=(-0.4, 0, 0))
plane("cscreen", 0.27, 0.2, (-1.25, -0.35, 0.19), mat_img("scr1", "/tmp/cabdesign/scr_ptc.png", 0.2, emit=1.4), rot_game=(-0.4, 0, 0))
box("ctray", (0.32, 0.05, 0.3), (-0.6, -0.32, 0.2), M["stand"], 0.02)
box("ctray_lip", (0.32, 0.12, 0.03), (-0.6, -0.27, 0.34), M["stand"], 0.012)
box("ebv", (0.12, 0.16, 0.1), (-1.47, -0.95, 0.75), M["red"], 0.015)
cyl("extinguisher", 0.075, 0.42, (1.25, FLOOR + 0.21, 2.6), M["red"], bevel=0.02)

# ------------------------------------------------------------------ seats
def seat(name, x, z):
    base = FLOOR
    cyl(name + "_post", 0.055, 0.3, (x, base + 0.27, z), M["steel"])
    cyl(name + "_bellows", 0.1, 0.18, (x, base + 0.1, z), M["rubber"])
    box(name + "_plate", (0.42, 0.03, 0.42), (x, base + 0.015, z), M["cast"], 0.01)
    cush = box(name + "_cushion", (0.54, 0.13, 0.5), (x, base + 0.5, z), M["seat"], 0.05)
    sub = cush.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    bk = box(name + "_back", (0.52, 0.7, 0.14), (x, base + 0.95, z + 0.28), M["seat"], 0.05, rot_game=(-0.16, 0, 0))
    bk.modifiers.new("sub", "SUBSURF").render_levels = 2
    hr = box(name + "_head", (0.34, 0.18, 0.12), (x, base + 1.4, z + 0.36), M["seat"], 0.04)
    hr.modifiers.new("sub", "SUBSURF").render_levels = 2
    for s in (-1, 1):
        tube(name + "_arm%d" % s, (x + s * 0.33, base + 0.76, z - 0.18), (x + s * 0.33, base + 0.76, z + 0.18), 0.035, M["vinyl"])


seat("eseat", 1.08, 1.32)
seat("cseat", -0.95, 1.25)
seat("cseat2", -0.95, 2.15)

# ------------------------------------------------------------------ outside: short hood nose, ground, track
RAIL = -3.35          # top of rail: cab floor ~79 in above it
DECK = RAIL + 1.84    # walkway / underframe 72.5 in
# short hood: top sits just below the windshield so it shows from the seat
box("nose", (2.96, SILL - 0.06 - DECK, 1.85), (0, (SILL - 0.06 + DECK) / 2, -0.92), M["hood"], 0.04)
box("nose_slope", (2.96, 1.0, 1.4), (0, DECK + 0.5, -2.42), M["hood"], 0.06, rot_game=(0.12, 0, 0))
box("nose_headlight", (0.6, 0.18, 0.05), (0, DECK + 0.85, -3.13), M["black"], 0.02)
box("deck", (3.18, 0.12, 6.0), (0, DECK, -2.0), M["deck"], 0.01)
for s in (-1, 1):
    tube("rail_top%d" % s, (s * 1.52, DECK + 1.05, -0.05), (s * 1.52, DECK + 1.05, -4.0), 0.025, M["handrail"])
    tube("rail_mid%d" % s, (s * 1.52, DECK + 0.55, -0.05), (s * 1.52, DECK + 0.55, -4.0), 0.025, M["handrail"])
    for z in (-0.05, -2.0, -4.0):
        tube("post", (s * 1.52, DECK, z), (s * 1.52, DECK + 1.05, z), 0.03, M["handrail"])
GROUND_Y = RAIL - 0.4
gnd = box("ground", (400, 0.1, 800), (0, GROUND_Y, -350), mat_tex("grass", "pbr/grass_field_diff.jpg", 0.25, 0.9), 0.0)
bal = box("ballast", (4.2, 0.3, 800), (0, GROUND_Y + 0.15, -350), mat_tex("ballast", "pbr/rocks_ground_01_diff.jpg", 0.6, 0.9, bump=0.5), 0.0)
for s in (-1, 1):
    box("railhead%d" % s, (0.075, 0.16, 800), (s * 0.7175, GROUND_Y + 0.38, -350), M["steel"], 0.0)
tie_m = mat_tex("tie", "pbr/rough_wood_diff.jpg", 2.0, 0.85, tint=(0.5, 0.42, 0.36))
bpy.ops.mesh.primitive_cube_add(size=1.0)
tie = bpy.context.active_object
tie.scale = (2.6, 0.22, 0.17)
bpy.ops.object.transform_apply(scale=True)
tie.location = g(0, GROUND_Y + 0.3, -5)
finish(tie, tie_m, 0.0)
arr = tie.modifiers.new("arr", "ARRAY")
arr.count = 600
arr.relative_offset_displace = (0, 2.65, 0)

def export_glb(path):
    """Interior + shell only, modifiers applied, box-projected textures turned into real UVs."""
    skip = ("ground", "ballast", "railhead", "Cube", "nose", "deck", "rail_top", "rail_mid", "post")
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.hide_render:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        o.hide_viewport = False
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            m.show_viewport = True
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except Exception:
                o.modifiers.remove(m)
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.hide_render or o.name.startswith(skip):
            bpy.data.objects.remove(o, do_unlink=True)
    for o in bpy.data.objects:
        mat = o.active_material
        if mat is None or not mat.use_nodes:
            continue
        nt = mat.node_tree
        mp = next((n for n in nt.nodes if n.type == "MAPPING"), None)
        im = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
        if mp is None or im is None:
            continue
        sc = mp.inputs["Scale"].default_value[0]
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        if not o.data.uv_layers:
            o.data.uv_layers.new()
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=1.0 / max(sc, 0.001), scale_to_bounds=False, correct_aspect=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nt = mat.node_tree
        for n in list(nt.nodes):
            if n.type in ("MAPPING", "TEX_COORD"):
                nt.nodes.remove(n)
        for n in nt.nodes:
            if n.type == "TEX_IMAGE":
                n.projection = "FLAT"
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)
    print("EXPORTED", path)


# ------------------------------------------------------------------ world, lights, camera
world = bpy.data.worlds.new("world")
scene.world = world
world.use_nodes = True
wn = world.node_tree
env = wn.nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(TEX + "pbr/sky_partly_cloudy.hdr")
mp = wn.nodes.new("ShaderNodeMapping")
mp.inputs["Rotation"].default_value = (0, 0, math.radians(200))
tc = wn.nodes.new("ShaderNodeTexCoord")
wn.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
wn.links.new(mp.outputs["Vector"], env.inputs["Vector"])
wn.links.new(env.outputs["Color"], wn.nodes["Background"].inputs["Color"])
wn.nodes["Background"].inputs["Strength"].default_value = 1.0
bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
sun = bpy.context.active_object
sun.data.energy = 4.5
sun.data.angle = math.radians(1.2)
sun.rotation_euler = Euler((math.radians(48), 0, math.radians(150)), "XYZ")
# soft fill inside the cab (bounce from the windshields)
bpy.ops.object.light_add(type="AREA", location=g(0, 0.4, 0.6))
fill = bpy.context.active_object
fill.data.energy = 0
fill.data.size = 2.4
fill.data.color = (1.0, 0.96, 0.9)
fill.rotation_euler = Euler((math.radians(70), 0, 0), "XYZ")

cams = {
    "eng": ((1.08, 0.0, 1.15), (0.9, -0.3, -1.0), 72),
    "rear": ((0.0, 0.42, 2.7), (0.0, -0.75, 0.0), 100),
    "plan": ((0.0, 6.0, 1.3), (0.0, 0.0, 1.3), 0),
    "stand": ((0.86, 0.0, 1.12), (0.25, -0.75, 0.55), 66),
    "wide": ((0.05, 0.5, 2.65), (0.35, -0.75, 0.0), 80),
    "overhead": ((0.86, 0.0, 1.12), (0.4, 0.55, 0.2), 70),
}
cpos, ctarget, fov = cams.get(VIEW, cams["eng"])
cam_data = bpy.data.cameras.new("cam")
cam_data.lens_unit = "FOV"
cam_data.angle = math.radians(max(fov, 1))
if VIEW == "plan":
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 5.6
    for o in bpy.data.objects:
        if any(o.name.startswith(k) for k in ("ceiling", "rib", "overhead", "ohpanel", "dome", "visor", "wiper", "nose", "deck", "rail_", "post")):
            o.hide_render = True
cam = bpy.data.objects.new("cam", cam_data)
col.objects.link(cam)
cam.location = g(*cpos)
d = g(*ctarget) - g(*cpos)
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler() if VIEW != "plan" else Euler((0, 0, 0))
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 6
scene.cycles.glossy_bounces = 3
scene.cycles.transmission_bounces = 6
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = {"rear": 1.7, "plan": 0.6, "eng": 0.9}.get(VIEW, 0.8)   # expose for the interior like a camera would
scene.render.filepath = OUT + "_" + LAYOUT + "_" + VIEW + ".png"
if VIEW == "export":
    export_glb(OUT)
    raise SystemExit(0)
bpy.ops.wm.save_as_mainfile(filepath="/home/claude/cabdesign/sd70ace_cab.blend")
bpy.ops.render.render(write_still=True)
print("RENDERED", scene.render.filepath)
