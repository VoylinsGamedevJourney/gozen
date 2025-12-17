class_name MoveClipRequest
extends RefCounted


var clip_id: int = 0
var frame_offset: int = 0
var track_offset: int = 0



func _init(id: int, f_offset: int, t_offset: int) -> void:
	clip_id = id
	frame_offset = f_offset
	track_offset = t_offset

