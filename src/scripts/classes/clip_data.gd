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

var effects_video: Array[VisualEffect]
var effects_sound: Array[SoundEffect]



func _to_string() -> String:
	return "<Clip:%s>" % id
