"""Append one export preset per content pack and platform to godot/export_presets.cfg.
Used by CI: each preset exports only that pack's files (+ dependencies) with --export-pack."""
import re, sys

PACKS = {
    "sd70ace": ["sd70ace_stand", "sd70ace_desktop"],
    "es44ac": ["es44ac_ge", "es44ac_desktop"],
    "gp38": ["gp38_factory", "gp38_factory_lhf"],
}
PLATFORMS = {"windows": 0, "android": 1}

path = sys.argv[1] if len(sys.argv) > 1 else "godot/export_presets.cfg"
src = open(path).read()
sections = {}
for m in re.finditer(r"^\[(preset\.\d+(?:\.options)?)\]\n(.*?)(?=^\[|\Z)", src, re.S | re.M):
    sections[m.group(1)] = m.group(2)
n = max(int(k.split(".")[1]) for k in sections) + 1
out = src.rstrip() + "\n"
for pack, models in PACKS.items():
    files = []
    for mname in models:
        files += ["res://models/%s.glb" % mname, "res://models/%s_ao.png" % mname, "res://models/%s_wear.png" % mname]
    for plat, base in PLATFORMS.items():
        head = sections["preset.%d" % base]
        head = re.sub(r'^name=".*"$', 'name="Pack %s %s"' % (pack, plat), head, flags=re.M)
        head = re.sub(r'^export_filter=".*"$', 'export_filter="resources"\nexport_files=PackedStringArray(%s)' % ", ".join('"%s"' % f for f in files), head, flags=re.M)
        head = re.sub(r'^exclude_filter=".*"$', 'exclude_filter=""', head, flags=re.M)
        head = re.sub(r'^export_path=".*"$', 'export_path=""', head, flags=re.M)
        out += "\n[preset.%d]\n\n%s\n[preset.%d.options]\n\n%s" % (n, head.strip() + "\n", n, sections["preset.%d.options" % base].strip() + "\n")
        n += 1
open(path, "w").write(out)
print("added pack presets up to preset.%d" % (n - 1))
