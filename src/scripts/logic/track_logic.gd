class_name TrackLogic
extends RefCounted


signal updated


var clip_ids: Array[PackedInt64Array] = [] # { track_index: [clip_ids] }
var frame_nrs: Array[PackedInt64Array] = [] # { track_index: [frame_nrs] }

var project_data: ProjectData



func _init(data: ProjectData) -> void:
	project_data = data
	_rebuild_structure()


func _rebuild_structure() -> void:
	clip_ids.clear()
	frame_nrs.clear()

	for i: int in size():
		clip_ids.append(PackedInt64Array())
		frame_nrs.append(PackedInt64Array())

	for i: int in Project.clips.size():
		var track_id: int = Project.clips.get_track_id(i)
		var start: int = Project.clips.get_start_frame(i)
		var id: int = Project.clips.get_id(i)

		if track_id >= 0 and track_id < size(): # Quick check if valid.
			clip_ids[track_id].append(id)
			frame_nrs[track_id].append(start)


func register_clip(index: int, clip_id: int, frame_nr: int) -> void:
	if index < 0 or index >= size(): return
	clip_ids[index].append(clip_id)
	frame_nrs[index].append(frame_nr)


func unregister_clip(index: int, frame_nr: int) -> void:
	if index < 0 or index >= size(): return
	var clip_index: int = frame_nrs.find(frame_nr)
	if clip_index == -1: return
	clip_ids[index].remove_at(clip_index)
	frame_nrs[index].remove_at(clip_index)


func update_clip(index: int, old_frame: int, new_frame: int) -> void:
	if index < 0 or index >= size(): return
	var frame_nr_index: int = frame_nrs[index].find(old_frame)
	if frame_nr_index == -1: return
	frame_nrs[index][frame_nr_index] = new_frame


# --- Handling ---

func add_track(index: int) -> void:
	var inserting: bool = index != size()
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
	var is_end: bool = index == size()

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
		for index: int in size():
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

func size() -> int: return project_data.tracks_is_muted.size()
func has_clip_id(index: int, clip_id: int) -> bool: return clip_ids[index].has(clip_id)
func has_frame_nr(index: int, frame_nr: int) -> bool: return frame_nrs[index].has(frame_nr)


# --- Clip data getters ---

func get_clip_ids(track_index: int) -> PackedInt64Array: return frame_nrs[track_index]
func get_frame_nrs(track_index: int) -> PackedInt64Array: return frame_nrs[track_index]


func get_clip_ids_after(track_index: int, frame_nr: int) -> PackedInt64Array: ## Unsorted
	var data: PackedInt64Array = []
	for index: int in size():
		if frame_nrs[track_index][index] < frame_nr: continue
		data.append(clip_ids[track_index][index])
	return data


func get_clip_id_at_frame(track_index: int, frame_nr: int) -> int:
	return clip_ids[track_index][frame_nrs[track_index].find(frame_nr)]


## Used for calculating the end of the timeline.
func get_last_clip_id(track_index: int) -> int:
	if track_index < 0 or track_index >= size(): return -1
	if clip_ids[track_index].is_empty(): return -1

	var max_end: int = -1
	var last_clip_id: int = -1
	for i: int in clip_ids[track_index].size():
		var clip_id: int = clip_ids[track_index][i]
		if !Project.clips.has(clip_id): continue
		var end: int = Project.clips.get_end(Project.clips.get_index(clip_id))
		if end > max_end:
			max_end = end
			last_clip_id = clip_id
	return last_clip_id


## Get a clip which starts at frame_nr.
func get_clip_id(index: int, frame_nr: int) -> int:
	var frame_nr_index: int = frame_nrs[index].find(frame_nr)
	if frame_nr_index == -1: return -1
	return clip_ids[index][frame_nr_index]


## Get a clip which is overlapping with frame_nr.
func get_clip_id_at(index: int, frame_nr: int) -> int:
	if index < 0 or index >= size(): return -1
	for i: int in frame_nrs[index].size():
		var start: int = frame_nrs[index][i]
		if frame_nr < start: continue
		var id: int = clip_ids[index][i]
		var end: int = Project.clips.get_end(Project.clips.get_index(id))
		if frame_nr >= start and frame_nr < end: return id
	return -1


## Returns all clip id's that are within range.
func get_clip_ids_in(index: int, start: int, end: int) -> PackedInt64Array:
	var result: PackedInt64Array = []
	if index < 0 or index >= size(): return result

	for i: int in frame_nrs[index].size():
		var clip_start: int = frame_nrs[index][i]
		var clip_id: int = clip_ids[index][i]
		if clip_start >= end or !Project.clips.has(clip_id): continue

		var clip_end: int = Project.clips.get_end_frame_by_id(clip_id)
		if clip_end > start and clip_start < end: result.append(clip_id)
	return result


## Returns start frame of an empty area as x and end frame of a free area as y.
func get_free_region(index: int, frame_nr: int, ignores: PackedInt64Array = []) -> Vector2i:
	var region: Vector2i = Vector2i(-1, -1)
	if index < 0 or index >= size(): return region
	var collision_id: int = get_clip_id_at(index, frame_nr)
	if collision_id != -1 and collision_id not in ignores: return region

	region.x = 0
	region.y = 2147483647 # Max integer value.
	for i: int in clip_ids[index].size():
		var clip_id: int = clip_ids[index][i]
		if clip_id in ignores or !Project.clips.has(clip_id): continue

		var start: int = frame_nrs[index][i]
		var end: int = Project.clips.get_end_frame_by_id(clip_id)
		if end <= frame_nr: region.x = maxi(region.x, end)
		elif start > frame_nr: region.y = mini(region.y, start)
	return region
