class_name CreateClipRequest
extends RefCounted


var file_id: int
var track_id: int
var frame_nr: int



func _init(file: int, track: int, frame: int) -> void:
	file_id = file
	track_id = track
	frame_nr = frame

