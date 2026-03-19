class_name ProjectData
extends RefCounted


var project_path: String = ""
var framerate: float = 30.0
var resolution: Vector2i = Vector2i(1920, 1080)
var background_color: Color = Color.BLACK
var timeline_end: int = 0
var playhead: int = 0 ## Playhead position.

var files: Dictionary[int, FileData] = {} ## { file_id: file_data }
var clips: Dictionary[int, ClipData] = {} ## { clip_id: clip_data }
var tracks: Array[TrackData] = []

var markers: Array[MarkerData] = []
var folders: Array[String] = []
