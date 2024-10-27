extends Node


signal _on_request_update_frame

signal _on_track_added
signal _on_track_removed(id: int)

signal _open_clip_effects(id: int)



var selected_clips: PackedInt64Array = []



#------------------------------------------------ TRACK HANDLING
func add_track() -> void:
	Project._add_track()
	_on_track_added.emit()


func remove_track(a_id: int) -> void:
	Project._remove_track(a_id)
	_on_track_removed.emit(a_id)


#------------------------------------------------ CLIP HANDLING
func add_clip(a_file_id: int, a_pts: int, a_track_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._add_clip(a_file_id, a_pts, a_track_id)


func remove_clip(a_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._remove_clip(a_id)


func resize_clip(a_id: int, a_duration: int, a_left: bool) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._resize_clip(a_id, a_duration, a_left)


func open_clip_effects(a_id: int) -> void:
	_open_clip_effects.emit(a_id)


#------------------------------------------------ PLAYBACK HANDLING
func set_playhead_pos(a_frame: int) -> void:
	CoreView.set_playhead_pos(a_frame)


func play_pressed() -> void:
	CoreView._on_play_pressed()


#------------------------------------------------ CALCULATIONS
func pos_to_frame(a_pos: float, a_zoom: float) -> int:
	return floor(a_pos / a_zoom)


func frame_to_pos(a_frame_nr: int, a_zoom: float) -> float:
	return a_frame_nr * a_zoom


func check_clip_fit(a_track: int, a_duration: int, a_pts: int, a_excluded_clip: int = -1) -> bool:
	if Project.tracks[a_track].size() == 0:
		return true

	var l_range: PackedInt64Array = range(a_pts, a_pts + a_duration)
	var l_prev_pts: int = -1

	for l_track_pts: int in Project.tracks[a_track].keys():
		if l_track_pts <= a_pts:
			l_prev_pts = l_track_pts
		elif l_track_pts in l_range:
			if a_excluded_clip == -1 or l_track_pts != Project.get_clip_pts(a_excluded_clip):
				return false
		elif l_track_pts > a_pts + a_duration + 1: # Adding a frame just in case
			break

	if l_prev_pts != -1:
		var l_track_clip: ClipData = Project.clips[Project.tracks[a_track][l_prev_pts]]

		for l_pts: int in range(l_track_clip.pts, l_track_clip.pts + l_track_clip.duration):
			if l_pts in l_range:
				return false

	return true
