class_name ProjectData
extends RefCounted

# Global settings
var project_path: String = ""
var framerate: float = 30.0
var resolution: Vector2i = Vector2i(1920, 1080)
var background_color: Color = Color.BLACK
var timeline_end: int = 0
var playhead_position: int = 0

var folders: PackedStringArray = []

var files_id: PackedInt64Array = []
var files_path: PackedStringArray = [] ## Temporary files start with "temp://".
var files_proxy_path: PackedStringArray = []
var files_nickname: PackedStringArray = []
var files_folder: PackedStringArray = [] ## Folder inside the editor.
var files_type: PackedInt32Array = []
var files_duration: PackedInt64Array = []
var files_modified_time: PackedInt64Array = []

# These variables are too specific to certain types to create empty array
# entries for.
var files_temp_file: Dictionary[int, TempFile] = {} ## { file_id: temp_file }
var files_ato_active: Dictionary[int, bool] = {} ## { file_id: bool }
var files_ato_offset: Dictionary[int, float] = {} ## { file_id: offset }
var files_ato_id: Dictionary[int, int] = {} ## { file_id: audio-take-over file id }

var tracks_is_muted: PackedByteArray = [] ## 0 = not muted, 1 = muted
var tracks_is_invisible: PackedByteArray = [] ## 0 = not invisible, 1 = visible

var clips_id: PackedInt64Array = []
var clips_file_id: PackedInt64Array = []
var clips_track_id: PackedInt64Array = []
var clips_start: PackedInt64Array = []
var clips_begin: PackedInt64Array = [] ## Only for video and audio files
var clips_duration: PackedInt64Array = []
var clips_effects: Array[ClipEffects] = []

# This variable is only necessary for video files, so only the id's of clips
# who require an individual video file will be presented here
var clips_individual_video: PackedInt64Array = [] ## [ clip_id's ]

var markers_frame: PackedInt64Array = []
var markers_text: PackedStringArray = []
var markers_type: PackedInt32Array = []
