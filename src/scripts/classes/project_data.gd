class_name ProjectData
extends DataManager


var project_path: String

var files: Dictionary[int, File] = {}
var resolution: Vector2i = Vector2i(1920, 1080)
var framerate: float = 30.0

var playhead_position: int = 0
var timeline_end: int = 0

var tracks: Array[Dictionary] = []  # [{frame_nr: clip_id}]
var clips: Dictionary[int, ClipData] = {}  # {clip_id: ClipData}

var background_color: Color = Color.BLACK

# Tracking current timeline for reloading project.
var timeline_scroll_h: int = 0
var zoom: float = 1.0

var folders: PackedStringArray = []

var markers: Dictionary = {} # { Frame: Text }

