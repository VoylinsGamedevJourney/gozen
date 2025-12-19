extends Node


signal updated


var tracks: Array[TrackData] = []


func _ready() -> void:
	Project.project_ready.connect(_project_ready)


func _project_ready() -> void:
	tracks = Project.data.tracks

	for id: int in tracks.size():
		tracks[id].id = id


func _reset_track_ids() -> void:
	for id: int in tracks.size():
		tracks[id].id = id

		for clip: ClipData in get_all_clips(id):
			clip.track_id = id
			print(clip.id)
			print(clip.track_id)

	updated.emit()
	

func _add_track(id: int) -> void:
	if tracks.size() == id:
		tracks.append([])
	else:
		tracks.insert(id, [])


func _remove_track(id: int) -> void:
	tracks.remove_at(id)


func _fix_removed_track(id: int, data: TrackData) -> void:
	tracks.insert(id, data)


func add_track(id: int = tracks.size()) -> void:
	InputManager.undo_redo.create_action("Adding track: %s" % id)

	if id == tracks.size():
		InputManager.undo_redo.add_do_method(_add_track.bind(tracks.size()))
		InputManager.undo_redo.add_undo_method(_remove_track.bind(tracks.size()))
	else:
		InputManager.undo_redo.add_do_method(_add_track.bind(id, []))
		InputManager.undo_redo.add_undo_method(_remove_track.bind(id))

	InputManager.undo_redo.add_do_method(_reset_track_ids)
	InputManager.undo_redo.add_undo_method(_reset_track_ids)

	InputManager.undo_redo.commit_action()

	Project.unsaved_changes = true


func remove_track(id: int) -> void:
	if tracks.size() == 1:
		return

	InputManager.undo_redo.create_action("Removing track: %s" % id)

	# NOTE: Clips don't get removed in this way to avoid complexity.
	# Something which I could figure out later on if there is an actual need
	# for this. (Maybe I can have a cleanup on project startup to check which
	# clips are actually used in tracks and which not and remove the remaining
	# references at that moment since it'll only be referenced in one place?)
	InputManager.undo_redo.add_do_method(_remove_track.bind(id))
	InputManager.undo_redo.add_do_method(_reset_track_ids)
	InputManager.undo_redo.add_do_method(updated.emit)
	InputManager.undo_redo.add_undo_method(_fix_removed_track.bind(id, tracks[id]))
	InputManager.undo_redo.add_undo_method(_reset_track_ids)
	InputManager.undo_redo.add_undo_method(updated.emit)

	InputManager.undo_redo.commit_action()


func set_frame_to_clip(track_id: int, clip: ClipData) -> void:
	tracks[track_id].clips[clip.start_frame] = clip.id
	Project.unsaved_changes = true


func remove_clip_from_frame(track_id: int, frame_nr: int) -> void:
	if tracks[track_id].clips.erase(frame_nr):
		Project.unsaved_changes = true


func get_tracks_size() -> int:
	return tracks.size()


func get_clip_id(track_id: int, frame_nr: int) -> int:
	return tracks[track_id].clips[frame_nr]


func get_clip_at_frame(track_id: int, frame_nr: int) -> ClipData:
	return ClipHandler.get_clip(tracks[track_id].clips[frame_nr])


func get_clips_size(track_id: int) -> int:
	return tracks[track_id].clips.size()


func get_frame_nrs(track_id: int) -> PackedInt64Array:
	var array: PackedInt64Array = tracks[track_id].clips.keys()

	array.sort()
	return array


func get_all_frame_nrs(track_id: int) -> PackedInt64Array:
	var array: PackedInt64Array = tracks[track_id].clips.keys()

	array.sort()
	return array


## Get all the clips in a sorted order in which they appear in the timeline.
func get_all_clips(track_id: int) -> Array[ClipData]:
	var array: Array[ClipData] = []
	var keys: PackedInt32Array = tracks[track_id].clips.keys()
	
	keys.sort()
	for key: int in keys:
		array.append(ClipHandler.get_clip(get_clip_id(track_id, key)))

	return array


## Used for calculating the end of the timeline.
func get_last_clip(track_id: int) -> ClipData:
	return ClipHandler.get_clip(tracks[track_id].clips[get_frame_nrs(track_id)[-1]])


func get_clip_at(track_id: int, frame_nr: int) -> ClipData:
	for frame_point: int in get_frame_nrs(track_id):
		if frame_nr < frame_point:
			continue

		var clip: ClipData = ClipHandler.get_clip(tracks[track_id].clips[frame_point])

		if clip.end_frame >= frame_nr: # Check if this is the correct clip.
			return clip
		break
			
	return null


func get_clips_in(track_id: int, start: int, end: int) -> Array[ClipData]:
	var data: Array[ClipData] = []

	for frame_nr: int in get_all_frame_nrs(track_id):
		if frame_nr > end:
			break # We reached the end of possible clips in this track.

		var clip_data: ClipData = ClipHandler.get_clip(get_clip_id(track_id, frame_nr))

		if clip_data.end_frame < start:
			continue # Not reached the point of usable data yet

		data.append(clip_data)

	return data


## Returns start frame of empty area as x and end frame of free area as y
func get_free_region(track_id: int, frame_nr: int, ignores: PackedInt32Array = []) -> Vector2i:
	var data: Vector2i = Vector2i.ZERO
	data.y = Vector2i.MAX.y

	for clip_data: ClipData in get_all_clips(track_id):
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


func has_frame_nr(track_id: int, frame_nr: int) -> bool:
	return tracks[track_id].clips.has(frame_nr)

