class_name TrackData
extends Resource


var clips: Dictionary[int, int] = {} # { frame_nr: clip_id }



func set_frame_to_clip(frame_nr: int, clip_id: int) -> void:
	clips[frame_nr] = clip_id
	Project.unsaved_changes = true


func remove_clip_from_frame(frame_nr: int) -> void:
	if !clips.erase(frame_nr):
		return printerr("Could not erase ", frame_nr, " from track!")

	Project.unsaved_changes = true


func get_clip_id(frame_nr: int) -> int:
	return clips[frame_nr]


func get_frame_nrs() -> PackedInt64Array:
	var array: PackedInt64Array = clips.keys()

	array.sort()
	return array


func get_all_clip_ids() -> PackedInt64Array:
	var array: PackedInt64Array = clips.values()

	array.sort()
	return array


func get_size() -> int:
	return clips.size()


## Used for calculating the end of the timeline.
func get_last_clip_id() -> int:
	return clips[get_frame_nrs()[-1]]


func has_frame_nr(frame_nr: int) -> bool:
	return clips.has(frame_nr)
