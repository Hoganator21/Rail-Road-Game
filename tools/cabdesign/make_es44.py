"""Generate build_es44.py from build_cab.py (shared shell, GE stand layout, ES44 back wall)."""
s = open("/home/claude/cabdesign/build_cab.py").read()
def rep(a, b):
    global s
    assert s.count(a) == 1, (s.count(a), a[:70]); s = s.replace(a, b)
rep('''if LAYOUT == "console":
    layout_console()''', '''def ge_desk():
    DESK = -0.56
    DX = 1.19
    box("desk_body", (0.68, DESK - FLOOR, 0.52), (DX, (DESK + FLOOR) / 2, 0.31), M["stand"], 0.03)
    box("desk_top", (0.72, 0.04, 0.56), (DX, DESK + 0.02, 0.31), M["console"], 0.012)
    a = -0.55
    nrm = (0.0, -math.sin(a), math.cos(a))
    box("display_pod", (0.7, 0.3, 0.1), (DX, DESK + 0.2, 0.12), M["stand"], 0.025, rot_game=(a, 0, 0))
    for k, (dx, img) in enumerate(((-0.17, "/tmp/cabdesign/scr_eng.png"), (0.17, "/tmp/cabdesign/scr_ptc.png"))):
        c0 = (DX + dx, DESK + 0.2 + nrm[1] * 0.06, 0.12 + nrm[2] * 0.06)
        box("smart_bezel%d" % k, (0.32, 0.27, 0.035), c0, M["black"], 0.014, rot_game=(a, 0, 0))
        plane("smart_scr%d" % k, 0.26, 0.19, (c0[0], c0[1] + nrm[1] * 0.019 + 0.012, c0[2] + nrm[2] * 0.019 + 0.008), mat_img("scr%d" % k, img, 0.2, emit=1.4), rot_game=(a, 0, 0))
        plane("smart_keys%d" % k, 0.26, 0.026, (c0[0], c0[1] - 0.105 * math.cos(a) + nrm[1] * 0.019, c0[2] - 0.105 * math.sin(a) + nrm[2] * 0.019), M["fkeys"], rot_game=(a, 0, 0))
    cyl("cup_hole", 0.045, 0.02, (DX, DESK + 0.035, 0.42), M["black"])
    for k, mm in enumerate((M["lcd"], M["alerter"], M["red"])):
        cyl("desk_btn%d" % k, 0.017, 0.02, (DX + 0.12 + k * 0.05, DESK + 0.045, 0.5), mm, bevel=0.003)
    plane("warrant", 0.2, 0.27, (DX + 0.25, DESK + 0.045, 0.42), M["paper"], rot_game=(-math.pi / 2, -0.15, 0))


def layout_ge():
    """GE control stand at the engineer's left (most ES44ACs) + desk with two Smart Displays."""
    SX, SZ = 0.6, 0.62
    TOPY = SILL - 0.03
    BLUE = mat_col("ge_blue", (0.1, 0.28, 0.6), 0.35)
    box("ge_body", (0.42, TOPY - FLOOR, 1.0), (SX, (TOPY + FLOOR) / 2, SZ), M["stand"], 0.035)
    box("ge_cap", (0.44, 0.03, 1.02), (SX, TOPY + 0.015, SZ), M["stand"], 0.012)
    FX = SX + 0.21
    box("ge_radio", (0.02, 0.16, 0.22), (FX, -0.36, SZ + 0.32), M["black"], 0.008)
    box("ge_radio_lcd", (0.004, 0.035, 0.12), (FX + 0.012, -0.32, SZ + 0.32), M["lcd"], 0.0)
    box("ccb_plate", (0.015, 0.36, 0.22), (FX, -0.72, SZ + 0.32), M["black"], 0.006)
    tube("ccb_auto", (FX + 0.01, -0.66, SZ + 0.32), (FX + 0.15, -0.6, SZ + 0.36), 0.012, M["red"])
    sphere("ccb_auto_k", 0.022, (FX + 0.15, -0.6, SZ + 0.36), M["red"])
    tube("ccb_ind", (FX + 0.01, -0.84, SZ + 0.3), (FX + 0.13, -0.82, SZ + 0.26), 0.011, M["chrome"])
    sphere("ccb_ind_k", 0.022, (FX + 0.13, -0.82, SZ + 0.26), M["black"])
    box("handset_cradle", (0.08, 0.22, 0.05), (SX, -0.55, SZ + 0.51), M["black"], 0.01)
    box("handset", (0.05, 0.22, 0.04), (SX, -0.55, SZ + 0.545), M["vinyl"], 0.015)
    for k in range(28):
        t = k / 28.0
        sphere("cord%d" % k, 0.009, (SX + math.sin(t * 60) * 0.016, -0.68 - t * 0.35, SZ + 0.55 + math.cos(t * 60) * 0.016), M["black"])
    box("ge_ctrl", (0.015, 0.42, 0.28), (FX, -0.6, SZ), M["black"], 0.006)
    plane("ge_nameplate", 0.22, 0.05, (FX + 0.009, -0.42, SZ), M["paper"], rot_game=(0, math.pi / 2, 0))
    for k, yy in enumerate((-0.52, -0.68)):
        cyl("ge_quad%d" % k, 0.1, 0.02, (FX + 0.012, yy, SZ - 0.02), BLUE, axis="x", segs=40, bevel=0.004)
        tube("ge_lever%d" % k, (FX + 0.02, yy, SZ - 0.02), (FX + 0.16, yy + 0.02, SZ - 0.08), 0.012, M["chrome"])
        tube("ge_grip%d" % k, (FX + 0.15, yy + 0.02, SZ - 0.075), (FX + 0.22, yy + 0.03, SZ - 0.1), 0.019, M["grip"])
    tube("ge_rev", (FX + 0.02, -0.82, SZ + 0.04), (FX + 0.1, -0.82, SZ + 0.08), 0.012, M["black"])
    box("ge_sw_plate", (0.015, 0.34, 0.2), (FX, -0.55, SZ - 0.34), M["black"], 0.006)
    plane("ge_sw", 0.18, 0.3, (FX + 0.009, -0.55, SZ - 0.34), M["switches"], rot_game=(0, math.pi / 2, 0))
    wy = TOPY + 0.09
    box("wab_bracket", (0.06, 0.05, 0.06), (SX + 0.12, TOPY + 0.03, SZ - 0.36), M["cast"], 0.006)
    box("wab_box", (0.07, 0.2, 0.25), (SX + 0.12, wy, SZ - 0.36), M["black"], 0.014, rot_game=(0, -0.9, 0))
    plane("wab_scr", 0.19, 0.14, (SX + 0.12 + 0.036 * math.cos(-0.9 + math.pi / 2), wy + 0.01, SZ - 0.36 + 0.036 * math.cos(0.9)), mat_img("scr1", "/tmp/cabdesign/scr_ptc.png", 0.2, emit=1.4), rot_game=(0, math.pi / 2 - 0.9, 0))
    for k, lz in enumerate((-0.1, 0.12)):
        box("ge_label%d" % k, (0.004, 0.035, 0.12), (FX + 0.01, -0.86, SZ + lz), M["yellow"], 0.0)
    box("pcs_lamp", (0.012, 0.03, 0.03), (FX + 0.012, -0.36, SZ + 0.1), M["led_red"], 0.004)
    ge_desk()


if LAYOUT == "ge":
    layout_ge()
elif LAYOUT == "console":
    layout_console()''')
rep('''box("ctray", (0.32, 0.05, 0.3), (-0.6, -0.32, 0.2), M["stand"], 0.02)
box("ctray_lip", (0.32, 0.12, 0.03), (-0.6, -0.27, 0.34), M["stand"], 0.012)''', '''box("cback_panel", (1.07, 0.2, 0.05), (-0.98, -0.46, 0.08), M["stand"], 0.015)
box("ebv_slot", (0.07, 0.15, 0.01), (-0.98, -0.47, 0.108), M["paper"], 0.003)
tube("ebv_handle", (-0.98, -0.45, 0.12), (-1.0, -0.53, 0.16), 0.01, M["red"])
box("c_handset", (0.05, 0.11, 0.035), (-0.84, -0.47, 0.13), M["vinyl"], 0.012)
box("c_tray", (0.36, 0.03, 0.42), (-1.32, -0.53, 0.38), M["steel"], 0.006)''')
s = s.replace('box("ebv", (0.12, 0.16, 0.1), (-1.47, -0.95, 0.75), M["red"], 0.015)\n', '')
rep('''# ------------------------------------------------------------------ outside''', '''TANL = mat_tex("locker_tan", "cab_wall_tan.png", 1.6, 0.55, 0.05, tint=(1.05, 0.92, 0.78), nor="pbr/paint_nor.jpg", nor_strength=0.5)
BRK = mat_img("breakers", "/tmp/cabdesign/breakers.png", 0.45)
LZ = CAB_LEN - 0.2
for k, lx in enumerate((-0.5, -0.06, 0.38)):
    box("locker%d" % k, (0.42, 1.9, 0.34), (lx, FLOOR + 0.95, LZ), TANL, 0.012)
    box("locker_seam%d" % k, (0.41, 0.008, 0.006), (lx, FLOOR + 1.1, LZ - 0.172), M["black"], 0.0)
    box("locker_latch%d" % k, (0.03, 0.12, 0.03), (lx + 0.16, FLOOR + 0.9, LZ - 0.185), M["steel"], 0.006)
    plane("locker_label%d" % k, 0.12, 0.16, (lx - 0.08, FLOOR + 1.45, LZ - 0.172), M["paper"], rot_game=(0, math.pi, 0))
plane("brk_panel", 0.38, 0.34, (-0.5, FLOOR + 1.45, LZ - 0.172), BRK, rot_game=(0, math.pi, 0))
box("ac_grille", (0.9, 0.12, 0.02), (-0.06, CEIL - 0.12, LZ - 0.17), M["black"], 0.01)
box("jump_frame", (0.38, 0.62, 0.05), (0.38, FLOOR + 0.75, LZ - 0.2), M["cast"], 0.01)
soft("jump_pad", (0.33, 0.5, 0.06), (0.38, FLOOR + 0.78, LZ - 0.25), M["vinyl"], round_=0.4)
for sxx in (-1, 1):
    tube("jump_arm", (0.38 + sxx * 0.2, FLOOR + 0.55, LZ - 0.22), (0.38 + sxx * 0.2, FLOOR + 1.0, LZ - 0.28), 0.012, M["cast"])
for fx in (-1.05, 0.95):
    cyl("cab_fan_box", 0.13, 0.08, (fx, TOP + 0.24, 0.42), M["black"], axis="z", segs=4, bevel=0.01).rotation_euler.y = math.pi / 4
    cyl("cab_fan", 0.085, 0.02, (fx, TOP + 0.24, 0.47), M["cast"], axis="z", segs=32)
for lx in (-0.6, 0.6):
    cyl("spot", 0.045, 0.06, (lx, CEIL - 0.04, 0.75), M["black"], bevel=0.008)

# ------------------------------------------------------------------ outside''')
s = s.replace('scene.render.filepath = OUT + "_" + LAYOUT + "_" + VIEW + ".png"', 'scene.render.filepath = OUT + "_es44_" + LAYOUT + "_" + VIEW + ".png"')
s = s.replace('bpy.ops.wm.save_as_mainfile(filepath="/home/claude/cabdesign/sd70ace_cab.blend")', 'bpy.ops.wm.save_as_mainfile(filepath="/home/claude/cabdesign/es44_cab.blend")')
open("/home/claude/cabdesign/build_es44.py", "w").write(s)
print("ok")
