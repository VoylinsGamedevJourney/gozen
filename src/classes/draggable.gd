class_name Draggable
extends Node


enum {
	NEW_CLIP = 0b00,
	NEW_CLIPS = 0b10,
	MOVE_CLIP = 0b01,
	MOVE_CLIPS = 0b11,
}


var type: int
var data: PackedInt64Array = [] # NEW_ use File ID's and MOVE_ use Clip ID's
var mouse_pos: float


func _init(a_type: int, a_data: PackedInt64Array, a_pos: float = 0.) -> void:
	type = a_type
	data = a_data
	mouse_pos = a_pos

