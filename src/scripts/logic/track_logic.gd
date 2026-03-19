extends Node


signal updated


var tracks: Array[TrackData]
var track_clips: Array[TrackClips] = []



## We need to run this before anything else after loading the project so we
## have all the data correctly.
func prepare_data() -> void:
	for _i: int in tracks.size():
		track_clips.append(TrackClips.new())
	for clip: ClipData in ClipLogic.clips.values():
		track_clips[clip.track].clips.append(clip)
	for clips: TrackClips in track_clips:
		clips.sort()


# --- Handling ---

func add_track(track: int) -> void:
	InputManager.undo_redo.create_action("Add track: %s" % track)
	InputManager.undo_redo.add_do_method(_add_track.bind(track))
	InputManager.undo_redo.add_undo_method(_remove_track.bind(track))
	InputManager.undo_redo.commit_action()


func _add_track(track: int) -> void:
	if track < tracks.size():
		tracks.insert(track, TrackData.new())
		track_clips.insert(track, TrackClips.new())
		for track_id: int in range(track + 1, tracks.size()):
			for clip: ClipData in track_clips[track_id].clips:
				clip.track = track_id
	else:
		tracks.append(TrackData.new())
		track_clips.append(TrackClips.new())
	Project.unsaved_changes = true
	updated.emit()


func remove_track(track: int) -> void:
	InputManager.undo_redo.create_action("Remove track: %s" % track)
	for clip: ClipData in track_clips[track].clips:
		InputManager.undo_redo.add_do_method(ClipLogic._delete.bind(clip.id))
		InputManager.undo_redo.add_undo_method(ClipLogic._restore_clip.bind(clip))
	InputManager.undo_redo.add_do_method(_remove_track.bind(track))
	InputManager.undo_redo.add_undo_method(_add_track.bind(track))
	InputManager.undo_redo.commit_action()


func _remove_track(track: int) -> void:
	tracks.remove_at(track)
	track_clips.remove_at(track)
	for track_id: int in range(track, tracks.size()):
		for clip: ClipData in track_clips[track_id].clips:
			clip.track = track_id
	Project.unsaved_changes = true
	updated.emit()


func add_clip_to_track(track: int, clip: ClipData) -> void:
	track_clips[track].append(clip)
	track_clips[track].sort()


func remove_clip_from_track(track: int, clip: ClipData) -> void:
	track_clips[track].clips.erase(clip)


# --- Track clip data getters ---

func get_clips_after(track: int, frame_nr: int) -> Array[ClipData]:
	var clips: Array[ClipData] = track_clips[track].clips
	for i: int in clips.size():
		if clips[i].start >= frame_nr:
			return clips.slice(i)
	return []


func get_clip_at_frame(track: int, frame_nr: int) -> ClipData:
	for clip: ClipData in track_clips[track].clips:
		if clip.start == frame_nr:
			return clip
	return null


## Get a clip which is overlapping with frame_nr.
func get_clip_at_overlap(track: int, frame_nr: int) -> ClipData:
	for clip: ClipData in track_clips[track].clips:
		if Utils.in_range(frame_nr, clip.start, clip.end):
			return clip
	return null


## Returns all clip id's that are within range.
func get_clips_in_range(track_id: int, start: int, end: int) -> Array[ClipData]:
	var clips: Array[ClipData] = []
	for clip: ClipData in track_clips[track_id].clips:
		if clip.start > end:
			return clips
		elif clip.end > start and clip.start < end:
			clips.append(clip)
	return clips


## Returns 'x' = free area start, 'y' = free area end.
func get_free_region(track: int, frame_nr: int, ignores: Array[int] = []) -> Vector2i:
	var collision_clip: ClipData = get_clip_at_overlap(track, frame_nr)
	if collision_clip and collision_clip.id not in ignores:
		return Vector2i(-1, -1)

	var region: Vector2i = Vector2i(0, 2147483647)
	for clip: ClipData in track_clips[track].clips:
		if clip.id not in ignores:
			if clip.end <= frame_nr:
				region.x = maxi(region.x, clip.end)
			elif clip.start > frame_nr:
				region.y = mini(region.y, clip.start)
	return region



class TrackClips:
	var clips: Array[ClipData] = []


	func sort() -> void: clips.sort_custom(_sort_track_clips)
	func _sort_track_clips(a: ClipData, b: ClipData) -> bool: return a.start < b.start

	func append(clip: ClipData) -> void: clips.append(clip)
