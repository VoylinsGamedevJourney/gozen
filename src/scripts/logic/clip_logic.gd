extends Node

signal added(clip: ClipData)
signal deleted(clip_id: int)
signal selected(clip: ClipData)
signal updated ## Signal for when all clips got updated.


var clips: Dictionary[int, ClipData] = {}
var selected_clips: Array[ClipData] = []

var copied_clips: Array[ClipData] = []
var copied_min_start: int = 0
var copied_min_track: int = 0



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
	InputManager.undo_redo.commit_action()


func _restore_clip(snapshot: ClipData) -> void:
	clips[snapshot.id] = snapshot
	TrackLogic.add_clip_to_track(snapshot.track, snapshot)
	Project.unsaved_changes = true
	Project.update_timeline_end.call_deferred()
	added.emit(snapshot)
	updated.emit.call_deferred()


func delete(clips_to_delete: Array[ClipData]) -> void:
	InputManager.undo_redo.create_action("Delete clip_data(s)")
	for clip: ClipData in clips_to_delete:
		InputManager.undo_redo.add_do_method(_delete.bind(clip))
		InputManager.undo_redo.add_undo_method(_restore_clip.bind(clip))
	InputManager.undo_redo.commit_action()


func _delete(clip: ClipData) -> void:
	TrackLogic.remove_clip_from_track(clip.track, clip)
	clips.erase(clip.id)
	selected_clips.erase(clip)
	Project.unsaved_changes = true
	Project.update_timeline_end.call_deferred()
	deleted.emit(clip.id)
	updated.emit.call_deferred()


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
	InputManager.undo_redo.commit_action()


func move(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Move clip_data(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		var new_track: int = clip.track + request.track_offset
		var new_start: int = clip.start + request.frame_offset
		InputManager.undo_redo.add_do_method(_move.bind(clip, new_track, new_start))
		InputManager.undo_redo.add_undo_method(_move.bind(clip, clip.track, clip.start))
	InputManager.undo_redo.commit_action()


func _move(clip: ClipData, new_track: int, new_frame: int) -> void:
	TrackLogic.remove_clip_from_track(clip.track, clip)
	clip.start = new_frame
	clip.track = new_track
	TrackLogic.add_clip_to_track(new_track, clip)
	Project.unsaved_changes = true
	Project.update_timeline_end.call_deferred()
	updated.emit.call_deferred()


func split(requests: Array[ClipRequest]) -> Array[ClipData]:
	var new_clips: Array[ClipData] = []
	InputManager.undo_redo.create_action("Split clip_data(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		var split_offset: int = request.frame
		var duration_left: int = split_offset
		var duration_right: int = clip.duration - split_offset
		if duration_left <= 0 or duration_right <= 0:
			continue # Check for invalid splits.

		# Splitting the main clip.
		InputManager.undo_redo.add_do_method(_resize_and_fade.bind(clip, -duration_right, true, clip.effects.fade_visual.x, 0, clip.effects.fade_audio.x, 0))
		InputManager.undo_redo.add_undo_method(_resize_and_fade.bind(clip, duration_right, true, clip.effects.fade_visual.x, clip.effects.fade_visual.y, clip.effects.fade_audio.x, clip.effects.fade_audio.y))

		# Construct the new clip snapshot.
		var snapshot: ClipData = request.clip.duplicate(true)
		var effects: ClipEffects = snapshot.effects

		# Reset fade-in on the new right-hand clip.
		effects.fade_visual = Vector2i(0, request.clip.effects.fade_visual.y)
		effects.fade_audio = Vector2i(0, request.clip.effects.fade_audio.y)

		effects.ato_active = request.clip.effects.ato_active
		effects.ato_offset = request.clip.effects.ato_offset
		effects.ato_file = request.clip.effects.ato_file
		effects.is_muted = request.clip.effects.is_muted
		snapshot.id = Utils.get_unique_id(clips.keys())
		snapshot.start += duration_left
		snapshot.begin += int(duration_left * request.clip.speed)
		snapshot.duration = duration_right
		effects.video = _copy_visual_effects(request.clip.effects.video, split_offset)
		effects.audio = _copy_audio_effects(request.clip.effects.audio, split_offset)
		InputManager.undo_redo.add_do_method(_restore_clip.bind(snapshot))
		InputManager.undo_redo.add_undo_method(_delete.bind(snapshot))

		new_clips.append(snapshot)
	InputManager.undo_redo.commit_action()
	return new_clips


func resize(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Resize clip_data(s)")
	for request: ClipRequest in requests:
		var clip: ClipData = request.clip
		InputManager.undo_redo.add_do_method(_resize.bind(
				clip, request.resize, request.is_end))
		InputManager.undo_redo.add_undo_method(_resize_restore.bind(
				clip, clip.start, clip.duration, clip.begin))
	InputManager.undo_redo.commit_action()


func _resize(clip: ClipData, amount: int, from_end: bool) -> void:
	if from_end:
		clip.duration += amount
	else:
		clip.start += amount
		clip.begin += int(amount * clip.speed)
		clip.duration -= amount
	Project.unsaved_changes = true
	Project.update_timeline_end.call_deferred()
	updated.emit.call_deferred()


func _resize_and_fade(clip: ClipData, amount: int, from_end: bool, v_fade_in: int, v_fade_out: int, a_fade_in: int, a_fade_out: int) -> void:
	_resize(clip, amount, from_end)
	clip.effects.fade_visual = Vector2i(v_fade_in, v_fade_out)
	clip.effects.fade_audio = Vector2i(a_fade_in, a_fade_out)


func _resize_restore(clip: ClipData, start: int, duration: int, begin: int) -> void:
	clip.start = start
	clip.begin = begin
	clip.duration = duration
	Project.unsaved_changes = true
	Project.update_timeline_end.call_deferred()
	updated.emit.call_deferred()


func copy_selected_clips() -> void:
	copied_clips.clear()
	if selected_clips.is_empty():
		return

	# 32 bit max.
	copied_min_start = Utils.INT_32_MAX
	copied_min_track = Utils.INT_32_MAX
	for clip: ClipData in selected_clips:
		var snapshot: ClipData = clip.duplicate(true)
		snapshot.effects = ClipEffects.new()
		snapshot.effects.fade_visual = clip.effects.fade_visual
		snapshot.effects.fade_audio = clip.effects.fade_audio
		snapshot.effects.ato_active = clip.effects.ato_active
		snapshot.effects.ato_offset = clip.effects.ato_offset
		snapshot.effects.ato_file = clip.effects.ato_file
		snapshot.effects.is_muted = clip.effects.is_muted
		snapshot.effects.video = _copy_visual_effects(clip.effects.video, 0)
		snapshot.effects.audio = _copy_audio_effects(clip.effects.audio, 0)
		copied_clips.append(snapshot)

		if clip.start < copied_min_start:
			copied_min_start = clip.start
		if clip.track < copied_min_track:
			copied_min_track = clip.track


## Cut as in Ctrl+X.
func cut_selected_clips() -> void:
	copy_selected_clips()
	delete(selected_clips)


func paste_copied_clips() -> void:
	if copied_clips.is_empty():
		return

	var target_frame: int = EditorCore.frame_nr
	var clips_to_paste: Array[ClipData] = []
	var existing_keys: Array[int] = clips.keys()

	for copied_clip: ClipData in copied_clips:
		var new_clip: ClipData = copied_clip.duplicate(true)
		new_clip.effects = ClipEffects.new()
		new_clip.effects.fade_visual = copied_clip.effects.fade_visual
		new_clip.effects.fade_audio = copied_clip.effects.fade_audio
		new_clip.effects.ato_active = copied_clip.effects.ato_active
		new_clip.effects.ato_offset = copied_clip.effects.ato_offset
		new_clip.effects.ato_file = copied_clip.effects.ato_file
		new_clip.effects.is_muted = copied_clip.effects.is_muted
		new_clip.effects.video = _copy_visual_effects(copied_clip.effects.video, 0)
		new_clip.effects.audio = _copy_audio_effects(copied_clip.effects.audio, 0)

		var relative_start: int = copied_clip.start - copied_min_start
		new_clip.start = target_frame + relative_start
		new_clip.id = Utils.get_unique_id(existing_keys)
		existing_keys.append(new_clip.id)
		clips_to_paste.append(new_clip)
	insert_clips(clips_to_paste, "Paste clip(s)")


func insert_clips(clips_to_insert: Array[ClipData], action_name: String) -> void:
	InputManager.undo_redo.create_action(action_name)
	var new_selected: Array[ClipData] = []
	for clip: ClipData in clips_to_insert:
		InputManager.undo_redo.add_do_method(_restore_clip.bind(clip))
		InputManager.undo_redo.add_undo_method(_delete.bind(clip))
		new_selected.append(clip)
	InputManager.undo_redo.commit_action()

	selected_clips = new_selected
	if new_selected.size() > 0:
		selected.emit(selected_clips[-1])


func duplicate_clips(clips_to_duplicate: Array[ClipData]) -> int:
	if clips_to_duplicate.is_empty():
		return 0

	var new_clips: Array[ClipData] = []
	var failed_duplicates: int = 0
	var existing_keys: Array[int] = clips.keys()

	for clip: ClipData in clips_to_duplicate:
		if !clip:
			continue
		var target_frame: int = clip.end
		var free_region: Vector2i = TrackLogic.get_free_region(clip.track, target_frame)
		if free_region.y - target_frame >= clip.duration:
			var new_clip: ClipData = clip.duplicate(true)
			new_clip.effects = ClipEffects.new()
			new_clip.effects.fade_visual = clip.effects.fade_visual
			new_clip.effects.fade_audio = clip.effects.fade_audio
			new_clip.effects.ato_active = clip.effects.ato_active
			new_clip.effects.ato_offset = clip.effects.ato_offset
			new_clip.effects.ato_file = clip.effects.ato_file
			new_clip.effects.is_muted = clip.effects.is_muted
			new_clip.effects.video = _copy_visual_effects(clip.effects.video, 0)
			new_clip.effects.audio = _copy_audio_effects(clip.effects.audio, 0)
			new_clip.start = target_frame
			new_clip.id = Utils.get_unique_id(existing_keys)

			existing_keys.append(new_clip.id)
			new_clips.append(new_clip)
		else:
			failed_duplicates += 1

	if not new_clips.is_empty():
		insert_clips(new_clips, "Duplicate clip(s)")
	return failed_duplicates


#---- Helper functions ----

## This function is intended to be used when splitting clips to copy over the effects.
func _copy_visual_effects(effects: Array[EffectVisual], split_pos: int) -> Array[EffectVisual]:
	var new_effects: Array[EffectVisual] = []
	for effect: EffectVisual in effects:
		var new_effect: EffectVisual = effect.deep_copy()
		new_effect.keyframes = {}
		new_effect._cache_dirty = true

		for param: EffectParam in new_effect.params:
			var param_id: String = param.id
			var value_at_split: Variant = effect.get_value(param, split_pos)

			if not new_effect.keyframes.has(param_id):
				new_effect.keyframes[param_id] = {}
			new_effect.keyframes[param_id][0] = value_at_split

			# Shift existing keyframes that appear after the split.
			for frame: int in effect.keyframes[param_id]:
				if frame > split_pos:
					new_effect.keyframes[param_id][frame - split_pos] = effect.keyframes[param_id][frame]
		new_effects.append(new_effect)
	return new_effects


## This function is intended to be used when splitting clips to copy over the effects.
func _copy_audio_effects(effects: Array[EffectAudio], split_pos: int) -> Array[EffectAudio]:
	var new_effects: Array[EffectAudio] = []
	for effect: EffectAudio in effects:
		var new_effect: EffectAudio = effect.deep_copy()
		new_effect.keyframes = {}
		new_effect._cache_dirty = true

		for param: EffectParam in new_effect.params:
			var param_id: String = param.id
			var value_at_split: Variant = effect.get_value(param, split_pos)

			if not new_effect.keyframes.has(param_id):
				new_effect.keyframes[param_id] = {}
			new_effect.keyframes[param_id][0] = value_at_split

			# Shift existing keyframes that appear after the split.
			for frame: int in effect.keyframes[param_id]:
				if frame <= split_pos:
					continue
				new_effect.keyframes[param_id][frame - split_pos] = effect.keyframes[param_id][frame]
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
	Project.update_timeline_end.call_deferred()
	updated.emit.call_deferred()


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
	InputManager.undo_redo.commit_action()


func _change_speed(clip: ClipData, amount: int, from_end: bool, new_speed: float) -> void:
	clip.speed = new_speed
	if from_end:
		clip.duration += amount
	else:
		clip.start += amount
		clip.duration -= amount
	Project.update_timeline_end.call_deferred()
	updated.emit.call_deferred()


func _change_speed_restore(clip: ClipData, start: int, duration: int, speed: float) -> void:
	clip.start = start
	clip.speed = speed
	clip.duration = duration
	Project.update_timeline_end.call_deferred()
	updated.emit.call_deferred()


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


func toggle_clip_mute(clip: ClipData, muted: bool) -> void:
	InputManager.undo_redo.create_action("Mute clip" if muted else "Unmute clip")
	InputManager.undo_redo.add_do_method(_set_clip_mute.bind(clip.effects, muted))
	InputManager.undo_redo.add_undo_method(_set_clip_mute.bind(clip.effects, !muted))
	InputManager.undo_redo.commit_action()


func _set_clip_mute(effects: ClipEffects, muted: bool) -> void:
	effects.is_muted = muted
	Project.unsaved_changes = true
	updated.emit.call_deferred()


# --- Helpers ---

func _create_default_effects(file_type: EditorCore.TYPE) -> ClipEffects:
	var effects: ClipEffects = ClipEffects.new()
	if file_type in EditorCore.VISUAL_TYPES:
		var resolution: Vector2i = Project.get_resolution()
		var transform_effect: EffectVisual = (load(Library.EFFECT_VISUAL_TRANSFORM) as EffectVisual).deep_copy()
		for param: EffectParam in transform_effect.params:
			if param.id == "pivot":
				param.default_value = Vector2i(resolution / 2.0)
		transform_effect.set_default_keyframe()
		effects.video.append(transform_effect)

	if file_type in EditorCore.AUDIO_TYPES:
		var volume_effect: EffectAudio = (load(Library.EFFECT_AUDIO_VOLUME) as EffectAudio).deep_copy()
		volume_effect.set_default_keyframe()
		effects.audio.append(volume_effect)
	return effects
