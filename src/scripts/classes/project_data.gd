class_name ProjectData
extends RefCounted


const VERSION: int = 2


var version: int = VERSION
var project_path: String = ""
var framerate: float = 30.0
var resolution: Vector2i = Vector2i(1920, 1080)
var background_color: Color = Color.BLACK
var timeline_end: int = 0
var playhead: int = 0 ## Playhead position.

var render_region: Vector2i = Vector2i(0, 1200)
var use_render_region: bool = false

var files: Dictionary[int, FileData] = {} ## { file_id: file_data }
var clips: Dictionary[int, ClipData] = {} ## { clip_id: clip_data }
var tracks: Array[TrackData] = []

var markers: Array[MarkerData] = []
var folders: Array[String] = []


#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = {
		"version": version,
		"project_path": project_path,
		"timeline_end": timeline_end,
		"playhead": playhead,
		"folders": folders,
		"files": {}, "clips": {},
		"tracks": []}

	if background_color != Color.BLACK:
		data["background_color"] = background_color.to_html()
	if framerate != 30.0:
		data["framerate"] = framerate
	if resolution != Vector2i(1920, 1080):
		data["resolution"] = resolution

	if render_region.x != render_region.y:
		data["render_region"] = render_region
	if use_render_region:
		data["use_render_region"] = true

	if markers.size() != 0:
		data["markers"] = []

	for file_id: int in files:
		data["files"][file_id] = files[file_id].serialize()
	for clip_id: int in clips:
		data["clips"][clip_id] = clips[clip_id].serialize()

	for track: TrackData in tracks:
		(data["tracks"] as Array).append(track.serialize())
	for marker: MarkerData in markers:
		(data["markers"] as Array).append(marker.serialize())
	return data


## Trying to keep everything compatible with already made projects. for V1.0 we
## should probably remove some of the compatibility checking.
func deserialize(data: Dictionary) -> void:
	version = data.get("version", VERSION) if data.get("version") != null else VERSION
	project_path = data.get("project_path", "")
	framerate = data.get("framerate", 30.0)
	resolution = data.get("resolution", Vector2i(1920, 1080))

	var bg_color: Variant = data.get("background_color", Color.BLACK)
	if typeof(bg_color) == TYPE_STRING:
		background_color = Color(bg_color as String)
	else:
		background_color = bg_color

	timeline_end = data.get("timeline_end", 0)
	playhead = data.get("playhead", 0)
	render_region = data.get("render_region", Vector2i(0, int(framerate * 60.0)))
	use_render_region = data.get("use_render_region", false)

	folders.clear()
	for folder: String in data["folders"]:
		folders.append(folder)

	files.clear()
	for file_id: int in data["files"]:
		var value: Variant = data["files"][file_id]
		if value is FileData:
			files[int(file_id)] = value
		else:
			files[int(file_id)] = FileData.new()
			files[int(file_id)].deserialize(value as Dictionary)

	clips.clear()
	if data.has("clips"):
		for clip_id: int in data["clips"]:
			var value: Variant = data["clips"][clip_id]
			if value is ClipData:
				clips[int(clip_id)] = value
			else:
				var color: ClipData = ClipData.new()
				color.deserialize(value as Dictionary)
				clips[int(clip_id)] = color

	tracks.clear()
	if data.has("tracks"):
		for track_value: Variant in data["tracks"]:
			if track_value is TrackData:
				tracks.append(track_value)
			else:
				var track: TrackData = TrackData.new()
				track.deserialize(track_value as Dictionary)
				tracks.append(track)

	markers.clear()
	if data.has("markers"):
		for marker_value: Variant in data["markers"]:
			if marker_value is MarkerData:
				markers.append(marker_value)
			else:
				var marker: MarkerData = MarkerData.new()
				marker.deserialize(marker_value as Dictionary)
				markers.append(marker)

	if version == 1:
		_migrate_v1_to_v2()
	if version == VERSION:
		return


## Map the old incremental integer IDs to the new bitwise flags (Type class).
## (Verify that these match what the old EditorCore.Type enum was).
func _migrate_v1_to_v2() -> void:
	if files.is_empty():
		version = 2
		return

	var type_map: Dictionary = {
		-1: Type.EMPTY,
		0: Type.IMAGE,
		1: Type.AUDIO,
		2: Type.VIDEO,
		3: Type.TEXT,
		4: Type.COLOR,
		5: Type.PCK,
	}

	for file_id: int in files:
		var file: FileData = files[file_id]
		if type_map.has(file.type):
			file.type = type_map[file.type]

	for clip_id: int in clips:
		var clip: ClipData = clips[clip_id]
		if type_map.has(clip.type):
			clip.type = type_map[clip.type]

	version = 2
