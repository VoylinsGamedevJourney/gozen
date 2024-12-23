class_name Draggable extends Node


var ids: PackedInt64Array = []
var files: bool = false
var duration: int = 0 # Duration in frames
var mouse_offset: int = 30

# For clips only
var ignore: Array[Vector2i] = [] # Vector2i(Track id, start_frame)
var clip_buttons: Array[Button] = []
