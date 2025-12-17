class_name TrackData
extends Resource


var clips: Dictionary[int, ClipData] = {} # { frame_nr: clip_data }



func set_frame_to_clip(clip: ClipData) -> void:
	clips[clip.start_frame] = clip
	Project.unsaved_changes = true


func remove_clip_from_frame(frame_nr: int) -> void:
	if !clips.erase(frame_nr):
		return printerr("Could not erase ", frame_nr, " from track!")

	Project.unsaved_changes = true


func get_clip(frame_nr: int) -> int:
	return clips[frame_nr].id


func get_clip_id(frame_nr: int) -> int:
	return clips[frame_nr].id


func get_frame_nrs() -> PackedInt64Array:
	var array: PackedInt64Array = clips.keys()

	array.sort()
	return array


func get_all_frame_nrs() -> PackedInt64Array:
	var array: PackedInt64Array = clips.keys()

	array.sort()
	return array


## Get all the clips in a sorted order in which they appear in the timeline.
func get_all_clips() -> Array[ClipData]:
	var array: Array[ClipData] = []
	var keys: PackedInt32Array = clips.keys()
	
	keys.sort()
	for key: int in keys:
		array.append(clips[key])

	return array


func get_size() -> int:
	return clips.size()


## Used for calculating the end of the timeline.
func get_last_clip() -> ClipData:
	return clips[get_frame_nrs()[-1]]


func get_clips_in(start: int, end: int) -> Array[ClipData]:
	var data: Array[ClipData] = []

	for frame_nr: int in get_all_frame_nrs():
		if frame_nr > end:
			break # We reached the end of possible clips in this track.

		var clip_data: ClipData = Project.get_clip(get_clip_id(frame_nr))

		if clip_data.end_frame < start:
			continue # Not reached the point of usable data yet

		data.append(clip_data)

	return data


## Returns start frame of empty area as x and end frame of free area as y
func get_free_region(frame_nr: int, ignores: PackedInt32Array = []) -> Vector2i:
	var data: Vector2i = Vector2i.ZERO
	data.y = Vector2i.MAX.y

	for clip_data: ClipData in get_all_clips():
		if clip_data.id in ignores:
			continue
		elif clip_data.end_frame < frame_nr:
			data.x = clip_data.end_frame # Beginning free region
		elif clip_data.start_frame > frame_nr:
			data.y = clip_data.start_frame # End of free region
			return data
		else:
			break

	return data


func has_frame_nr(frame_nr: int) -> bool:
	return clips.has(frame_nr)
