class_name ProjectData
extends RefCounted


var project_path: String

# Media
var folders: PackedStringArray = []
var files: Dictionary[int, File] = {}

# Project
var framerate: float = 30.0
var resolution: Vector2i = Vector2i(1920, 1080)
var background_color: Color = Color.BLACK

# Editor state
var playhead_position: int = 0

# Timeline
var timeline_end: int = 0
var tracks: Array[TrackData] = []  # [{frame_nr: id}]
var clips: Dictionary[int, ClipData] = {}  # {id: ClipData}
var markers: Dictionary[int, MarkerData] = {} # { Frame: Marker }

