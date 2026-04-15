class_name ProjectData
extends RefCounted


var project_path: String = ""
var framerate: float = 30.0
var resolution: Vector2i = Vector2i(1920, 1080)
var background_color: Color = Color.BLACK
var timeline_end: int = 0
var playhead: int = 0 ## Playhead position.

var render_region: Vector2i = Vector2i(0, 0)
var use_render_region: bool = false

var files: Dictionary[int, FileData] = {} ## { file_id: file_data }
var clips: Dictionary[int, ClipData] = {} ## { clip_id: clip_data }
var tracks: Array[TrackData] = []

var markers: Array[MarkerData] = []
var folders: Array[String] = []



#--- Data handling ---

func serialize() -> Dictionary[String, Variant]:
	var data: Dictionary = {
		"project_path": project_path,
		"framerate": framerate,
		"resolution": resolution,
		"background_color": background_color.to_html(),
		"timeline_end": timeline_end,
		"playhead": playhead,
		"render_region": render_region,
		"use_render_region": use_render_region,
		"folders": folders,
		"files": {},
		"clips": {},
		"tracks": [],
		"markers": []}

	@warning_ignore_start("unsafe_method_access")
	for file_id: int in files:
		data["files"][file_id] = files[file_id].serialize()

	for clip_id: int in clips:
		data["clips"][clip_id] = clips[clip_id].serialize()

	for track: TrackData in tracks:
		data["tracks"].append(track.serialize())

	for marker: MarkerData in markers:
		data["markers"].append(marker.serialize())
	@warning_ignore_restore("unsafe_method_access")
	return data


## Trying to keep everything compatible with already made projects. for V1.0 we
## should probably remove some of the compatibility checking.
func deserialize(data: Dictionary) -> void:
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
	render_region = data.get("render_region", Vector2i(0, 0))
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
			var file: FileData = FileData.new()
			file.deserialize(value as Dictionary)
			files[int(file_id)] = file

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
