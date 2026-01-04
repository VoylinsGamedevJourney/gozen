extends Node


signal clip_added(clip_id: int)
signal clip_deleted(clip_id: int)
signal clips_updated

# This is the amount that we allow to use next_frame before using seek_frame
# for the video data since seek_frame is usually slower
# TODO: Make this into a setting
const MAX_FRAME_SKIPS: int = 20


var clips: Dictionary[int, ClipData] = {}



func has_clip(id: int) -> bool:
	return clips.has(id)


func get_clip(id: int) -> ClipData:
	if has_clip(id):
		return clips[id]
	return null


func get_type(id: int) -> FileHandler.TYPE:
	return FileHandler.get_file(clips[id].file_id).type


func get_clip_datas() -> Array[ClipData]:
	return clips.values()


func get_clip_ids() -> PackedInt64Array:
	return clips.keys()


func get_start_frame(id: int, clip: ClipData = clips[id]) -> int:
	return clip.start_frame


func get_end_frame(id: int, clip: ClipData = clips[id]) -> int:
	return clip.start_frame + clip.duration - 1


func get_clip_track_id(id: int, clip: ClipData = clips[id]) -> int:
	return clip.track_id


func get_clip_file_id(id: int, clip: ClipData = clips[id]) -> int:
	return clip.file_id


func get_clip_file_data(id: int, clip: ClipData = clips[id]) -> FileData:
	return FileHandler.get_file_data(clip.file_id)


func get_frame(id: int, frame_nr: int, clip: ClipData = clips[id]) -> Texture:
	var type: FileHandler.TYPE = ClipHandler.get_type(clip.id)

	if type not in EditorCore.VISUAL_TYPES:
		return null
	elif type == FileHandler.TYPE.VIDEO:
		# For the video stuff, we load in the data for the shader. The FileData
		# has a placeholder texture of the size of the video so in the end we
		# do the same as for the images, we return the picture. Only difference
		# is that we need to update the data which we send to the shader
		# through the editor.

		# Changing from global frame nr to clip frame nr
		var file_data: FileData = FileHandler.get_file_data(clip.file_id)
		var video: GoZenVideo

		if file_data.clip_only_video.has(clip.id):
			video = file_data.clip_only_video[clip.id]
		else:
			video = file_data.video

		var video_framerate: float = video.get_framerate()
		var video_frame_nr: int = video.get_current_frame()

		frame_nr = frame_nr - clip.start_frame + clip.begin
		frame_nr = int((frame_nr / Project.get_framerate()) * video_framerate)

		# check if not reloading same frame
		if frame_nr == video_frame_nr:
			return FileHandler.get_file_data(clip.file_id).image

		# check if frame is before current one or after max skip
		var skips: int = frame_nr - video_frame_nr

		if frame_nr < video_frame_nr or skips > MAX_FRAME_SKIPS:
			if !video.seek_frame(frame_nr):
				printerr("Couldn't seek frame!")
		else:
			# go through skips and set frame
			for i: int in skips:
				if !video.next_frame(i == skips):
					print("Something went wrong skipping next frame!")

	return FileHandler.get_file_data(clip.file_id).image


func get_clip_audio_data(id: int, clip: ClipData = clips[id]) -> PackedByteArray:
	var file_data: FileData = FileHandler.get_file_data(clip.file_id)
	var sample_size: int = Utils.get_sample_count(1, Project.get_framerate())
	var data: PackedByteArray = file_data.audio.data.slice(
			Utils.get_sample_count(clip.begin, Project.get_framerate()),
			Utils.get_sample_count(clip.begin + clip.duration, Project.get_framerate()))

	if clip.effects_audio.mute:
		data.fill(0)
		return data

	data = GoZenAudio.change_db(data, clip.effects_audio.gain[0])

	if clip.effects_audio.fade_in != 0:
		var new_data: PackedByteArray = []

		for i: int in clip.effects_audio.fade_in:
			var gain: float = Utils.calculate_fade(i, clip.effects_audio.fade_in) * clip.effects_audio.FADE_OUT_LIMIT
			var pos: int = sample_size * i

			new_data.append_array(GoZenAudio.change_db(data.slice(pos, pos + sample_size), gain))

		new_data.append_array(data.slice(sample_size * (clip.effects_audio.fade_in + 1), data.size()))
		data = new_data
	if clip.effects_audio.fade_out != 0:
		var new_data: PackedByteArray = []
		var start_pos: int = clip.duration - clip.effects_audio.fade_out

		for i: int in clip.effects_audio.fade_out:
			var pos: int = sample_size * (i + start_pos)
			var gain: float = Utils.calculate_fade(clip.effects_audio.fade_out - i, clip.effects_audio.fade_out)

			gain *= clip.effects_audio.FADE_OUT_LIMIT
			new_data.append_array(GoZenAudio.change_db(data.slice(pos, pos + sample_size), gain))

		data = data.slice(0, sample_size * (clip.duration - clip.effects_audio.fade_out - 1))
		data.append_array(new_data)

	if clip.effects_audio.mono != clip.effects_audio.MONO.DISABLE:
		data = GoZenAudio.change_to_mono(data, clip.effects_audio.mono == clip.effects_audio.MONO.LEFT_CHANNEL)

	return data


func add_clips(data: Array[CreateClipRequest]) -> void:
	InputManager.undo_redo.create_action("Add new clip(s)")

	for clip_request: CreateClipRequest in data:
		var clip_data: ClipData = ClipData.new()
		var file_data: File = FileHandler.get_file(clip_request.file_id)

		clip_data.id = Utils.get_unique_id(ClipHandler.get_clip_ids())
		clip_data.file_id = file_data.id
		clip_data.track_id = clip_request.track_id
		clip_data.start_frame = clip_request.frame_nr
		clip_data.duration = file_data.duration

		if file_data.type in EditorCore.VISUAL_TYPES:
			clip_data.effects_video = EffectsVideo.new()
			clip_data.effects_video.clip_id = clip_data.id
			clip_data.effects_video.set_default_transform()
		if file_data.type in EditorCore.AUDIO_TYPES:
			clip_data.effects_audio = EffectsAudio.new()
			clip_data.effects_audio.clip_id = clip_data.id

		InputManager.undo_redo.add_do_method(_add_clip.bind(clip_data))
		InputManager.undo_redo.add_undo_method(_delete_clip.bind(clip_data))

	InputManager.undo_redo.add_do_method(clips_updated.emit)
	InputManager.undo_redo.add_undo_method(clips_updated.emit)

	InputManager.undo_redo.commit_action()
	

func delete_clips(data: PackedInt64Array) -> void:
	# First check if clips still exist.
	var correct_data: PackedInt64Array = []

	for clip_id: int in data:
		if clips.has(clip_id):
			correct_data.append(clip_id)

	InputManager.undo_redo.create_action("Remove clip(s)")

	for clip_id: int in correct_data:
		var clip: ClipData = get_clip(clip_id)

		InputManager.undo_redo.add_do_method(_delete_clip.bind(clip))
		InputManager.undo_redo.add_undo_method(_add_clip.bind(clip))

	InputManager.undo_redo.add_do_method(clips_updated.emit)
	InputManager.undo_redo.add_undo_method(clips_updated.emit)

	InputManager.undo_redo.commit_action()


func cut_clips(data: Array[CutClipRequest]) -> void:
	InputManager.undo_redo.create_action("Cut clip(s)")

	for clip_request: CutClipRequest in data:
		var clip_data: ClipData = clips[clip_request.clip_id]
		var new_duration: int = clip_data.duration - clip_request.cut_frame_pos

		# Editing the main clip
		InputManager.undo_redo.add_do_method(_resize_clip.bind(clip_data, -new_duration, true))
		InputManager.undo_redo.add_undo_method(_resize_clip.bind(clip_data, new_duration, true))

		# Adding the new clip (clone of old clip + duration changes)
		var new_clip_data: ClipData = ClipData.new()

		new_clip_data.id = Utils.get_unique_id(ClipHandler.get_clip_ids())
		new_clip_data.file_id = clip_data.file_id
		new_clip_data.track_id = clip_data.track_id
		new_clip_data.begin = clip_data.begin + clip_request.cut_frame_pos
		new_clip_data.start_frame = clip_data.start_frame + clip_request.cut_frame_pos
		new_clip_data.duration = new_duration

		# TODO: Copy effects stuff, can't do that yet due to the new
		# effects system which I'm working on.
		InputManager.undo_redo.add_do_method(_add_clip.bind(new_clip_data))
		InputManager.undo_redo.add_undo_method(_delete_clip.bind(new_clip_data))

	InputManager.undo_redo.add_do_method(clips_updated.emit)
	InputManager.undo_redo.add_undo_method(clips_updated.emit)

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
	InputManager.undo_redo.add_do_method(clips_updated.emit)
	InputManager.undo_redo.add_undo_method(clips_updated.emit)

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
