class_name MoveClipRequest
extends RefCounted


var clip_id: int = 0
var frame_offset: int = 0
var track_offset: int = 0



func _init(id: int, _frame_offset: int, _track_offset: int) -> void:
	clip_id = id
	frame_offset = _frame_offset
	track_offset = _track_offset

