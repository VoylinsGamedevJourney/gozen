class_name Draggable
extends RefCounted

const BASE_NAME: String = "<Draggable:%s-%s>"


var ids: PackedInt64Array = []
var files: bool = false
var duration: int = 0 ## Duration in frames

var ignores: Array[PackedInt32Array] = [] ## Tracks[clip_ids]
var track_offset: int = 0
var frame_offset: int = 0
var mouse_offset: int = 30


func _to_string() -> String: return BASE_NAME % ["new_clips" if files else "moving", ids]
