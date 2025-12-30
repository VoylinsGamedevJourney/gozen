class_name CutClipRequest
extends RefCounted


var clip_id: int = 0
var cut_frame_pos: int = 0



func _init(id: int, _frame_cut_pos: int) -> void:
	clip_id = id
	cut_frame_pos = _frame_cut_pos

