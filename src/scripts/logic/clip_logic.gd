class_name ClipLogic
extends RefCounted

signal added(clip_id: int)
signal deleted(clip_id: int)
signal selected(clip_id: int)
signal updated ## Signal for when all clips got updated.


var project_data: ProjectData

var index_map: Dictionary[int, int] = {} ## { clip_id: index }


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
		"id": project_data.clips[clip_index],
		"type": project_data.clips_type[clip_index],
		"track": project_data.clips_track[clip_index],
		"file_id": project_data.clips_file[clip_index],
		"start": project_data.clips_start[clip_index],
		"begin": project_data.clips_begin[clip_index],
		"duration": project_data.clips_duration[clip_index],
		"effects": project_data.clips_effects[clip_index].duplicate(true)
	}


## For undo/redo system.
func _create_snapshot_from_request(request: ClipRequest) -> Dictionary:
	var file_index: int = Project.files.index_map[request.file]
	var clip_id: int = Utils.get_unique_id(project_data.clips)
	return {
		"id": clip_id,
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
	var id: int = Utils.get_unique_id(project_data.clips)
	var file_id: int = project_data.clips_file[clip_index]
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
		"id": id,
		"type": project_data.clips_type[clip_index],
		"track": project_data.clips_track[clip_index],
		"file_id": file_id,
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
		InputManager.undo_redo.add_undo_method(_delete.bind(snapshot.id))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _restore_clip_from_snapshot(snapshot: Dictionary) -> void:
	var clip_index: int = project_data.clips.size()

	project_data.clips.append(snapshot.id as int)
	project_data.clips_type.append(snapshot.type as int)
	project_data.clips_track.append(snapshot.track as int)
	project_data.clips_file.append(snapshot.file as int)
	project_data.clips_start.append(snapshot.start as int)
	project_data.clips_begin.append(snapshot.begin as int)
	project_data.clips_duration.append(snapshot.duration as int)
	project_data.clips_effects.append(snapshot.effects as ClipEffects)
	index_map[snapshot.id] = clip_index

	Project.tracks.register_clip(
			snapshot.track as int,
			snapshot.id as int,
			snapshot.start as int)
	added.emit(snapshot.id)
	Project.unsaved_changes = true


func delete(clip_ids: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Delete clip_data(s)")
	for clip_id: int in clip_ids:
		if !index_map.has(clip_id):
			continue
		var snapshot: Dictionary = _create_snapshot(index_map[clip_id])
		InputManager.undo_redo.add_do_method(_delete.bind(clip_id))
		InputManager.undo_redo.add_undo_method(_restore_clip_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _delete(clip_id: int) -> void:
	if !index_map.has(clip_id):
		return
	var clip_index: int = index_map[clip_id]
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
	deleted.emit(clip_id)
	Project.unsaved_changes = true


func ripple_delete(clip_ids: PackedInt64Array) -> void:
	# Store min start and total duration per track.
	var ranges_by_track: Dictionary[int, Vector2i] = {}

	for clip_id: int in clip_ids:
		if !index_map.has(clip_id):
			continue
		var clip_index: int = index_map[clip_id]
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
	for clip_id: int in clip_ids:
		if !index_map.has(clip_id):
			continue
		var snapshot: Dictionary = _create_snapshot(index_map[clip_id])
		InputManager.undo_redo.add_do_method(_delete.bind(clip_id))
		InputManager.undo_redo.add_undo_method(_restore_clip_from_snapshot.bind(snapshot))

	# Move remaining clips to fill the gap.
	for track: int in ranges_by_track:
		var gap_range: Vector2i = ranges_by_track[track]
		var gap_start: int = gap_range.x
		var gap_size: int = gap_range.y - gap_range.x

		for move_id: int in Project.tracks.get_clip_ids_after(track, gap_start):
			if move_id in clip_ids:
				continue
			var clip_index: int = index_map[move_id]
			var current_start: int = project_data.clips_start[clip_index]
			var new_start: int = current_start - gap_size

			InputManager.undo_redo.add_do_method(_move.bind(move_id, track, new_start))
			InputManager.undo_redo.add_undo_method(_move.bind(move_id, track, current_start))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func move(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Move clip_data(s)")
	for request: ClipRequest in requests:
		var clip_id: int = request.clip
		if !index_map.has(clip_id):
			continue
		var clip_index: int = index_map[clip_id]
		var current_track: int = project_data.clips_track[clip_index]
		var current_start: int = project_data.clips_start[clip_index]
		var new_track: int = current_track + request.track_offset
		var new_start: int = current_start + request.frame_offset

		InputManager.undo_redo.add_do_method(_move.bind(clip_id, new_track, new_start))
		InputManager.undo_redo.add_undo_method(_move.bind(clip_id, current_track, current_start))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _move(clip_id: int, new_track: int, new_frame: int) -> void:
	if !index_map.has(clip_id):
		return
	var clip_index: int = index_map[clip_id]
	var old_track: int = project_data.clips_track[clip_index]
	var old_frame: int = project_data.clips_start[clip_index]

	if old_track != new_track:
		Project.tracks.unregister_clip(old_track, old_frame)
		project_data.clips_track[clip_index] = new_track
		project_data.clips_start[clip_index] = new_frame
		Project.tracks.register_clip(new_track, clip_id, new_frame)
	else:
		project_data.clips_start[clip_index] = new_frame
		Project.tracks.update_clip_info(clip_id)
	updated.emit()
	Project.unsaved_changes = true


func cut(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Cut clip_data(s)")
	for request: ClipRequest in requests:
		var clip_id: int = request.clip
		if !index_map.has(clip_id):
			continue
		var clip_index: int = index_map[clip_id]
		var cut_offset: int = request.frame
		var current_duration: int = project_data.clips_duration[clip_index]
		var duration_left: int = cut_offset
		var duration_right: int = current_duration - cut_offset
		if duration_left <= 0 or duration_right <= 0:
			continue # Check for invalid cuts.

		# Cutting the main clip.
		InputManager.undo_redo.add_do_method(_resize.bind(clip_id, -duration_right, true))
		InputManager.undo_redo.add_undo_method(_resize.bind(clip_id, duration_right, true))

		# Construct the new clip snapshot.
		var snapshot: Dictionary = _create_snapshot_for_cut(clip_index, cut_offset, duration_left, duration_right)
		InputManager.undo_redo.add_do_method(_restore_clip_from_snapshot.bind(snapshot))
		InputManager.undo_redo.add_undo_method(_delete.bind(snapshot.id))
	InputManager.undo_redo.commit_action()


func resize(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Resize clip_data(s)")
	for request: ClipRequest in requests:
		var clip_id: int = request.clip
		var clip_index: int = index_map[clip_id]
		var amount: int = request.resize
		var from_end: int = request.is_end
		var current_start: int = project_data.clips_start[clip_index]
		var current_duration: int = project_data.clips_duration[clip_index]
		var current_begin: int = project_data.clips_begin[clip_index]

		InputManager.undo_redo.add_do_method(_resize.bind(clip_id, amount, from_end))
		InputManager.undo_redo.add_undo_method(_resize_restore.bind(clip_id, current_start, current_duration, current_begin))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _resize(id: int, amount: int, from_end: bool) -> void:
	var clip_index: int = index_map[id]
	if from_end:
		project_data.clips_duration[clip_index] += amount
		return updated.emit()

	var track: int = project_data.clips_track[clip_index]
	var old_start: int = project_data.clips_start[clip_index]
	var new_start: int = old_start + amount

	project_data.clips_start[clip_index] = new_start
	project_data.clips_begin[clip_index] += amount
	project_data.clips_duration[clip_index] -= amount

	Project.tracks.unregister_clip(track, old_start)
	Project.tracks.register_clip(track, id, new_start)
	updated.emit()


func _resize_restore(id: int, start: int, duration: int, begin: int) -> void:
	var clip_index: int = index_map[id]
	var track_id: int = project_data.clips_track[clip_index]
	var old_start_pos: int = project_data.clips_start[clip_index]

	project_data.clips_start[clip_index] = start
	project_data.clips_begin[clip_index] = begin
	project_data.clips_duration[clip_index] = duration

	if old_start_pos != start:
		Project.tracks.unregister_clip(track_id, old_start_pos)
		Project.tracks.register_clip(track_id, id, start)
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

func load_frame(clip_id: int, frame_nr: int) -> void:
	if !index_map.has(clip_id):
		return
	var clip_index: int = index_map[clip_id]
	var clip_type: EditorCore.TYPE = project_data.clips_type[clip_index] as EditorCore.TYPE
	var file_index: int = project_data.files.find(project_data.clips_file[clip_index])
	var video: GoZenVideo = null

	if clip_type not in EditorCore.VISUAL_TYPES:
		return
	elif clip_type == EditorCore.TYPE.VIDEO:
		if project_data.clips_individual_video.has(clip_id):
			video = Project.files.clip_video_instances[clip_id]
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


func get_audio_data(id: int) -> PackedByteArray:
	if !index_map.has(id):
		return PackedByteArray()

	var index: int = index_map[id]
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
		printerr("ClipLogic: Audio source %s not found for clip %s!" % [target_file_id, id])
		return PackedByteArray()

	var file_index: int = Project.data.files.find(target_file_id)
	var file_path: String = Project.data.files_path[file_index]
	return GoZenAudio.get_audio_data(file_path, -1, start_sec, duration_sec)


# --- Setters ---

func switch_ato_active(id: int) -> void:
	set_ato_active(id, project_data.clips_effects[index_map[id]].ato_active)


func set_ato_active(id: int, value: bool) -> void:
	if value:
		InputManager.undo_redo.create_action("Enable clip audio take over")
	else:
		InputManager.undo_redo.create_action("Disable clip audio take over")
	InputManager.undo_redo.add_do_method(_set_ato_active.bind(id, value))
	InputManager.undo_redo.add_undo_method(_set_ato_active.bind(id, !value))
	InputManager.undo_redo.commit_action()


func _set_ato_active(id: int, value: bool) -> void:
	project_data.clips_effects[index_map[id]].ato_active = value
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
