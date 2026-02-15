class_name TrackLogic
extends RefCounted

signal updated


var clip_map: Array[PackedInt64Array] = [] ## { track: [clips] }
var frame_map: Array[PackedInt64Array] = [] ## { track: [frames] }

var project_data: ProjectData
var project_clips: ClipLogic


# --- Main ---

func _init(data: ProjectData) -> void:
	project_data = data
	project_clips = Project.clips
	_rebuild_structure()


func _rebuild_structure() -> void:
	clip_map.clear()
	frame_map.clear()
	var track_size: int = project_data.tracks_is_muted.size()

	for _i: int in track_size:
		clip_map.append(PackedInt64Array())
		frame_map.append(PackedInt64Array())

	for index: int in project_data.clips_track.size():
		var track: int = project_data.clips_track[index]
		clip_map[track].append(project_data.clips[index])
		frame_map[track].append(project_data.clips_start[index])


func register_clip(track: int, clip_id: int, frame_nr: int) -> void:
	clip_map[track].append(clip_id)
	frame_map[track].append(frame_nr)


func unregister_clip(track: int, frame_nr: int) -> void:
	var clip_index: int = frame_map[track].find(frame_nr)
	if clip_index == -1:
		return
	clip_map[track].remove_at(clip_index)
	frame_map[track].remove_at(clip_index)


# --- Handling ---

func add_track(track: int) -> void:
	var inserting: bool = track != project_data.tracks_is_muted.size()
	InputManager.undo_redo.create_action("Add track: %s" % track)
	InputManager.undo_redo.add_do_method(_add_track.bind(track, inserting))
	InputManager.undo_redo.add_undo_method(_remove_track.bind(track))
	InputManager.undo_redo.commit_action()


func _add_track(track: int, is_inserting: bool) -> void:
	if is_inserting:
		project_data.tracks_is_muted.insert(track, 0)
		project_data.tracks_is_invisible.insert(track, 0)
		clip_map.insert(track, [])
		frame_map.insert(track, [])
	else: # Track added to end.
		project_data.tracks_is_muted.append(0)
		project_data.tracks_is_invisible.append(0)
		clip_map.append([])
		frame_map.append([])

	Project.unsaved_changes = true
	updated.emit()


func remove_track(track: int) -> void:
	var is_end: bool = track == project_data.tracks_is_muted.size()

	InputManager.undo_redo.create_action("Remove track: %s" % track)

	for clip_id: int in clip_map[track]:
		var clip_index: int = project_clips.index_map[clip_id]
		var clip_snapshot: Dictionary = project_clips._create_snapshot(clip_index)
		InputManager.undo_redo.add_do_method(project_clips._delete.bind(clip_id))
		InputManager.undo_redo.add_undo_method(project_clips._restore_clip_from_snapshot.bind(clip_snapshot))
	InputManager.undo_redo.add_do_method(_remove_track.bind(track))
	InputManager.undo_redo.add_undo_method(_add_track.bind(track, !is_end))
	InputManager.undo_redo.commit_action()


func _remove_track(track: int) -> void:
	project_data.tracks_is_muted.remove_at(track)


# --- Track getters ---

func has_clip_id(track: int, clip_id: int) -> bool:
	return clip_map[track].has(clip_id)


func has_frame_nr(track: int, frame_nr: int) -> bool:
	return frame_map[track].has(frame_nr)


# --- Clip data getters ---

func get_clips(track: int) -> PackedInt64Array:
	return frame_map[track]


func get_frame_nrs(track: int) -> PackedInt64Array:
	return frame_map[track]


func get_clips_after(track: int, frame_nr: int) -> PackedInt64Array: ## Unsorted
	var data: PackedInt64Array = []
	for clip_index: int in frame_map[track].size():
		if frame_map[track][clip_index] < frame_nr:
			continue
		data.append(clip_map[track][clip_index])
	return data


func get_clip_at_frame(track: int, frame_nr: int) -> int:
	return clip_map[track][frame_map[track].find(frame_nr)]


## Used for calculating the end of the timeline.
func get_last_clip(track: int) -> int:
	if track < 0 or track >= project_data.tracks_is_muted.size():
		return -1
	if clip_map[track].is_empty():
		return -1

	var max_end: int = -1
	var last_clip_id: int = -1
	for i: int in clip_map[track].size():
		var clip_id: int = clip_map[track][i]
		if !project_clips.index_map.has(clip_id):
			continue
		var clip_index: int = project_clips.index_map[clip_id]
		var clip_start: int = project_data.clips_start[clip_index]
		var clip_end: int = project_data.clips_duration[clip_index] + clip_start
		if clip_end > max_end:
			max_end = clip_end
			last_clip_id = clip_id
	return last_clip_id


## Get a clip which starts at frame_nr.
func get_clip_id(track: int, frame_nr: int) -> int:
	var frame_index: int = frame_map[track].find(frame_nr)
	if frame_index == -1:
		return -1
	return clip_map[track][frame_index]


## Get a clip which is overlapping with frame_nr.
func get_clip_id_at(track: int, frame_nr: int) -> int:
	if track < 0 or track >= project_data.tracks_is_muted.size():
		return -1
	for i: int in frame_map[track].size():
		var start: int = frame_map[track][i]
		if frame_nr < start:
			continue
		var clip_id: int = clip_map[track][i]
		var clip_index: int = project_clips.index_map[clip_id]
		var clip_start: int = project_data.clips_start[clip_index]
		var clip_end: int = project_data.clips_duration[clip_index] + clip_start
		if frame_nr >= clip_start and frame_nr < clip_end:
			return clip_id
	return -1


## Returns all clip id's that are within range.
func get_clip_ids_in(track: int, start: int, end: int) -> PackedInt64Array:
	var result: PackedInt64Array = []
	if track < 0 or track >= project_data.tracks_is_muted.size():
		return result

	for i: int in frame_map[track].size():
		var clip_start: int = frame_map[track][i]
		var clip_id: int = clip_map[track][i]
		if clip_start >= end or !project_clips.index_map.has(clip_id):
			continue

		var clip_index: int = project_clips.index_map[clip_id]
		var clip_end: int = clip_start + project_data.clips_duration[clip_index]
		if clip_end > start and clip_start < end:
			result.append(clip_id)
	return result


## Returns start frame of an empty area as x and end frame of a free area as y.
func get_free_region(track: int, frame_nr: int, ignores: PackedInt64Array = []) -> Vector2i:
	var region: Vector2i = Vector2i(-1, -1)
	if track < 0 or track >= project_data.tracks_is_muted.size():
		return region
	var collision_id: int = get_clip_id_at(track, frame_nr)
	if collision_id != -1 and collision_id not in ignores:
		return region

	region.x = 0
	region.y = 2147483647 # Max integer value.
	for i: int in clip_map[track].size():
		var clip_id: int = clip_map[track][i]
		if clip_id in ignores or !project_clips.index_map.has(clip_id):
			continue

		var clip_index: int = project_clips.index_map[clip_id]
		var clip_start: int = frame_map[track][i]
		var clip_end: int = clip_start + project_data.clips_duration[clip_index]
		if clip_end <= frame_nr:
			region.x = maxi(region.x, clip_end)
		elif clip_start > frame_nr:
			region.y = mini(region.y, clip_start)
	return region
