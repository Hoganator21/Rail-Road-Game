"""EMD GP38-2 cab interior, design prototype (game coords: x right, y up, -z forward, front wall z=0)."""
import math
import bpy
from mathutils import Vector, Euler

SRC = open("/home/claude/cabdesign/build_cab.py").read()
exec(SRC[:SRC.index("# ------------------------------------------------------------------ cab shell")])
exec(SRC[SRC.index("def soft("):SRC.index("\n\nseat(")])

REPAINT = LAYOUT.startswith("repaint")
LHF = LAYOUT.endswith("lhf")
WALL = mat_tex("wall_g", "cab_wall_green.png", 1.6, 0.62, 0.05, bump=0.15) if REPAINT else M["wall"]
STAND = mat_tex("stand_k", "stand_brown.png", 1.5, 0.5, 0.25, tint=(0.17, 0.17, 0.18), bump=0.12) if REPAINT else M["stand"]
CEILM = mat_tex("ceil_g", "ceiling_green.png", 1.4, 0.85, bump=0.25) if REPAINT else M["ceil"]
STAINLESS = mat_col("stainless", (0.6, 0.6, 0.58), 0.38, 0.85)
WHITE = mat_col("cab_white", (0.75, 0.75, 0.72), 0.55)
DANGER = mat_img("danger", "/tmp/cabdesign/danger.png", 0.5)
ORANGE = mat_col("orange", (0.9, 0.35, 0.08), 0.5)

# ------------------------------------------------------------------ dimensions
W = 3.0
HW = W / 2
CAB_LEN = 2.3
FLOOR = -1.35
CEIL = FLOOR + 1.98          # 6 ft 6 in
SILL = FLOOR + 1.02          # 40 in to the bottom of the glass
TOP = SILL + 0.56            # 22 in tall panes
WIN_W = 0.72
WIN_XS = (-0.52, 0.52)
WR = 0.09

# ------------------------------------------------------------------ shell
box("floor", (W, 0.06, CAB_LEN), (0, FLOOR - 0.03, CAB_LEN / 2), M["floor"], 0.0)
box("ceiling", (W, 0.05, CAB_LEN), (0, CEIL + 0.025, CAB_LEN / 2), CEILM, 0.0)
front = box("front_wall", (W, CEIL - FLOOR, 0.1), (0, (CEIL + FLOOR) / 2, 0.0), WALL, 0.0)
for i, x in enumerate(WIN_XS):
    cut(front, rounded_rect_cutter("wcut%d" % i, WIN_W, TOP - SILL, WR, 0.4, (x, (TOP + SILL) / 2, 0.0)))
    gasket("wgasket%d" % i, WIN_W, TOP - SILL, WR, (x, (TOP + SILL) / 2, 0.03))
    box("wglass%d" % i, (WIN_W + 0.02, TOP - SILL + 0.02, 0.012), (x, (TOP + SILL) / 2, -0.01), M["glass"], 0.0)
# cab door, front-left corner, out to the walkway
DX0, DX1 = -HW + 0.04, -0.92
dcx, dw = (DX0 + DX1) / 2, DX1 - DX0
DTOP = TOP + 0.08
cut(front, box("dcut", (dw, DTOP - FLOOR + 0.05, 0.4), (dcx, (DTOP + FLOOR) / 2 - 0.02, 0.0), WALL, 0.0))
leaf = box("door", (dw - 0.02, DTOP - FLOOR - 0.02, 0.045), (dcx, (DTOP + FLOOR) / 2, -0.02), WALL, 0.01)
cut(leaf, rounded_rect_cutter("dwcut", dw - 0.16, TOP - SILL, 0.06, 0.3, (dcx, (TOP + SILL) / 2, -0.02)))
box("dglass", (dw - 0.14, TOP - SILL + 0.02, 0.01), (dcx, (TOP + SILL) / 2, -0.02), M["glass"], 0.0)
gasket("dgasket", dw - 0.16, TOP - SILL, 0.06, (dcx, (TOP + SILL) / 2, 0.005), 0.022, 0.04)
box("dhandle", (0.035, 0.16, 0.05), (DX1 - 0.07, FLOOR + 1.0, 0.03), M["chrome"], 0.01)
for hy in (FLOOR + 0.3, TOP - 0.1):
    box("dhinge", (0.04, 0.12, 0.05), (DX0 + 0.03, hy, 0.03), M["steel"], 0.008)
# bathroom door: low opening at the centre of the wall, under the windshields
BW, BH, BX = 0.6, 0.82, 0.0
cut(front, box("bcut", (BW, BH + 0.05, 0.4), (BX, FLOOR + BH / 2 - 0.02, 0.0), WALL, 0.0))
_hw = BW - 0.03
_ha = 1.2   # hatch swung open into the nose
box("bdoor", (_hw, BH - 0.02, 0.04), (BX - BW / 2 + math.cos(_ha) * _hw / 2, FLOOR + BH / 2, -0.03 - math.sin(_ha) * _hw / 2), WALL, 0.01, rot_game=(0, _ha, 0))
NOSE_F = FLOOR - 0.2
box("nose_step", (BW, 0.04, 0.3), (BX, NOSE_F + 0.1, -0.2), M["floor"], 0.005)
box("nose_step_edge", (BW, 0.012, 0.03), (BX, NOSE_F + 0.125, -0.06), M["yellow"], 0.002)
box("nose_floor", (1.0, 0.04, 1.4), (BX, NOSE_F - 0.02, -0.75), M["floor"], 0.0)
for nx in (-0.5, 0.5):
    box("nose_wall", (0.04, 1.2, 1.4), (BX + nx, NOSE_F + 0.6, -0.75), M["black"], 0.0)
box("nose_back", (1.0, 1.2, 0.04), (BX, NOSE_F + 0.6, -1.45), M["black"], 0.0)
box("nose_top", (1.0, 0.04, 1.4), (BX, FLOOR + BH + 0.1, -0.75), M["black"], 0.0)
cyl("toilet", 0.17, 0.36, (BX + 0.15, NOSE_F + 0.18, -1.1), mat_col("porcelain", (0.85, 0.85, 0.82), 0.25), bevel=0.02)
box("bedge", (BW + 0.1, 0.05, 0.07), (BX, FLOOR + BH + 0.03, 0.035), M["yellow"], 0.008)
GR = WALL
tube("bgrab", (BX - 0.34, FLOOR + BH + 0.06, 0.16), (BX + 0.08, FLOOR + BH + 0.06, 0.16), 0.02, GR)
tube("bgrab_up", (BX - 0.34, FLOOR + BH + 0.06, 0.16), (BX - 0.34, FLOOR + BH + 0.06, 0.02), 0.02, GR)
tube("bgrab_dn", (BX + 0.08, FLOOR + BH + 0.06, 0.16), (BX + 0.08, FLOOR + 0.25, 0.16), 0.02, GR)
tube("bgrab_ft", (BX + 0.08, FLOOR + 0.25, 0.16), (BX + 0.08, FLOOR + 0.25, 0.02), 0.02, GR)
# emergency brake valve in a recess of the front wall, left of the restroom door
box("ev_recess", (0.28, 0.32, 0.04), (-0.62, FLOOR + 0.72, 0.035), M["black"], 0.006)
cyl("ev_pipe", 0.025, 0.3, (-0.62, FLOOR + 0.72, 0.07), M["cast"])
tube("ev_handle", (-0.6, FLOOR + 0.74, 0.09), (-0.66, FLOOR + 0.56, 0.11), 0.012, M["red"])
box("watch_step", (0.2, 0.06, 0.004), (0, TOP + 0.06, 0.052), ORANGE, 0.0)
# stainless overhead panel above the glass
OVB = TOP + 0.09
OVM = WALL if REPAINT else STAINLESS
box("ov_panel", (W - 0.3, CEIL - OVB, 0.06), (0, (CEIL + OVB) / 2, 0.08), OVM, 0.01)
if REPAINT:
    for px in (-0.62, 0.62):
        box("ov_inset", (1.05, CEIL - OVB - 0.1, 0.02), (px, (CEIL + OVB) / 2, 0.115), WALL, 0.04)
box("ov_lip", (W - 0.3, 0.03, 0.12), (0, OVB, 0.08), OVM, 0.006)
box("ov_sticker", (0.12, 0.13, 0.004), (-0.05, OVB + 0.2, 0.112), M["yellow"], 0.0)
box("ov_box", (0.24, 0.1, 0.06), (0.45, OVB + 0.16, 0.14), M["black"], 0.01)
box("cam_box", (0.2, 0.08, 0.1), (0.62, OVB - 0.05, 0.12), M["black"], 0.012)
# side walls with sliding windows
for s in (-1, 1):
    sw = box("side%d" % s, (0.1, CEIL - FLOOR, CAB_LEN), (s * (HW - 0.05), (CEIL + FLOOR) / 2, CAB_LEN / 2), WALL, 0.0)
    c = rounded_rect_cutter("scut%d" % s, 1.2, TOP - SILL + 0.06, 0.06, 0.5, (s * (HW - 0.05), (TOP + SILL) / 2, 0.95))
    c.rotation_euler = (0, 0, math.pi / 2)
    cut(sw, c)
    box("sglass%d" % s, (0.012, TOP - SILL + 0.08, 1.22), (s * (HW - 0.02), (TOP + SILL) / 2, 0.95), M["glass"], 0.0)
    box("ssash%d" % s, (0.04, TOP - SILL + 0.06, 0.04), (s * (HW - 0.06), (TOP + SILL) / 2, 0.95), M["chrome"], 0.004)
    box("strack%d" % s, (0.06, 0.025, 1.25), (s * (HW - 0.11), SILL - 0.02, 0.95), M["chrome"], 0.004)
# rear wall: two small windows (for running long hood forward) and the electrical locker
back = box("back_wall", (W, CEIL - FLOOR, 0.1), (0, (CEIL + FLOOR) / 2, CAB_LEN), WALL, 0.0)
RW = 0.5
for i, x in enumerate((-0.92, 0.92)):
    cut(back, rounded_rect_cutter("rcut%d" % i, RW, TOP - SILL, 0.07, 0.4, (x, (TOP + SILL) / 2, CAB_LEN)))
    gasket("rgasket%d" % i, RW, TOP - SILL, 0.07, (x, (TOP + SILL) / 2, CAB_LEN - 0.03))
    box("rglass%d" % i, (RW + 0.02, TOP - SILL + 0.02, 0.012), (x, (TOP + SILL) / 2, CAB_LEN + 0.01), M["glass"], 0.0)
LZ = CAB_LEN - 0.23
box("locker", (1.16, CEIL - FLOOR - 0.02, 0.36), (0, (CEIL + FLOOR) / 2, LZ), WALL, 0.015)
for (lx, ly, lw, lh) in ((-0.29, FLOOR + 0.45, 0.54, 0.82), (0.29, FLOOR + 0.45, 0.54, 0.82), (-0.29, FLOOR + 1.3, 0.54, 0.78), (0.29, FLOOR + 1.3, 0.54, 0.78)):
    box("lk_door", (lw, lh, 0.03), (lx, ly, LZ - 0.19), WALL, 0.012)
    box("lk_handle", (0.03, 0.12, 0.04), (lx + lw / 2 - 0.07, ly, LZ - 0.215), M["steel"], 0.008)
    plane("lk_danger", 0.13, 0.065, (lx - 0.08, ly + 0.15, LZ - 0.206), DANGER, rot_game=(0, math.pi, 0))
box("breaker_frame", (0.5, 0.42, 0.03), (0.29, FLOOR + 1.5, LZ - 0.21), M["black"], 0.01)
plane("breakers", 0.46, 0.38, (0.29, FLOOR + 1.5, LZ - 0.227), mat_img("breakers", "/tmp/cabdesign/breakers.png", 0.45), rot_game=(0, math.pi, 0))
for cx in (-0.75, 0.0, 0.75):
    for cz in (0.55, 1.6):
        box("ceil_panel", (0.62, 0.035, 0.8), (cx, CEIL - 0.018, cz), CEILM, 0.05)
for s in (-1, 1):
    for pz in (0.75, 1.65):
        box("wall_inset", (0.025, 0.58, 0.75), (s * (HW - 0.112), FLOOR + 0.48, pz), WALL, 0.05)
    box("grab_side", (0.03, 0.03, 0.5), (s * (HW - 0.14), SILL - 0.12, 1.75), M["steel"], 0.01)
# ceiling light, visors, wipers
box("dome", (0.3, 0.05, 0.2), (0, CEIL - 0.03, 1.2), M["black"], 0.01)
box("dome_lens", (0.24, 0.02, 0.14), (0, CEIL - 0.065, 1.2), M["dome"], 0.006)
for i, x in enumerate(WIN_XS):
    box("visor%d" % i, (0.52, 0.035, 0.24), (x, TOP + 0.02, 0.2), M["vinyl"], 0.012, rot_game=(-0.4, 0, 0))
    tube("visor_arm%d" % i, (x - 0.28, TOP + 0.05, 0.1), (x - 0.28, TOP + 0.05, 0.3), 0.008, M["steel"])
    side = -1 if x < 0 else 1
    wx = x + side * (WIN_W / 2 - 0.1)
    tube("wiper%d" % i, (wx, TOP + 0.03, -0.08), (wx - side * 0.06, SILL + 0.1, -0.08), 0.006, M["black"])
    box("wiper_blade%d" % i, (0.016, (TOP - SILL) * 0.6, 0.014), (wx - side * 0.07, (TOP + SILL) / 2 - 0.03, -0.095), M["rubber"], 0.004)

# ------------------------------------------------------------------ interior furniture (mirrored for long hood forward)
before = set(bpy.data.objects)


def group(build, pos, yaw):
    b = set(bpy.data.objects)
    build()
    e = bpy.data.objects.new("grp", None)
    col.objects.link(e)
    for o in bpy.data.objects:
        if o not in b and o is not e and o.parent is None:
            o.parent = e
    e.location = g(*pos)
    e.rotation_euler = (0, 0, yaw)
    return e


def build_stand():
    H = FLOOR + 0.92            # top of the stand body, ~36 in
    box("st_body", (0.5, H - FLOOR, 0.8), (0, (H + FLOOR) / 2, 0), STAND, 0.03)
    box("st_base", (0.54, 0.06, 0.84), (0, FLOOR + 0.03, 0), M["black"], 0.01)
    box("st_hatch", (0.012, 0.3, 0.4), (0.256, FLOOR + 0.38, -0.05), STAND, 0.01)
    plane("st_danger", 0.15, 0.075, (0.264, FLOOR + 0.62, -0.05), DANGER, rot_game=(0, math.pi / 2, 0))
    # controller: black face plate with throttle (lower) and dynamic brake (upper) quadrants
    box("st_ctrl", (0.03, 0.38, 0.42), (0.26, H - 0.32, -0.08), M["cast"], 0.01)
    for nm, yy, rr in (("st_arc_db", H - 0.24, 0.11), ("st_arc_thr", H - 0.42, 0.11)):
        cyl(nm, rr, 0.02, (0.28, yy, -0.12), M["steel"], axis="x", segs=40, bevel=0.003)
    tube("st_db", (0.29, H - 0.24, -0.12), (0.45, H - 0.22, -0.04), 0.011, M["chrome"])
    sphere("st_db_k", 0.022, (0.45, H - 0.22, -0.04), M["grip"])
    tube("st_thr", (0.29, H - 0.42, -0.12), (0.47, H - 0.4, -0.2), 0.012, M["chrome"])
    tube("st_thr_g", (0.45, H - 0.4, -0.19), (0.56, H - 0.39, -0.24), 0.02, M["grip"])
    tube("st_rev", (0.29, H - 0.5, 0.06), (0.37, H - 0.5, 0.09), 0.012, M["black"])
    plane("st_sw", 0.22, 0.15, (0.266, H - 0.09, 0.2), M["switches"], rot_game=(0, math.pi / 2, 0))
    # 26L brake valve on the column at the rear end of the face
    box("st_col", (0.12, 0.6, 0.24), (0.3, H - 0.36, 0.28), STAND, 0.02)
    box("b26_plate", (0.01, 0.34, 0.2), (0.365, H - 0.36, 0.28), STAINLESS, 0.006)
    cyl("pcs_btn", 0.022, 0.03, (0.28, H - 0.62, 0.05), M["red"], axis="x", bevel=0.004)
    for k in range(3):
        box("st_toggle", (0.03, 0.02, 0.012), (0.285, H - 0.06, 0.02 + k * 0.035), M["chrome"], 0.003)
    cyl("b26_body", 0.07, 0.22, (0.39, H - 0.42, 0.29), M["cast"], bevel=0.008)
    cyl("b26_cap", 0.08, 0.04, (0.39, H - 0.3, 0.29), M["cast"], bevel=0.006)
    tube("b26_auto", (0.39, H - 0.28, 0.29), (0.6, H - 0.26, 0.38), 0.013, M["black"])
    sphere("b26_auto_k", 0.026, (0.6, H - 0.26, 0.38), M["black"])
    cyl("b26_ind_body", 0.06, 0.1, (0.39, H - 0.62, 0.29), M["cast"], bevel=0.006)
    tube("b26_ind", (0.39, H - 0.58, 0.29), (0.56, H - 0.58, 0.2), 0.012, M["black"])
    sphere("b26_ind_k", 0.022, (0.56, H - 0.58, 0.2), M["black"])
    # angled gauge panel on top, facing the engineer
    a = 0.5
    n = Vector((math.cos(a), math.sin(a), 0.0))
    gc = Vector((0.12, H + 0.09, 0.0))
    box("st_gpanel", (0.12, 0.2, 0.8), tuple(gc), STAND, 0.02, rot_game=(0, 0, a))
    for k, (zz, key) in enumerate(((-0.27, "g_er"), (-0.09, "g_mr"), (0.09, "g_er"), (0.27, "g_speed"))):
        c = gc + n * 0.065 + Vector((0, 0, zz))
        r = 0.058
        can = cyl("g_can%d" % k, r * 1.08, 0.03, tuple(c - n * 0.01), M["black"], axis="x", segs=40, bevel=0.004)
        can.rotation_euler.y = math.pi / 2 - a
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.04, minor_radius=0.007, major_segments=48, minor_segments=12, location=g(*(c + n * 0.006)))
        ring = bpy.context.active_object
        ring.rotation_euler = (0, math.pi / 2 - a, 0)
        finish(ring, M["chrome"])
        bpy.ops.mesh.primitive_circle_add(vertices=48, radius=r * 0.96, fill_type="NGON", location=g(*(c + n * 0.008)))
        face = bpy.context.active_object
        face.rotation_euler = (0, math.pi / 2 - a, 0)
        d = 2 * r * 0.96
        for li, loop in enumerate(face.data.loops):
            co = face.data.vertices[loop.vertex_index].co
            face.data.uv_layers.active.data[li].uv = (co.y / d + 0.5, -co.x / d + 0.5)
        finish(face, M[key], smooth=False)
    # notch indicator window, nameplates, indicator lights, alerter, sand, horn, MU2A
    box("st_notch_win", (0.008, 0.04, 0.16), (0.279, H - 0.155, -0.12), M["paper"], 0.004)
    plane("st_plate1", 0.12, 0.04, (0.277, H - 0.33, 0.02), M["paper"], rot_game=(0, math.pi / 2, 0))
    plane("st_plate2", 0.1, 0.035, (0.277, H - 0.52, -0.2), M["yellow"], rot_game=(0, math.pi / 2, 0))
    box("st_lights", (0.02, 0.07, 0.1), (0.275, H - 0.1, -0.24), M["cast"], 0.006)
    for k in range(4):
        box("st_light", (0.01, 0.022, 0.022), (0.287, H - 0.085 - (k // 2) * 0.03, -0.265 + (k % 2) * 0.045), M["led_red"] if k == 0 else M["lcd"], 0.003)
    cyl("st_alerter", 0.024, 0.025, (0.28, H - 0.6, -0.22), M["alerter"], axis="x", bevel=0.004)
    tube("st_sand", (0.28, H - 0.68, -0.02), (0.33, H - 0.66, -0.02), 0.01, M["chrome"])
    tube("st_horn", (0.08, H + 0.02, 0.33), (0.08, H + 0.27, 0.33), 0.012, M["chrome"])
    tube("st_horn_g", (0.08, H + 0.27, 0.33), (0.08, H + 0.37, 0.33), 0.02, M["grip"])
    box("mu2a", (0.08, 0.1, 0.1), (0.36, H - 0.76, 0.29), M["cast"], 0.012)
    tube("mu2a_h", (0.4, H - 0.76, 0.29), (0.46, H - 0.76, 0.33), 0.009, M["chrome"])
    fy = H + 0.2
    box("rb_base", (0.3, 0.015, 0.32), (-0.04, H + 0.02, 0.26), M["cast"], 0.004)
    box("rb_top", (0.3, 0.015, 0.32), (-0.04, fy + 0.12, 0.26), M["cast"], 0.004)
    for bz in (0.105, 0.415):
        box("rb_side", (0.3, 0.2, 0.015), (-0.04, fy + 0.02, bz), M["cast"], 0.004)
    box("rb_back", (0.015, 0.2, 0.32), (-0.185, fy + 0.02, 0.26), M["cast"], 0.004)
    box("radio_ctrl", (0.1, 0.05, 0.16), (0.05, H + 0.05, 0.26), M["black"], 0.008)
    box("radio_lcd", (0.004, 0.02, 0.08), (0.101, H + 0.06, 0.26), M["lcd"], 0.0)
    box("alert_box", (0.14, 0.12, 0.12), (-0.06, H + 0.07, -0.32), M["black"], 0.012)


group(build_stand, (0.28, 0.0, 0.72), -0.75)   # angled diagonally toward the engineer
VINYL = mat_col("seat_vinyl", (0.04, 0.045, 0.06), 0.42)


def gp_seat(name, x, z):
    b = FLOOR
    box(name + "_plate", (0.4, 0.03, 0.4), (x, b + 0.015, z), M["cast"], 0.01)
    cyl(name + "_post", 0.05, 0.36, (x, b + 0.2, z), M["steel"])
    box(name + "_frame", (0.38, 0.04, 0.42), (x, b + 0.4, z), M["cast"], 0.008)
    cush = box(name + "_cush", (0.5, 0.11, 0.48), (x, b + 0.47, z), VINYL, 0.04)
    cush.modifiers.new("sub", "SUBSURF").render_levels = 2
    bk = box(name + "_back", (0.48, 0.6, 0.1), (x, b + 0.86, z + 0.27), VINYL, 0.04, rot_game=(-0.15, 0, 0))
    bk.modifiers.new("sub", "SUBSURF").render_levels = 2
    for k in range(4):   # stitched channels in the backrest
        box(name + "_seam", (0.44, 0.006, 0.105), (x, b + 0.68 + k * 0.12, z + 0.25 + k * 0.018), M["black"], 0.0, rot_game=(-0.15, 0, 0))
    for sxx in (-1, 1):   # fold-down armrests on pivots at the backrest
        piv = (x + sxx * 0.28, b + 0.7, z + 0.2)
        tube(name + "_arm_pv", (piv[0] - 0.02 * sxx, piv[1], piv[2]), (piv[0] + 0.02 * sxx, piv[1], piv[2]), 0.02, M["steel"])
        arm = box(name + "_arm", (0.06, 0.06, 0.34), (piv[0], piv[1] - 0.02, piv[2] - 0.16), VINYL, 0.025, rot_game=(-0.12, 0, 0))


# heater cabinet ahead of the engineer, by the right wall
box("heater", (0.48, 0.72, 0.42), (1.18, FLOOR + 0.36, 0.3), WHITE, 0.02)
box("heater_grille", (0.36, 0.14, 0.01), (1.18, FLOOR + 0.18, 0.515), M["black"], 0.004)
# conductor side: emergency valve recess in the wall, low heater, extinguisher
box("c_heater", (0.18, 0.4, 0.5), (-HW + 0.19, FLOOR + 0.2, 1.1), WHITE, 0.015)
cyl("extinguisher", 0.07, 0.4, (-0.08, FLOOR + 0.2, 0.45), M["red"], bevel=0.02)
gp_seat("eseat", 0.98, 1.3)
gp_seat("cseat", -0.95, 1.2)
gp_seat("cseat2", -0.95, 1.9)
interior = [o for o in bpy.data.objects if o not in before and o.parent is None]
if LHF:
    # long hood forward: the stand and seats are set up facing the rear wall
    e = bpy.data.objects.new("mirror", None)
    col.objects.link(e)
    e.location = g(0, 0, CAB_LEN / 2)
    bpy.context.view_layer.update()
    for o in interior:
        o.parent = e
        o.matrix_parent_inverse = e.matrix_world.inverted()
    e.rotation_euler = (0, 0, math.pi)

# ------------------------------------------------------------------ outside: hoods, deck, track
RAIL = FLOOR - 1.75
DECK = RAIL + 1.55
SH_TOP = SILL - 0.14
shood = box("short_hood", (1.75, SH_TOP - DECK, 2.95), (0, (SH_TOP + DECK) / 2, -1.55), M["hood"], 0.05)
cut(shood, box("nose_cavity_cut", (1.05, 1.4, 1.5), (BX, NOSE_F + 0.6, -0.72), M["black"], 0.0))
box("number_boards", (1.2, 0.18, 0.06), (0, SH_TOP - 0.12, -3.03), M["black"], 0.01)
cyl("bell", 0.1, 0.16, (-0.45, SH_TOP + 0.08, -1.2), M["yellow"])
LH_TOP = SILL - 0.06
box("long_hood", (1.8, LH_TOP - DECK, 12.0), (0, (LH_TOP + DECK) / 2, CAB_LEN + 6.05), M["hood"], 0.05)
for z in (CAB_LEN + 8.5, CAB_LEN + 10.3):
    cyl("fan", 0.55, 0.06, (0, LH_TOP + 0.03, z), M["black"], segs=32)
box("stack", (0.35, 0.18, 0.8), (0, LH_TOP + 0.09, CAB_LEN + 4.2), M["black"], 0.02)
box("deck", (W + 0.1, 0.12, 20.0), (0, DECK, 5.0), M["deck"], 0.01)
for s in (-1, 1):
    for yy in (0.55, 1.05):
        tube("rail_h", (s * 1.5, DECK + yy, -4.3), (s * 1.5, DECK + yy, -0.05), 0.025, M["handrail"])
        tube("rail_h2", (s * 1.5, DECK + yy, CAB_LEN + 0.05), (s * 1.5, DECK + yy, 14.0), 0.025, M["handrail"])
    for z in (-4.3, -2.2, CAB_LEN + 2.0, CAB_LEN + 6.0, CAB_LEN + 10.0, 14.0):
        tube("post", (s * 1.5, DECK, z), (s * 1.5, DECK + 1.05, z), 0.03, M["handrail"])
GY = RAIL - 0.4
box("ground", (400, 0.1, 900), (0, GY, 0), mat_tex("grass", "pbr/grass_field_diff.jpg", 0.25, 0.9), 0.0)
box("ballast", (4.2, 0.3, 900), (0, GY + 0.15, 0), mat_tex("ballast", "pbr/rocks_ground_01_diff.jpg", 0.6, 0.9, bump=0.5), 0.0)
for s in (-1, 1):
    box("railhead", (0.075, 0.16, 900), (s * 0.7175, GY + 0.38, 0), M["steel"], 0.0)
bpy.ops.mesh.primitive_cube_add(size=1.0)
tie = bpy.context.active_object
tie.scale = (2.6, 0.22, 0.17)
bpy.ops.object.transform_apply(scale=True)
tie.location = g(0, GY + 0.3, 400)
finish(tie, mat_tex("tie", "pbr/rough_wood_diff.jpg", 2.0, 0.85, tint=(0.5, 0.42, 0.36)), 0.0)
arr = tie.modifiers.new("arr", "ARRAY")
arr.count = 1700
arr.relative_offset_displace = (0, 2.65, 0)

# ------------------------------------------------------------------ world, camera, render (shared)
exec(SRC[SRC.index("def soft("):SRC.index("def seat(")])
exec(SRC[SRC.index("def _bake_ao("):SRC.index("# ------------------------------------------------------------------ world, lights, camera")])
tail = SRC[SRC.index("# ------------------------------------------------------------------ world, lights, camera"):]
i0, i1 = tail.index("cams = {"), tail.index("cpos, ctarget, fov")
tail = tail[:i0] + '''cams = {
    "eng": ((0.98, 0.0, 1.15), (0.8, -0.35, -1.0), 75),
    "side": ((-1.25, 0.05, 1.25), (1.0, -0.4, 0.55), 85),
    "lhf": ((-0.98, 0.0, CAB_LEN - 1.15), (-0.72, -0.35, CAB_LEN + 2.3), 75),
    "rear": ((-1.15, 0.35, 2.0), (0.4, -0.6, 0.3), 95),
    "stand": ((1.0, 0.12, 1.45), (0.2, -0.55, 0.75), 66),
    "photo": ((0.98, 0.38, 1.75), (0.3, -0.85, 0.35), 98),
    "back": ((0.6, 0.05, 0.6), (-0.1, -0.25, 2.4), 80),
    "plan": ((0.0, 6.0, 1.15), (0.0, 0.0, 1.15), 0),
}
''' + tail[i1:]
tail = tail.replace("cam_data.ortho_scale = 5.6", "cam_data.ortho_scale = 4.6")
tail = tail.replace('("ceiling", "rib", "overhead", "ohpanel", "dome", "visor", "wiper", "nose", "deck", "rail_", "post")', '("ceiling", "ceil_", "ov_", "dome", "visor", "wiper", "short_hood", "long_hood", "deck", "rail_h", "post", "fan", "stack", "bell")')
tail = tail.replace('{"rear": 1.7, "plan": 0.6, "eng": 0.9}', '{"rear": 1.7, "plan": 0.6, "eng": 0.9, "lhf": 0.9, "stand": 1.3, "side": 1.5, "back": 1.3, "photo": 1.2}')
tail = tail.replace("sd70ace_cab.blend", "gp38_cab.blend").replace('OUT + "_" + LAYOUT', 'OUT + "_gp38_" + LAYOUT')
exec(tail)
