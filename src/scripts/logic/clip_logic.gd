extends Node

signal added(clip: ClipData)
signal deleted(clip_id: int)
signal selected(clip: ClipData)
signal updated ## Signal for when all clips got updated.


var clips: Dictionary[int, ClipData]



# --- Handling ---

func add(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Add new clip(s)")
	var existing_keys: Array[int] = clips.keys()
	for request: ClipRequest in requests:
		var new_clip: ClipData = ClipData.new()
		new_clip.id = Utils.get_unique_id(existing_keys)
		new_clip.type = FileLogic.files[request.file.id].type
		new_clip.file = request.file.id
		new_clip.track = request.track
		new_clip.start = request.frame
		new_clip.duration = FileLogic.files[request.file.id].duration
		new_clip.effects = _create_default_effects(new_clip.type)
		InputManager.undo_redo.add_do_method(_restore_clip.bind(new_clip))
		InputManager.undo_redo.add_undo_method(_delete.bind(new_clip))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _restore_clip(snapshot: ClipData) -> void:
	clips[snapshot.id] = snapshot
	TrackLogic.add_clip_to_track(snapshot.track, snapshot)
	Project.unsaved_changes = true
	added.emit(snapshot)
	updated.emit()


func delete(clips_to_delete: Array[ClipData]) -> void:
	InputManager.undo_redo.create_action("Delete clip_data(s)")
	for clip: ClipData in clips_to_delete:
		InputManager.undo_redo.add_do_method(_delete.bind(clip))
		InputManager.undo_redo.add_undo_method(_restore_clip.bind(clip))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _delete(clip: ClipData) -> void:
	TrackLogic.remove_clip_from_track(clip.track, clip)
	clips.erase(clip.id)
	Project.unsaved_changes = true
	deleted.emit(clip.id)
	updated.emit()


func ripple_delete(clips_to_delete: Array[ClipData]) -> void:
	# Store min start and total duration per track.
	var ranges_by_track: Dictionary[int, Vector2i] = {}

	for clip: ClipData in clips_to_delete:
		if not ranges_by_track.has(clip.track):
			ranges_by_track[clip.track] = Vector2i(clip.start, clip.end)
		else:
			ranges_by_track[clip.track].x = mini(ranges_by_track[clip.track].x, clip.start)
			ranges_by_track[clip.track].y = maxi(ranges_by_track[clip.track].y, clip.end)

	InputManager.undo_redo.create_action("Ripple delete clip_data(s)")
	for clip: ClipData in clips_to_delete: # First delete the clips.
		InputManager.undo_redo.add_do_method(_delete.bind(clip))
		InputManager.undo_redo.add_undo_method(_restore_clip.bind(clip))

	for track: int in ranges_by_track: # Move remaining clips to fill the gap.
		var gap_range: Vector2i = ranges_by_track[track]
		var gap_start: int = gap_range.x
		var gap_size: int = gap_range.y - gap_range.x

		for move_clip: ClipData in TrackLogic.get_clips_after(track, gap_start):
			if move_clip not in clips_to_delete:
				InputManager.undo_redo.add_do_method(_move.bind(
						move_clip, track, move_clip.start - gap_size))
				InputManager.undo_redo.add_undo_method(_move.bind(
						move_clip, track, move_clip.start))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func move(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Move clip_data(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		var new_track: int = clip.track + request.track_offset
		var new_start: int = clip.start + request.frame_offset
		InputManager.undo_redo.add_do_method(_move.bind(clip, new_track, new_start))
		InputManager.undo_redo.add_undo_method(_move.bind(clip, clip.track, clip.start))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _move(clip: ClipData, new_track: int, new_frame: int) -> void:
	TrackLogic.remove_clip_from_track(clip.track, clip)
	clip.start = new_frame
	clip.track = new_track
	TrackLogic.add_clip_to_track(new_track, clip)
	Project.unsaved_changes = true
	updated.emit()


func cut(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Cut clip_data(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		var cut_offset: int = request.frame
		var duration_left: int = cut_offset
		var duration_right: int = clip.duration - cut_offset
		if duration_left <= 0 or duration_right <= 0:
			continue # Check for invalid cuts.

		# Cutting the main clip.
		InputManager.undo_redo.add_do_method(_resize.bind(clip, -duration_right, true))
		InputManager.undo_redo.add_undo_method(_resize.bind(clip, duration_right, true))

		# Construct the new clip snapshot.
		var snapshot: ClipData = request.clip.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		var effects: ClipEffects = snapshot.effects
		snapshot.id = Utils.get_unique_id(clips.keys())
		snapshot.start += duration_left
		snapshot.begin += duration_left
		snapshot.duration = duration_right
		effects.video = _copy_visual_effects(effects.video, cut_offset)
		effects.audio = _copy_audio_effects(effects.audio, cut_offset)
		InputManager.undo_redo.add_do_method(_restore_clip.bind(snapshot))
		InputManager.undo_redo.add_undo_method(_delete.bind(snapshot))
	InputManager.undo_redo.commit_action()


func resize(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Resize clip_data(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		InputManager.undo_redo.add_do_method(_resize.bind(
				clip, request.resize, request.is_end))
		InputManager.undo_redo.add_undo_method(_resize_restore.bind(
				clip, clip.start, clip.duration, clip.begin))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _resize(clip: ClipData, amount: int, from_end: bool) -> void:
	if from_end:
		clip.duration += amount
	else:
		clip.start += amount
		clip.begin += amount
		clip.duration -= amount
	Project.unsaved_changes = true
	updated.emit()


func _resize_restore(clip: ClipData, start: int, duration: int, begin: int) -> void:
	clip.start = start
	clip.begin = begin
	clip.duration = duration
	Project.unsaved_changes = true
	updated.emit()


#---- Helper functions ----

## This function is intended to be used when cutting clips to copy over the effects.
func _copy_visual_effects(effects: Array[EffectVisual], cut_pos: int) -> Array[EffectVisual]:
	var new_effects: Array[EffectVisual] = []
	for effect: EffectVisual in effects:
		var new_effect: EffectVisual = effect.duplicate(true)
		new_effect.keyframes = {}
		new_effect._cache_dirty = true

		for param: EffectParam in new_effect.params:
			var param_id: String = param.id
			var value_at_cut: Variant = effect.get_value(param, cut_pos)

			if not new_effect.keyframes.has(param_id):
				new_effect.keyframes[param_id] = {}
			new_effect.keyframes[param_id][0] = value_at_cut

			# Shift existing keyframes that appear after the cut.
			for frame: int in effect.keyframes[param_id]:
				if frame > cut_pos:
					new_effect.keyframes[param_id][frame - cut_pos] = effect.keyframes[param_id][frame]
		new_effects.append(new_effect)
	return new_effects


## This function is intended to be used when cutting clips to copy over the effects.
func _copy_audio_effects(effects: Array[EffectAudio], cut_pos: int) -> Array[EffectAudio]:
	var new_effects: Array[EffectAudio] = []
	for effect: EffectAudio in effects:
		var new_effect: EffectAudio = effect.duplicate(true)
		new_effect.keyframes = {}
		new_effect._cache_dirty = true

		for param: EffectParam in new_effect.params:
			var param_id: String = param.id
			var value_at_cut: Variant = effect.get_value(param, cut_pos)

			if not new_effect.keyframes.has(param_id):
				new_effect.keyframes[param_id] = {}
			new_effect.keyframes[param_id][0] = value_at_cut

			# Shift existing keyframes that appear after the cut.
			for frame: int in effect.keyframes[param_id]:
				if frame <= cut_pos:
					continue
				new_effect.keyframes[param_id][frame - cut_pos] = effect.keyframes[param_id][frame]
			new_effects.append(new_effect)
	return new_effects


func apply_audio_take_over(clip: ClipData, audio_file: int, offset: float) -> void:
	var effects: ClipEffects = clip.effects
	var active: bool = audio_file != -1
	InputManager.undo_redo.create_action("Set clip Audio-Take-Over")
	InputManager.undo_redo.add_do_method(_apply_audio_take_over.bind(clip, active, audio_file, offset))
	InputManager.undo_redo.add_undo_method(_apply_audio_take_over.bind(clip, effects.ato_active, effects.ato_file, effects.ato_offset))
	InputManager.undo_redo.commit_action()


func _apply_audio_take_over(clip: ClipData, active: bool, audio_file_id: int, offset: float) -> void:
	var effects: ClipEffects = clip.effects
	effects.ato_active = active
	effects.ato_file = audio_file_id
	effects.ato_offset = offset
	Project.unsaved_changes = true
	updated.emit()


func change_speed(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Change speed clip(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		var amount: int = request.resize
		var from_end: int = request.is_end
		var new_duration: int = maxi(clip.duration + (amount if from_end else -amount), 1)
		var new_speed: float = (clip.duration * clip.speed) / float(new_duration)

		InputManager.undo_redo.add_do_method(_change_speed.bind(
				clip, amount, from_end, new_speed))
		InputManager.undo_redo.add_undo_method(_change_speed_restore.bind(
				clip, clip.start, clip.duration, clip.speed))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _change_speed(clip: ClipData, amount: int, from_end: bool, new_speed: float) -> void:
	clip.speed = new_speed
	if from_end:
		clip.duration += amount
	else:
		clip.start += amount
		clip.duration -= amount
	updated.emit()


func _change_speed_restore(clip: ClipData, start: int, duration: int, speed: float) -> void:
	clip.start = start
	clip.speed = speed
	clip.duration = duration
	updated.emit()


# --- Playback helpers ---

func load_video_frame(clip: ClipData, frame_nr: int, instance_index: int = 0) -> void:
	if clip and clip.type == EditorCore.TYPE.VIDEO:
		var file: FileData = FileLogic.files[clip.file]
		var video: Video = FileLogic.get_video_reader(file, instance_index)
		if video == null:
			return # Probably still loading.

		var project_fps: float = Project.data.framerate
		var video_fps: float = video.get_framerate()
		var video_frame_nr: int = video.get_current_frame()
		var target_frame_nr: int = roundi((float(frame_nr) / project_fps) * video_fps)
		if target_frame_nr != video_frame_nr: # Shouldn't reload same frame
			var frame_diff: int = target_frame_nr - video_frame_nr
			if frame_diff > 0 and frame_diff <= 40:
				# Small forward jump is much faster via next_frame.
				for i: int in frame_diff:
					if !video.next_frame(i < frame_diff - 1):
						break
			elif !video.seek_frame(target_frame_nr):
				printerr("Project.clips: Couldn't seek frame!")


func get_audio_data(clip: ClipData) -> PackedByteArray:
	var framerate: float = Project.data.framerate
	var start_sec: float = clip.begin / framerate
	var duration_sec: float = clip.duration / framerate
	var file_path: String

	# Get the correct file to use for audio.
	if clip.effects.ato_active and clip.effects.ato_file != -1:
		start_sec -= clip.effects.ato_offset
		file_path = FileLogic.files[clip.effects.ato_file].path
	else:
		file_path = FileLogic.files[clip.file].path
	return Audio.get_audio_data(file_path, -1, start_sec, duration_sec)


# --- Setters ---

func switch_ato_active(clip: ClipData) -> void:
	set_ato_active(clip, clip.effects.ato_active)


func set_ato_active(clip: ClipData, value: bool) -> void:
	if value:
		InputManager.undo_redo.create_action("Enable clip audio take over")
	else:
		InputManager.undo_redo.create_action("Disable clip audio take over")
	InputManager.undo_redo.add_do_method(_set_ato_active.bind(clip.effects, value))
	InputManager.undo_redo.add_undo_method(_set_ato_active.bind(clip.effects, !value))
	InputManager.undo_redo.commit_action()


func _set_ato_active(effects: ClipEffects, value: bool) -> void:
	effects.ato_active = value
	Project.unsaved_changes = true


# --- Helpers ---

func _create_default_effects(file_type: EditorCore.TYPE) -> ClipEffects:
	var effects: ClipEffects = ClipEffects.new()

	if file_type in EditorCore.VISUAL_TYPES:
		var resolution: Vector2i = Project.get_resolution()
		var transform_effect: EffectVisual = load(Library.EFFECT_VISUAL_TRANSFORM).duplicate(true)
		for param: EffectParam in transform_effect.params:
			if param.id == "pivot":
				param.default_value = Vector2i(resolution / 2.0)
		transform_effect.set_default_keyframe()
		effects.video.append(transform_effect)

	if file_type in EditorCore.AUDIO_TYPES:
		var volume_effect: EffectAudio = load(Library.EFFECT_AUDIO_VOLUME).duplicate(true)
		volume_effect.set_default_keyframe()
		effects.audio.append(volume_effect)
	return effects
