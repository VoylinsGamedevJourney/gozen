class_name Draggable
extends Node

# TODO: To move multiple clips, code is mostly in place, but not tested yet!
# To fully implement this we would need to add all clips to the
# Timeline.selected_clips array, and also add grouping of clips while
# working on that system of selecting multiple clips.


var ids: PackedInt64Array = []
var files: bool = false
var duration: int = 0 # Duration in frames
var offset: int = 30 # Mouse offset

# For new files only
var new_clips: Array[ClipData] = []

# For clips only
var ignores: Array[Vector2i] = [] # Vector2i(Track id, start_frame)
var clip_buttons: Array[Button] = []
var differences: Vector2i = Vector2i.ZERO # (Frame_difference, Track_difference)

var start_mouse_pos: Vector2



# Give it the index of the array of ids/clip_buttons/new_position ...
func get_clip_data(a_index: int) -> ClipData:
	return Project.get_clip(ids[a_index])

