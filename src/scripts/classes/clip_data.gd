class_name ClipData
extends RefCounted



var id: int
var file_id: int
var track_id: int

var start_frame: int
var duration: int
var end_frame: int:
	get: return start_frame + duration

var begin: int = 0 # Only for video and audio files

var effects_video: Array[GoZenEffectVisual]
var effects_audio: Array[GoZenEffectAudio]

var fade_in_visual: int = 0
var fade_out_visual: int = 0

var fade_in_audio: int = 0
var fade_out_audio: int = 0

# Audio take-over variables.
var ato_file_id: int = -1
var ato_offset: float = 0.0 # Seconds
var ato_active: bool = false



func _to_string() -> String:
	return "<Clip:%s>" % id
