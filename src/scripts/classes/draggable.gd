class_name Draggable
extends RefCounted


var ids: PackedInt64Array = []
var files: bool = false
var duration: int = 0 # Duration in frames

var ignores: Array[PackedInt32Array] = [] # Tracks[clip_ids]
var track_offset: int = 0
var frame_offset: int = 0
var mouse_offset: int = 30



# Give it the index of the array of ids/clip_buttons/new_position ...
func get_clip_data(index: int) -> ClipData:
	return Project.clips.get_clip(ids[index])


func _to_string() -> String:
	return "<Draggable:%s-%s>" % ["new_clips" if files else "moving", ids]

