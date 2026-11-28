extends Node
## Downloadable content packs (HD locomotive cabs now; scenery regions later).
## The app ships small; packs are .pck files downloaded to user://packs/ and mounted at
## startup with ProjectSettings.load_resource_pack, which overlays res://models/... etc.

const PACK_VERSION := 1
const BASE_URL := "https://github.com/Hoganator21/Rail-Road-Game/releases/download/content-packs/"
const PACKS := {
	"sd70ace": {"name": "EMD SD70ACe HD cab", "locos": ["sd70ace"]},
	"es44ac": {"name": "GE ES44AC HD cab", "locos": ["modern"]},
	"gp38": {"name": "EMD GP38-2 HD cab", "locos": ["classic", "classic_lhf"]},
}
const DIR := "user://packs/"

signal progress(id: String, done_bytes: int, total_bytes: int)
signal finished(id: String, ok: bool, msg: String)

var http: HTTPRequest
var busy_id := ""
var mounted := {}

func platform() -> String:
	return "android" if OS.has_feature("android") else "windows"

func file_name(id: String) -> String:
	return "%s_%s_v%d.pck" % [id, platform(), PACK_VERSION]

func path(id: String) -> String:
	return DIR + file_name(id)

func installed(id: String) -> bool:
	return FileAccess.file_exists(path(id))

func pack_for_loco(kind: String) -> String:
	for id in PACKS:
		if kind in PACKS[id]["locos"]:
			return id
	return ""

func size_mb(id: String) -> float:
	if not installed(id):
		return 0.0
	var f := FileAccess.open(path(id), FileAccess.READ)
	return f.get_length() / 1048576.0 if f else 0.0

## Mount every installed pack (call once at startup, before building any cab).
func mount_all() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_cleanup_old()
	for id in PACKS:
		if installed(id):
			mount(id)

func mount(id: String) -> bool:
	if mounted.has(id):
		return true
	var ok := ProjectSettings.load_resource_pack(path(id), false)
	if ok:
		mounted[id] = true
	return ok

## Packs from older versions are useless once the game moves on.
func _cleanup_old() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".pck") and not f.ends_with("_v%d.pck" % PACK_VERSION):
			d.remove(f)

func download(id: String) -> void:
	if busy_id != "":
		return
	busy_id = id
	if http == null:
		http = HTTPRequest.new()
		http.use_threads = true
		http.max_redirects = 10
		add_child(http)
		http.request_completed.connect(_on_done)
	http.download_file = path(id) + ".part"
	var err := http.request(BASE_URL + file_name(id))
	if err != OK:
		busy_id = ""
		finished.emit(id, false, "Could not start the download (%d)" % err)

func cancel() -> void:
	if http and busy_id != "":
		http.cancel_request()
		DirAccess.remove_absolute(path(busy_id) + ".part")
		var id := busy_id
		busy_id = ""
		finished.emit(id, false, "Cancelled")

func _process(_dt: float) -> void:
	if busy_id != "" and http:
		progress.emit(busy_id, http.get_downloaded_bytes(), http.get_body_size())

func _on_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	var id := busy_id
	busy_id = ""
	var part := path(id) + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part)
		finished.emit(id, false, "Download failed (%s)" % (str(code) if result == HTTPRequest.RESULT_SUCCESS else "network"))
		return
	DirAccess.rename_absolute(part, path(id))
	var ok := mount(id)
	finished.emit(id, ok, "Installed" if ok else "Downloaded but could not load the pack")

## Deleting takes effect on the next launch (a mounted pack stays loaded until then).
func remove(id: String) -> void:
	DirAccess.remove_absolute(path(id))
