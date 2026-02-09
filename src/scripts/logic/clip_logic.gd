class_name ClipLogic
extends RefCounted

signal added(clip_id: int)
signal deleted(clip_id: int)
signal selected(clip_id: int)
signal updated ## Signal for when all clips got updated.


var file_ids: PackedInt64Array
var end_frames: PackedInt64Array # start_frame + duration

var project_data: ProjectData

var _id_map: Dictionary[int, int] = {} # { file_id: index }



func _init(data: ProjectData) -> void:
	project_data = data
	_rebuild_map()


func _rebuild_map() -> void:
	_id_map.clear()
	for i: int in project_data.clips_id.size():
		_id_map[project_data.clips_id[i]] = i


func _create_snapshot(index: int) -> Dictionary:
	return {
		"id": get_id(index),
		"file_id": get_file_id(index),
		"track_id": get_track_id(index),
		"start_frame": get_start_frame(index),
		"duration": get_duration(index),
		"begin": get_begin(index),
		"effects": get_effects(index).duplicate(true)
	}


# --- Handling ---

func add(data: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Add new clip(s)")
	for request: ClipRequest in data:
		var file_index: int = Project.files.get_index(request.file_id)
		var id: int = Utils.get_unique_id(project_data.clips_id)
		var snapshot: Dictionary = {
			"id": id,
			"file_id": request.file_id,
			"track_id": request.track_id,
			"start_frame": request.start_frame,
			"duration": Project.files.get_duration(file_index),
			"begin": 0,
			"effects": _create_default_effects(file_index)
		}
		InputManager.undo_redo.add_do_method(_restore_clip_from_snapshot.bind(snapshot))
		InputManager.undo_redo.add_undo_method(_delete.bind(id))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func delete(ids: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Delete clip_data(s)")
	for id: int in ids:
		var snapshot: Dictionary = _create_snapshot(get_index(id))
		InputManager.undo_redo.add_do_method(_delete.bind(id))
		InputManager.undo_redo.add_undo_method(_restore_clip_from_snapshot.bind(snapshot))
	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)
	InputManager.undo_redo.commit_action()


func _restore_clip_from_snapshot(snapshot: Dictionary) -> void:
	var index: int = size()

	project_data.clips_id.append(snapshot.id)
	project_data.clips_file_id.append(snapshot.file_id)
	project_data.clips_track_id.append(snapshot.track_id)
	project_data.clips_start_frame.append(snapshot.start_frame)
	project_data.clips_duration.append(snapshot.duration)
	project_data.clips_begin.append(snapshot.begin)
	project_data.clips_effects.append(snapshot.effects)
	_id_map[snapshot.id] = index

	Project.tracks.register_clip(snapshot.track_id, snapshot.id, snapshot.start_frame)
	added.emit(snapshot.id)
	Project.unsaved_changes = true


func ripple_delete(data: PackedInt64Array) -> void:
	if data.is_empty(): return
	var clips_by_track: Dictionary[int, PackedInt64Array] = {}
	var ranges_by_track: Dictionary[int, Vector2i] = {} # Store min start and total duration per track.

	for id: int in data:
		var clip_data: ClipData = Project.clips.get_clip(id)
		if not clip_data: continue
		if not clips_by_track.has(clip_data.track_id):
			clips_by_track[clip_data.track_id] = []
			ranges_by_track[clip_data.track_id] = Vector2i(clip_data.start_frame, clip_data.end_frame)

		clips_by_track[clip_data.track_id].append(id)
		ranges_by_track[clip_data.track_id].x = mini(ranges_by_track[clip_data.track_id].x, clip_data.start_frame)
		ranges_by_track[clip_data.track_id].y = maxi(ranges_by_track[clip_data.track_id].y, clip_data.end_frame)

	InputManager.undo_redo.create_action("Ripple delete clip_data(s)")

	# First delete the clips.
	for clip_id: int in data:
		if !clips.has(clip_id): continue
		var clip_data: ClipData = get_clip(clip_id)

		InputManager.undo_redo.add_do_method(_delete.bind(clip_data))
		InputManager.undo_redo.add_undo_method(_add.bind(clip_data))

	# Move remaining clips to fill the gap.
	var move_requests: Array[ClipRequest] = []

	for track_id: int in ranges_by_track:
		var gap_start: int = ranges_by_track[track_id].x
		var gap_size: int = ranges_by_track[track_id].y - ranges_by_track[track_id].x

		for clip_id: int in Project.tracks.get_clip_ids_after(track_id, gap_start):
			move_requests.append(ClipRequest.new(clip_id, -gap_size, 0))

	if not move_requests.is_empty():
		Project.clips.move(move_requests)


func _delete(id: int) -> void:
	if !has(id): return
	var index: int = get_index(id)
	var track_id: int = get_track_id(index)
	var frame_nr: int = get_start_frame(index)

	Project.tracks.unregister_clip(track_id, frame_nr)

	project_data.clips_id.remove_at(index)
	project_data.clips_file_id.remove_at(index)
	project_data.clips_start_frame.remove_at(index)
	project_data.clips_track_id.remove_at(index)
	project_data.clips_start_frame.remove_at(index)
	project_data.clips_duration.remove_at(index)
	project_data.clips_begin.remove_at(index)
	project_data.clips_effects.remove_at(index)
	_rebuild_map()

	deleted.emit(id)
	Project.unsaved_changes = true


func cut(data: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Cut clip_data(s)")

	for request: ClipRequest in data:
		var clip_data: ClipData = clips[request.clip_id]
		var new_clip_data: ClipData = ClipData.new()
		var cut_frame_pos: int = request.cut_frame_pos
		var new_duration: int = clip_data.duration - cut_frame_pos

		# Editing the main clip_data
		InputManager.undo_redo.add_do_method(_resize.bind(clip_data.id, -new_duration, true))
		InputManager.undo_redo.add_undo_method(_resize.bind(clip_data.id, new_duration, true))

		# Adding the new clip_data (clone of old clip_data + duration changes)

		new_clip_data.id = Utils.get_unique_id(Project.clips.get_ids())
		new_clip_data.file_id = clip_data.file_id
		new_clip_data.track_id = clip_data.track_id
		new_clip_data.begin = clip_data.begin + cut_frame_pos
		new_clip_data.start_frame = clip_data.start_frame + cut_frame_pos
		new_clip_data.duration = new_duration

		# Copy effects of main clip_data
		new_clip_data.effects_video.assign(
				_copy_visual_effects(clip_data.effects_video, cut_frame_pos))
		new_clip_data.effects_audio.assign(
				_copy_audio_effects(clip_data.effects_audio, cut_frame_pos))

		InputManager.undo_redo.add_do_method(_add.bind(new_clip_data))
		InputManager.undo_redo.add_undo_method(_delete.bind(new_clip_data))

	InputManager.undo_redo.commit_action()


func move(data: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Move clip_data(s)")

	for request: ClipRequest in data:
		var clip_data: ClipData = clips[request.clip_id]

		var new_track: int = clip_data.track_id + request.track_offset
		var new_frame: int = clip_data.start_frame + request.frame_offset

		InputManager.undo_redo.add_do_method(_clip_move.bind(clip_data.id, new_track, new_frame))
		InputManager.undo_redo.add_undo_method(_clip_move.bind(clip_data.id, clip_data.track_id, clip_data.start_frame))

	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)

	InputManager.undo_redo.commit_action()


func _move(clip_id: int, new_track: int, new_frame: int) -> void:
	var clip_data: ClipData = clips[clip_id]

	Project.tracks.remove_clip_from_frame(clip_data.track_id, clip_data.start_frame)
	clip_data.track_id = new_track
	clip_data.start_frame = new_frame
	Project.tracks.set_frame_to_clip(new_track, clip_data)

	clips_updated.emit()
	Project.unsaved_changes = true


func resize(requests: Array[ClipRequest]) -> void:
	InputManager.undo_redo.create_action("Resize clip_data(s)")

	for request: ClipRequest in requests:
		var id: int = request.clip_id
		var index: int = get_index(id)
		var amount: int = request.resize_amount
		var from_end: int = request.from_end
		var current_start: int = get_start_frame(index)
		var current_duration: int = get_duration(index)
		var current_begin: int = get_begin(index)

		InputManager.undo_redo.add_do_method(_resize.bind(id, amount, from_end))
		InputManager.undo_redo.add_undo_method(_resize_restore.bind(id, current_start, current_duration, current_begin))

	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)

	InputManager.undo_redo.commit_action()


func _resize(id: int, amount: int, from_end: bool) -> void:
	if from_end:
		project_data.clips_duration[get_index(id)] += amount
		return updated.emit()

	var index: int = get_index(id)
	var track_id: int = get_track_id(index)
	var old_start: int = project_data.clips_start_frame[index]
	var new_start: int = old_start + amount

	project_data.clips_start_frame[index] = new_start
	project_data.clips_duration[index] -= amount
	project_data.clips_begin[index] += amount

	Project.tracks.remove_clip_from_frame(track_id, old_start)
	Project.tracks.register_clip(track_id, id, new_start)
	updated.emit()


func _resize_restore(id: int, start: int, duration: int, begin: int) -> void:
	var index: int = get_index(id)
	var track_id: int = project_data.clips_track_id[index]
	var old_start_pos: int = project_data.clips_start_frame[index] # Current state before undo

	project_data.clips_start_frame[index] = start
	project_data.clips_duration[index] = duration
	project_data.clips_begin[index] = begin

	if old_start_pos != start:
		Project.tracks.remove_clip_from_frame(track_id, old_start_pos)
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
			var param_id: String = param.param_id
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
			var param_id: String = param.param_id
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


# --- Playback helpers ---

func load_frame(id: int, frame_nr: int) -> void:
	var type: FileLogic.TYPE = Project.clips.get_type(clip_data.id)

	if type not in EditorCore.VISUAL_TYPES:
		return
	elif type in FileLogic.TYPE_VIDEOS:
		var file_data: FileData = Project.files.get_file_data(clip_data.file_id)
		var video: GoZenVideo
		var video_frame_nr: int

		if file_data.clip_only_video.has(clip_data.id):
			video = file_data.clip_only_video[clip_data.id]
		else:
			video = file_data.video

		if video == null: return # Probably still loading.

		video_frame_nr = video.get_current_frame()
		frame_nr = int((frame_nr / Project.get_framerate()) * video.get_framerate())

		if frame_nr != video_frame_nr: # Shouldn't reload same frame
			if frame_nr == video_frame_nr + 1:
				video.next_frame(false)
			elif !video.seek_frame(frame_nr):
				printerr("Project.clips: Couldn't seek frame!")


func get_clip_audio_data(id: int, clip_data: ClipData = clips[id]) -> PackedByteArray:
	var start_sec: float = clip_data.begin / Project.get_framerate()
	var duration_sec: float = float(clip_data.duration) / Project.get_framerate()

	if clip_data.ato_active and clip_data.ato_file_id != -1:
		start_sec -= clip_data.ato_offset
		file = Project.files.get_file(clip_data.ato_file_id)
	else:
		file = Project.files.get_file(clip_data.file_id)

	return GoZenAudio.get_audio_data(file.path, -1, start_sec, duration_sec)


# --- Getters ---

func size() -> int: return _id_map.size()
func has(id: int) -> bool: return _id_map.has(id)
func get_index(clip_id: int) -> int: return _id_map[clip_id]

func get_id(index: int) -> int: return project_data.clips_id[index]
func get_file_id(index: int) -> int: return project_data.clips_file_id[index]
func get_track_id(index: int) -> int: return project_data.clips_track_id[index]
func get_start_frame(index: int) -> int: return project_data.clips_start_frame[index]
func get_duration(index: int) -> int: return project_data.clips_duration[index]
func get_begin(index: int) -> int: return project_data.clips_begin[index]
func get_effects(index: int) -> ClipEffects: return project_data.clips_effects[index]

# This variable is only necessary for video files, so only the id's of clips
# who require an individual video file will be presented here
var clips_individual_video: PackedInt64Array = [] ## [ clip_id's ]


# --- Helpers ---

func _create_default_effects(file_index: int) -> ClipEffects:
	var type: FileLogic.TYPE = Project.files.get_type(file_index)
	var effects: ClipEffects = ClipEffects.new()

	if type in EditorCore.VISUAL_TYPES:
		var resolution: Vector2i = Project.get_resolution()

		var transform_effect: GoZenEffectVisual = load(Library.EFFECT_VISUAL_TRANSFORM).duplicate(true)
		for param: EffectParam in transform_effect.params:
			if param.id == "size": param.default_value = resolution
			elif param.id == "pivot": param.default_value = Vector2i(resolution / 2.0)
		transform_effect.set_default_keyframe()
		effects.video.append(transform_effect)

	if type in EditorCore.AUDIO_TYPES:
		var volume_effect: GoZenEffectAudio = load(Library.EFFECT_AUDIO_VOLUME).duplicate(true)
		volume_effect.set_default_keyframe()
		effects.audio.append(volume_effect)


	return effects
