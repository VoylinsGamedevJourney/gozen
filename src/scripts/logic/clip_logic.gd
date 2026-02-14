class_name ClipLogic
extends RefCounted

signal added(clip: int)
signal deleted(clip: int)
signal selected(clip: int)
signal updated ## Signal for when all clips got updated.


var project_data: ProjectData

var index_map: Dictionary[int, int] = {} ## { clip: index }


# --- Main ---

func _init(data: ProjectData) -> void:
	project_data = data
	_rebuild_map()


func _rebuild_map() -> void:
	index_map.clear()
	for index: int in project_data.clips.size():
		index_map[project_data.clips[index]] = index


## For undo/redo system.
func _create_snapshot(clip_index: int) -> Dictionary:
	return {
		"clip": project_data.clips[clip_index],
		"type": project_data.clips_type[clip_index],
		"file": project_data.clips_file[clip_index],
		"track": project_data.clips_track[clip_index],
		"start": project_data.clips_start[clip_index],
		"begin": project_data.clips_begin[clip_index],
		"duration": project_data.clips_duration[clip_index],
		"effects": project_data.clips_effects[clip_index].duplicate(true)
	}


## For undo/redo system.
func _create_snapshot_from_request(request: ClipRequest) -> Dictionary:
	var file_index: int = Project.files.index_map[request.file]
	var clip: int = Utils.get_unique_id(project_data.clips)
	return {
		"clip": clip,
		"type": project_data.files_type[file_index],
		"file": request.file,
		"track": request.track,
		"start": request.frame,
		"begin": 0,
		"duration": project_data.files_duration[file_index],
		"effects": _create_default_effects(file_index)
	}


## For undo/redo system. (After a clip is cut, we create a new clip behind it)
func _create_snapshot_for_cut(clip_index: int, offset: int, duration_left: int, duration_right: int) -> Dictionary:
	var clip: int = Utils.get_unique_id(project_data.clips)
	var file: int = project_data.clips_file[clip_index]
	var effects: ClipEffects = project_data.clips_effects[clip_index]
	var new_effects: ClipEffects = ClipEffects.new()

	new_effects.video = _copy_visual_effects(effects.video, offset)
	new_effects.audio = _copy_audio_effects(effects.audio, offset)
	new_effects.fade_visual = effects.fade_visual
	new_effects.fade_audio = effects.fade_audio
	new_effects.ato_active = effects.ato_active
	new_effects.ato_offset = effects.ato_offset
	new_effects.ato_id = effects.ato_id

	return {
		"clip": clip,
		"type": project_data.clips_type[clip_index],
		"file": file,
		"track": project_data.clips_track[clip_index],
		"start": project_data.clips_start[clip_index] + duration_left,
		"begin": project_data.clips_begin[clip_index] + duration_left,
		"duration": duration_right,
		"effects": new_effects
	}


# --- Handling ---

func add(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Add new clip(s)")
	for request: ClipRequest in requests:
		var snapshot: Dictionary = _create_snapshot_from_request(request)
		InputManager.undo_redo.add_do_method(_restore_clip_from_snapshot.bind(snapshot))
		InputManager.undo_redo.add_undo_method(_delete.bind(snapshot.clip))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _restore_clip_from_snapshot(snapshot: Dictionary) -> void:
	var clip_index: int = project_data.clips.size()

	project_data.clips.append(snapshot.clip as int)
	project_data.clips_type.append(snapshot.type as int)
	project_data.clips_track.append(snapshot.track as int)
	project_data.clips_file.append(snapshot.file as int)
	project_data.clips_start.append(snapshot.start as int)
	project_data.clips_begin.append(snapshot.begin as int)
	project_data.clips_duration.append(snapshot.duration as int)
	project_data.clips_effects.append(snapshot.effects as ClipEffects)
	index_map[snapshot.clip] = clip_index

	Project.tracks.register_clip(
			snapshot.track as int,
			snapshot.clip as int,
			snapshot.start as int)
	added.emit(snapshot.clip)
	Project.unsaved_changes = true


func delete(clips: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Delete clip_data(s)")
	for clip: int in clips:
		if !index_map.has(clip):
			continue
		var snapshot: Dictionary = _create_snapshot(index_map[clip])
		InputManager.undo_redo.add_do_method(_delete.bind(clip))
		InputManager.undo_redo.add_undo_method(_restore_clip_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _delete(clip: int) -> void:
	if !index_map.has(clip):
		return
	var clip_index: int = index_map[clip]
	var clip_track: int = project_data.clips_track[clip_index]
	var frame_nr: int = project_data.clips_start[clip_index]

	Project.tracks.unregister_clip(clip_track, frame_nr)

	project_data.clips.remove_at(clip_index)
	project_data.clips_type.remove_at(clip_index)
	project_data.clips_file.remove_at(clip_index)
	project_data.clips_track.remove_at(clip_index)
	project_data.clips_start.remove_at(clip_index)
	project_data.clips_begin.remove_at(clip_index)
	project_data.clips_duration.remove_at(clip_index)
	project_data.clips_effects.remove_at(clip_index)

	_rebuild_map()
	deleted.emit(clip)
	updated.emit()
	Project.unsaved_changes = true


func ripple_delete(clips: PackedInt64Array) -> void:
	# Store min start and total duration per track.
	var ranges_by_track: Dictionary[int, Vector2i] = {}

	for clip: int in clips:
		if !index_map.has(clip):
			continue
		var clip_index: int = index_map[clip]
		var clip_track: int = project_data.clips_track[clip_index]
		var clip_start: int = project_data.clips_start[clip_index]
		var clip_end: int = clip_start + project_data.clips_duration[clip_index]

		if not ranges_by_track.has(clip_track):
			ranges_by_track[clip_track] = Vector2i(clip_start, clip_end)
		else:
			ranges_by_track[clip_track].x = mini(ranges_by_track[clip_track].x, clip_start)
			ranges_by_track[clip_track].y = mini(ranges_by_track[clip_track].y, clip_end)

	InputManager.undo_redo.create_action("Ripple delete clip_data(s)")

	# First delete the clips.
	for clip: int in clips:
		if !index_map.has(clip):
			continue
		var snapshot: Dictionary = _create_snapshot(index_map[clip])
		InputManager.undo_redo.add_do_method(_delete.bind(clip))
		InputManager.undo_redo.add_undo_method(_restore_clip_from_snapshot.bind(snapshot))

	# Move remaining clips to fill the gap.
	for track: int in ranges_by_track:
		var gap_range: Vector2i = ranges_by_track[track]
		var gap_start: int = gap_range.x
		var gap_size: int = gap_range.y - gap_range.x

		for move_clip: int in Project.tracks.get_clips_after(track, gap_start):
			if move_clip in clips:
				continue
			var clip_index: int = index_map[move_clip]
			var current_start: int = project_data.clips_start[clip_index]
			var new_start: int = current_start - gap_size

			InputManager.undo_redo.add_do_method(_move.bind(move_clip, track, new_start))
			InputManager.undo_redo.add_undo_method(_move.bind(move_clip, track, current_start))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func move(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Move clip_data(s)")
	for request: ClipRequest in requests:
		var clip: int = request.clip
		if !index_map.has(clip):
			continue
		var clip_index: int = index_map[clip]
		var current_track: int = project_data.clips_track[clip_index]
		var current_start: int = project_data.clips_start[clip_index]
		var new_track: int = current_track + request.track_offset
		var new_start: int = current_start + request.frame_offset

		InputManager.undo_redo.add_do_method(_move.bind(clip, new_track, new_start))
		InputManager.undo_redo.add_undo_method(_move.bind(clip, current_track, current_start))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _move(clip: int, new_track: int, new_frame: int) -> void:
	if !index_map.has(clip):
		return
	var clip_index: int = index_map[clip]
	var old_track: int = project_data.clips_track[clip_index]
	var old_frame: int = project_data.clips_start[clip_index]

	if old_track != new_track:
		Project.tracks.unregister_clip(old_track, old_frame)
		project_data.clips_track[clip_index] = new_track
		project_data.clips_start[clip_index] = new_frame
		Project.tracks.register_clip(new_track, clip, new_frame)
	else:
		project_data.clips_start[clip_index] = new_frame
		Project.tracks.update_clip_info(clip)
	updated.emit()
	Project.unsaved_changes = true


func cut(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Cut clip_data(s)")
	for request: ClipRequest in requests:
		var clip: int = request.clip
		if !index_map.has(clip):
			continue
		var clip_index: int = index_map[clip]
		var cut_offset: int = request.frame
		var current_duration: int = project_data.clips_duration[clip_index]
		var duration_left: int = cut_offset
		var duration_right: int = current_duration - cut_offset
		if duration_left <= 0 or duration_right <= 0:
			continue # Check for invalid cuts.

		# Cutting the main clip.
		InputManager.undo_redo.add_do_method(_resize.bind(clip, -duration_right, true))
		InputManager.undo_redo.add_undo_method(_resize.bind(clip, duration_right, true))

		# Construct the new clip snapshot.
		var snapshot: Dictionary = _create_snapshot_for_cut(clip_index, cut_offset, duration_left, duration_right)
		InputManager.undo_redo.add_do_method(_restore_clip_from_snapshot.bind(snapshot))
		InputManager.undo_redo.add_undo_method(_delete.bind(snapshot.clip))
	InputManager.undo_redo.commit_action()


func resize(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Resize clip_data(s)")
	for request: ClipRequest in requests:
		var clip: int = request.clip
		var clip_index: int = index_map[clip]
		var amount: int = request.resize
		var from_end: int = request.is_end
		var current_start: int = project_data.clips_start[clip_index]
		var current_duration: int = project_data.clips_duration[clip_index]
		var current_begin: int = project_data.clips_begin[clip_index]

		InputManager.undo_redo.add_do_method(_resize.bind(clip, amount, from_end))
		InputManager.undo_redo.add_undo_method(_resize_restore.bind(clip, current_start, current_duration, current_begin))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _resize(clip: int, amount: int, from_end: bool) -> void:
	var clip_index: int = index_map[clip]
	if from_end:
		project_data.clips_duration[clip_index] += amount
		updated.emit()
		return

	var track: int = project_data.clips_track[clip_index]
	var old_start: int = project_data.clips_start[clip_index]
	var new_start: int = old_start + amount

	project_data.clips_start[clip_index] = new_start
	project_data.clips_begin[clip_index] += amount
	project_data.clips_duration[clip_index] -= amount

	Project.tracks.unregister_clip(track, old_start)
	Project.tracks.register_clip(track, clip, new_start)
	updated.emit()


func _resize_restore(clip: int, start: int, duration: int, begin: int) -> void:
	var clip_index: int = index_map[clip]
	var track: int = project_data.clips_track[clip_index]
	var old_start_pos: int = project_data.clips_start[clip_index]

	project_data.clips_start[clip_index] = start
	project_data.clips_begin[clip_index] = begin
	project_data.clips_duration[clip_index] = duration

	if old_start_pos != start:
		Project.tracks.unregister_clip(track, old_start_pos)
		Project.tracks.register_clip(track, clip, start)
	updated.emit()


## This function is intended to be used when cutting clips to copy over the effects.
func _copy_visual_effects(effects: Array[GoZenEffectVisual], cut_pos: int) -> Array[GoZenEffectVisual]:
	var new_effects: Array[GoZenEffectVisual] = []
	for effect: GoZenEffectVisual in effects:
		var new_effect: GoZenEffectVisual = effect.duplicate(true)
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
func _copy_audio_effects(effects: Array[GoZenEffectAudio], cut_pos: int) -> Array[GoZenEffectAudio]:
	var new_effects: Array[GoZenEffectAudio] = []
	for effect: GoZenEffectAudio in effects:
		var new_effect: GoZenEffectAudio = effect.duplicate(true)
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


# --- Playback helpers ---

func load_frame(clip: int, frame_nr: int) -> void:
	if !index_map.has(clip):
		return
	var clip_index: int = index_map[clip]
	var clip_type: EditorCore.TYPE = project_data.clips_type[clip_index] as EditorCore.TYPE
	var file_index: int = project_data.files.find(project_data.clips_file[clip_index])
	var video: GoZenVideo = null

	if clip_type not in EditorCore.VISUAL_TYPES:
		return
	elif clip_type == EditorCore.TYPE.VIDEO:
		if project_data.clips_individual_video.has(clip):
			video = Project.files.clip_video_instances[clip]
		else:
			var temp: Variant = Project.files.get_data(file_index)
			if temp is GoZenVideo:
				video = temp
	if video == null:
		return # Probably still loading.

	var project_fps: float = project_data.framerate
	var video_fps: float = video.get_framerate()
	var video_frame_nr: int = video.get_current_frame()
	var target_frame_nr: int = int((frame_nr / project_fps) * video_fps)

	if target_frame_nr != video_frame_nr: # Shouldn't reload same frame
		if target_frame_nr == video_frame_nr + 1:
			video.next_frame(false)
		elif !video.seek_frame(target_frame_nr):
			printerr("Project.clips: Couldn't seek frame!")


func get_audio_data(clip: int) -> PackedByteArray:
	if !index_map.has(clip):
		return PackedByteArray()

	var index: int = index_map[clip]
	var framerate: float = project_data.framerate
	var begin: int = project_data.clips_begin[index]
	var duration: int = project_data.clips_duration[index]
	var start_sec: float = begin / framerate
	var duration_sec: float = float(duration) / framerate

	var effects: ClipEffects = project_data.clips_effects[index]
	var target_file_id: int = -1

	# Get the correct file to use for audio.
	if effects.ato_active and effects.ato_id != -1:
		start_sec -= effects.ato_offset
		target_file_id -= effects.ato_id
	else:
		target_file_id = project_data.clips_file[index]

	if !project_data.files.has(target_file_id):
		printerr("ClipLogic: Audio source %s not found for clip %s!" % [target_file_id, clip])
		return PackedByteArray()

	var file_index: int = Project.data.files.find(target_file_id)
	var file_path: String = Project.data.files_path[file_index]
	return GoZenAudio.get_audio_data(file_path, -1, start_sec, duration_sec)


# --- Setters ---

func switch_ato_active(clip: int) -> void:
	set_ato_active(clip, project_data.clips_effects[index_map[clip]].ato_active)


func set_ato_active(clip: int, value: bool) -> void:
	if value:
		InputManager.undo_redo.create_action("Enable clip audio take over")
	else:
		InputManager.undo_redo.create_action("Disable clip audio take over")
	InputManager.undo_redo.add_do_method(_set_ato_active.bind(clip, value))
	InputManager.undo_redo.add_undo_method(_set_ato_active.bind(clip, !value))
	InputManager.undo_redo.commit_action()


func _set_ato_active(clip: int, value: bool) -> void:
	project_data.clips_effects[index_map[clip]].ato_active = value
	Project.unsaved_changes = true


# --- Helpers ---

func _create_default_effects(file_index: int) -> ClipEffects:
	var type: EditorCore.TYPE = project_data.files_type[file_index] as EditorCore.TYPE
	var effects: ClipEffects = ClipEffects.new()

	if type in EditorCore.VISUAL_TYPES:
		var resolution: Vector2i = Project.get_resolution()

		var transform_effect: GoZenEffectVisual = load(Library.EFFECT_VISUAL_TRANSFORM).duplicate(true)
		for param: EffectParam in transform_effect.params:
			if param.id == "size":
				param.default_value = resolution
			elif param.id == "pivot":
				param.default_value = Vector2i(resolution / 2.0)
		transform_effect.set_default_keyframe()
		effects.video.append(transform_effect)

	if type in EditorCore.AUDIO_TYPES:
		var volume_effect: GoZenEffectAudio = load(Library.EFFECT_AUDIO_VOLUME).duplicate(true)
		volume_effect.set_default_keyframe()
		effects.audio.append(volume_effect)
	return effects
