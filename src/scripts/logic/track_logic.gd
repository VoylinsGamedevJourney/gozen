class_name TrackLogic
extends RefCounted


signal updated


var clip_ids: Array[PackedInt64Array] = [] # { track_index: [clip_ids] }
var frame_nrs: Array[PackedInt64Array] = [] # { track_index: [frame_nrs] }

var project_data: ProjectData

var _id_map: Dictionary[int, int] = {} # { track_id: index }



func _init(data: ProjectData) -> void:
	project_data = data
	for index: int in get_size(): update_track_info(index)
	_rebuild_map()


func _rebuild_map() -> void:
	_id_map.clear()
	for i: int in project_data.clips_id.size():
		_id_map[project_data.clips_id[i]] = i


func register_clip(index: int, clip_id: int, frame_nr: int) -> void:
	clip_ids[index].append(clip_id)
	frame_nrs[index].append(frame_nr)


func unregister_clip(index: int, frame_nr: int) -> void:
	var clip_index: int = frame_nrs.find(frame_nr)
	if clip_index == -1: return
	clip_ids[index].remove_at(clip_index)
	frame_nrs[index].remove_at(clip_index)


# --- Handling ---

func add_track(index: int) -> void:
	var inserting: bool = index != get_size()
	InputManager.undo_redo.create_action("Add track: %s" % index)
	InputManager.undo_redo.add_do_method(_add_track.bind(index, inserting))
	InputManager.undo_redo.add_undo_method(_remove_track.bind(index))
	InputManager.undo_redo.commit_action()


func _add_track(index: int, is_inserting: bool) -> void:
	if is_inserting:
		project_data.tracks_is_muted.insert(index, 0)
		project_data.tracks_is_invisible.insert(index, 0)
		clip_ids.insert(index, [])
		frame_nrs.insert(index, [])
	else: # Track added to end.
		project_data.tracks_is_muted.append(0)
		project_data.tracks_is_invisible.append(0)
		clip_ids.append([])
		frame_nrs.append([])

	Project.unsaved_changes = true
	updated.emit()


func remove_track(index: int) -> void:
	var is_end: bool = index == get_size()

	InputManager.undo_redo.create_action("Remove track: %s" % index)

	for clip_id: int in clip_ids[index]:
		InputManager.undo_redo.add_do_method(Project.clips._delete_clip.bind(clip_id))
		InputManager.undo_redo.add_undo_method(Project.clips._add_clip.bind(clip_id))

	InputManager.undo_redo.add_do_method(_remove_track.bind(index))
	InputManager.undo_redo.add_undo_method(_add_track.bind(index, !is_end))

	InputManager.undo_redo.commit_action()


func _remove_track(index: int) -> void:
	project_data.tracks_is_muted.remove_at(index)
	project_data.tracks_is_invisible.remove_at(index)
	clip_ids.remove_at(index)
	frame_nrs.remove_at(index)


func update_track_info(_index: int) -> void:
	# TODO: update clip_ids ( Can only start doing this after I finish ClipLogic )
	# TODO: update frame_nrs ( Can only start doing this after I finish ClipLogic )
	pass


func update_clip_info(clip_id: int) -> void:
	var clip_index: int = clip_ids.find(clip_id)

	if clip_index == -1: # Clip probably got deleted so check the track clip_ids.
		for index: int in get_size():
			clip_index = clip_ids[index].find(clip_id)

			if clip_index != -1:
				clip_ids.remove_at(index)
				frame_nrs.remove_at(index)
				return
		return printerr("TrackLogic: Invalid clip id '%s'!" % clip_id)

	var track_index: int = Project.clips.track_ids[clip_index]
	var frame_nr: int = Project.clips.start_frames[clip_index]
	clip_index = clip_ids[track_index].find(clip_id)

	if clip_index == -1: # Data not found, let's add it :p
		clip_ids[track_index].append(clip_id)
		frame_nrs[track_index].append(frame_nr)
	else: # We just update the data.
		frame_nrs[track_index][clip_index] = frame_nr



# --- Track getters ---

func get_size() -> int: return project_data.tracks_is_muted.size()


# --- Clip data getters ---

func get_track_size(track_index: int) -> int: return clip_ids[track_index].size()
func get_clip_ids(track_index: int) -> PackedInt64Array: return frame_nrs[track_index]
func get_frame_nrs(track_index: int) -> PackedInt64Array: return frame_nrs[track_index]


func get_clip_ids_after(track_index: int, frame_nr: int) -> PackedInt64Array: ## Unsorted
	var data: PackedInt64Array = []

	for index: int in frame_nrs[track_index].size():
		if frame_nrs[track_index][index] < frame_nr: continue
		data.append(clip_ids[track_index][index])
	return data


func get_clip_id_at_frame(track_index: int, frame_nr: int) -> int:
	return clip_ids[track_index][frame_nrs[track_index].find(frame_nr)]


## Used for calculating the end of the timeline.
func get_last_clip_id(track_index: int) -> int:
	while true:
		if tracks[track_index].clips.size() == 0:
			return -1

		var frame_nr: int = get_frame_nrs(track_index)[-1]
		var clip_id: int = tracks[track_index].clips[frame_nr]

		if !Project.clips.clips.has(clip_id):
			tracks[track_index].clips.erase(frame_nr)
			continue
		break

	return Project.clips.get_clip(tracks[track_index].clips[get_frame_nrs(track_index)[-1]])


func get_clip_at(track_index: int, frame_nr: int) -> ClipData:
	# TODO: Check if this would be faster if going backwards
	for frame_point: int in get_frame_nrs(track_index):
		if frame_nr < frame_point:
			continue

		var clip_data: ClipData = Project.clips.get_clip(tracks[track_index].clips[frame_point])

		if clip_data == null:
			remove_clip_from_frame(track_index, frame_nr)
			continue
		elif clip_data.end_frame > frame_nr: # Check if this is the correct clip.
			return clip_data

	return null


func get_clips_in(track_index: int, start: int, end: int) -> Array[ClipData]:
	var data: Array[ClipData] = []

	for frame_nr: int in get_all_frame_nrs(track_index):
		if frame_nr > end:
			break # We reached the end of possible clips in this track.

		var clip_data: ClipData = Project.clips.get_clip(tracks[track_index].clips[frame_nr])

		if clip_data == null:
			remove_clip_from_frame(track_index, frame_nr)
			continue
		elif clip_data.end_frame < start:
			continue # Not reached the point of usable data yet

		data.append(clip_data)

	return data


## Returns start frame of empty area as x and end frame of free area as y
func get_free_region(track_index: int, frame_nr: int, ignores: PackedInt64Array = []) -> Vector2i:
	var data: Vector2i = Vector2i.ZERO
	data.y = Vector2i.MAX.y

	var collision_clip: ClipData = get_clip_at(track_index, frame_nr)

	if collision_clip != null and collision_clip.id not in ignores:
		return Vector2i(-1, -1) # Early check if collision is happening

	for clip_data: ClipData in get_all_clips(track_index):
		if clip_data.id in ignores:
			continue
		elif clip_data.end_frame <= frame_nr: # Finding beginning free region
			data.x = max(data.x, clip_data.end_frame)
		elif clip_data.start_frame >= frame_nr: # End of free region
			data.y = clip_data.start_frame
			break

	return data


func has_frame_nr(track_index: int, frame_nr: int) -> bool:
	return tracks[track_index].clips.has(frame_nr)


# --- Getters ---

func size() -> int: return clip_ids.size()
