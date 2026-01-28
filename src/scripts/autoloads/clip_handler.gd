extends Node

signal clip_added(clip_id: int)
signal clip_deleted(clip_id: int)
signal clip_selected(clip_id: int)

signal clips_updated


var clips: Dictionary[int, ClipData] = {}


#--- Setters/Getters ---

func get_clip(id: int) -> ClipData:
	return clips[id] if clips.has(id) else null


func get_type(id: int) -> FileHandler.TYPE:
	return FileHandler.get_file_type(clips[id].file_id)


func get_start_frame(id: int, clip: ClipData = clips[id]) -> int:
	return clip.start_frame


func get_end_frame(id: int, clip: ClipData = clips[id]) -> int:
	return clip.start_frame + clip.duration - 1


func get_file_data(id: int, clip: ClipData = clips[id]) -> FileData:
	return FileHandler.get_file_data(clip.file_id)


#--- Clip handling functions ---

func load_frame(id: int, frame_nr: int, clip: ClipData = clips[id]) -> void:
	var type: FileHandler.TYPE = ClipHandler.get_type(clip.id)

	if type not in EditorCore.VISUAL_TYPES:
		return
	elif type in FileHandler.TYPE_VIDEOS:
		var file_data: FileData = FileHandler.get_file_data(clip.file_id)
		var video: GoZenVideo
		var video_frame_nr: int

		if file_data.clip_only_video.has(clip.id):
			video = file_data.clip_only_video[clip.id]
		else:
			video = file_data.video

		if video == null: return # Probably still loading.

		video_frame_nr = video.get_current_frame()
		frame_nr = int((frame_nr / Project.get_framerate()) * video.get_framerate())

		if frame_nr != video_frame_nr: # Shouldn't reload same frame
			if frame_nr == video_frame_nr + 1:
				video.next_frame(false)
			elif !video.seek_frame(frame_nr):
				printerr("ClipHandler: Couldn't seek frame!")


func get_clip_audio_data(id: int, clip: ClipData = clips[id]) -> PackedByteArray:
	var file: File = FileHandler.get_file(clip.file_id)
	var start_sec: float = float(clip.begin) / Project.get_framerate()
	var duration_sec: float = float(clip.duration) / Project.get_framerate()

	return GoZenAudio.get_audio_data(file.path, -1, start_sec, duration_sec)


func add_clips(data: Array[CreateClipRequest]) -> void:
	InputManager.undo_redo.create_action("Add new clip(s)")

	for clip_request: CreateClipRequest in data:
		var clip_data: ClipData = ClipData.new()
		var file_data: File = FileHandler.get_file(clip_request.file_id)

		clip_data.id = Utils.get_unique_id(ClipHandler.clips.keys())
		clip_data.file_id = file_data.id
		clip_data.track_id = clip_request.track_id
		clip_data.start_frame = clip_request.frame_nr
		clip_data.duration = file_data.duration

		if file_data.type in EditorCore.VISUAL_TYPES:
			var transform_effect: GoZenEffectVisual = load(
					Library.EFFECT_VISUAL_TRANSFORM).duplicate(true)

			# Setting default values
			for param: EffectParam in transform_effect.params:
				if param.param_id == "size":
					param.default_value = Project.get_resolution()
				elif param.param_id == "pivot":
					param.default_value = Vector2i(Project.get_resolution() / 2.0)

			transform_effect.set_default_keyframe()
			clip_data.effects_video.append(transform_effect)
		if file_data.type in EditorCore.AUDIO_TYPES:
			var volume_effect: GoZenEffectAudio = load(Library.EFFECT_AUDIO_VOLUME).duplicate(true)

			volume_effect.set_default_keyframe()
			clip_data.effects_audio.append(volume_effect)

		InputManager.undo_redo.add_do_method(_add_clip.bind(clip_data))
		InputManager.undo_redo.add_undo_method(_delete_clip.bind(clip_data))

	InputManager.undo_redo.commit_action()


func delete_clips(data: PackedInt64Array) -> void:
	# First check if clips still exist.
	var correct_data: PackedInt64Array = []

	for clip_id: int in data:
		if clips.has(clip_id):
			correct_data.append(clip_id)

	InputManager.undo_redo.create_action("Delete clip(s)")

	for clip_id: int in correct_data:
		var clip: ClipData = get_clip(clip_id)

		InputManager.undo_redo.add_do_method(_delete_clip.bind(clip))
		InputManager.undo_redo.add_undo_method(_add_clip.bind(clip))

	InputManager.undo_redo.commit_action()


func ripple_delete_clips(data: PackedInt64Array) -> void:
	if data.is_empty(): return
	var clips_by_track: Dictionary[int, PackedInt64Array] = {}
	var ranges_by_track: Dictionary[int, Vector2i] = {} # Store min start and total duration per track.

	for id: int in data:
		var clip: ClipData = ClipHandler.get_clip(id)
		if not clip: continue
		if not clips_by_track.has(clip.track_id):
			clips_by_track[clip.track_id] = []
			ranges_by_track[clip.track_id] = Vector2i(clip.start_frame, clip.end_frame)

		clips_by_track[clip.track_id].append(id)
		ranges_by_track[clip.track_id].x = mini(ranges_by_track[clip.track_id].x, clip.start_frame)
		ranges_by_track[clip.track_id].y = maxi(ranges_by_track[clip.track_id].y, clip.end_frame)

	InputManager.undo_redo.create_action("Ripple delete clip(s)")

	# First delete the clips.
	for clip_id: int in data:
		if !clips.has(clip_id): continue
		var clip: ClipData = get_clip(clip_id)

		InputManager.undo_redo.add_do_method(_delete_clip.bind(clip))
		InputManager.undo_redo.add_undo_method(_add_clip.bind(clip))

	# Move remaining clips to fill the gap.
	var move_requests: Array[MoveClipRequest] = []

	for track_id: int in ranges_by_track:
		var gap_start: int = ranges_by_track[track_id].x
		var gap_size: int = ranges_by_track[track_id].y - ranges_by_track[track_id].x

		for clip_id: int in TrackHandler.get_clip_ids_after(track_id, gap_start):
			move_requests.append(MoveClipRequest.new(clip_id, -gap_size, 0))

	if not move_requests.is_empty():
		ClipHandler.move_clips(move_requests)


func cut_clips(data: Array[CutClipRequest]) -> void:
	InputManager.undo_redo.create_action("Cut clip(s)")

	for clip_request: CutClipRequest in data:
		var clip_data: ClipData = clips[clip_request.clip_id]
		var new_clip_data: ClipData = ClipData.new()
		var cut_frame_pos: int = clip_request.cut_frame_pos
		var new_duration: int = clip_data.duration - cut_frame_pos

		# Editing the main clip
		InputManager.undo_redo.add_do_method(_resize_clip.bind(clip_data.id, -new_duration, true))
		InputManager.undo_redo.add_undo_method(_resize_clip.bind(clip_data.id, new_duration, true))

		# Adding the new clip (clone of old clip + duration changes)

		new_clip_data.id = Utils.get_unique_id(ClipHandler.get_ids())
		new_clip_data.file_id = clip_data.file_id
		new_clip_data.track_id = clip_data.track_id
		new_clip_data.begin = clip_data.begin + cut_frame_pos
		new_clip_data.start_frame = clip_data.start_frame + cut_frame_pos
		new_clip_data.duration = new_duration

		# Copy effects of main clip
		new_clip_data.effects_video.assign(
				_copy_visual_effects(clip_data.effects_video, cut_frame_pos))
		new_clip_data.effects_audio.assign(
				_copy_audio_effects(clip_data.effects_audio, cut_frame_pos))

		InputManager.undo_redo.add_do_method(_add_clip.bind(new_clip_data))
		InputManager.undo_redo.add_undo_method(_delete_clip.bind(new_clip_data))

	InputManager.undo_redo.commit_action()


func move_clips(data: Array[MoveClipRequest]) -> void:
	InputManager.undo_redo.create_action("Move clip(s)")

	for clip_request: MoveClipRequest in data:
		var clip: ClipData = clips[clip_request.clip_id]

		var new_track: int = clip.track_id + clip_request.track_offset
		var new_frame: int = clip.start_frame + clip_request.frame_offset

		InputManager.undo_redo.add_do_method(_clip_move.bind(clip.id, new_track, new_frame))
		InputManager.undo_redo.add_undo_method(_clip_move.bind(clip.id, clip.track_id, clip.start_frame))

	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)

	InputManager.undo_redo.commit_action()


func resize_clips(data: Array[ResizeClipRequest]) -> void:
	InputManager.undo_redo.create_action("Resize clip(s)")

	for request: ResizeClipRequest in data:
		var clip: ClipData = clips[request.clip_id]

		InputManager.undo_redo.add_do_method(_resize_clip.bind(clip.id, request.resize_amount, request.from_end))
		InputManager.undo_redo.add_undo_method(_resize_clip.bind(clip.id, -request.resize_amount, request.from_end))

	InputManager.undo_redo.add_do_method(Project.update_timeline_end)
	InputManager.undo_redo.add_undo_method(Project.update_timeline_end)

	InputManager.undo_redo.commit_action()


func set_clip(id: int, clip: ClipData) -> void:
	clip.id = id
	clips[id] = clip
	Project.unsaved_changes = true


func _add_clip(clip_data: ClipData) -> void:
	# Used for undoing the deletion of a file.
	clips[clip_data.id] = clip_data

	TrackHandler.set_frame_to_clip(clip_data.track_id, clip_data)
	clip_added.emit(clip_data.id)
	clips_updated.emit()
	Project.unsaved_changes = true


func _delete_clip(clip_data: ClipData) -> void:
	var clip_id: int = clip_data.id
	var track_id: int = clip_data.track_id
	var frame_nr: int = clip_data.start_frame

	TrackHandler.remove_clip_from_frame(track_id, frame_nr)
	clips.erase(clip_id)
	clip_deleted.emit(clip_id)
	clips_updated.emit()
	Project.unsaved_changes = true


func _clip_move(clip_id: int, new_track: int, new_frame: int) -> void:
	var clip: ClipData = clips[clip_id]

	TrackHandler.remove_clip_from_frame(clip.track_id, clip.start_frame)
	clip.track_id = new_track
	clip.start_frame = new_frame
	TrackHandler.set_frame_to_clip(new_track, clip)

	clips_updated.emit()
	Project.unsaved_changes = true


func _resize_clip(clip_id: int, resize_amount: int, end: bool) -> void:
	var clip_data: ClipData = clips[clip_id]

	if !end:
		var old_start_frame: int = clip_data.start_frame
		var new_start_frame: int = old_start_frame - resize_amount

		clip_data.start_frame = new_start_frame
		clip_data.begin -= resize_amount

		TrackHandler.remove_clip_from_frame(clip_data.track_id, old_start_frame)
		TrackHandler.set_frame_to_clip(clip_data.track_id, clip_data)

	clip_data.duration += resize_amount
	clips_updated.emit()


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

