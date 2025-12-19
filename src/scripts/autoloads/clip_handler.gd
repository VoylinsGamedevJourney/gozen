extends Node


signal clip_added(clip_id: int)
signal clip_deleted(clip_id: int)

# This is the amount that we allow to use next_frame before using seek_frame
# for the video data since seek_frame is usually slower
# TODO: Make this into a setting
const MAX_FRAME_SKIPS: int = 20


var clips: Dictionary[int, ClipData] = {}



func get_clip(id: int) -> ClipData:
	return clips[id]


func get_type(id: int) -> File.TYPE:
	return FileHandler.get_files()[clips[id].file_id].type


func get_clip_datas() -> Array[ClipData]:
	return clips.values()


func get_clip_ids() -> PackedInt64Array:
	return clips.keys()


func get_end_frame(id: int, clip: ClipData = clips[id]) -> int:
	return clip.start_frame + clip.duration - 1


func get_clip_type(clip: ClipData) -> File.TYPE:
	return FileHandler.get_file_type(clip.file_id)


func get_frame(id: int, frame_nr: int, clip: ClipData = clips[id]) -> Texture:
	var type: File.TYPE = Project.get_clip_type(clip.id)

	if type not in EditorCore.VISUAL_TYPES:
		return null
	elif type == File.TYPE.VIDEO:
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
	InputManager.undo_redo.create_action("Adding new clip(s)")

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
		if file_data.type in EditorCore.AUDIO_TYPES:
			clip_data.effects_audio = EffectsAudio.new()
			clip_data.effects_audio.clip_id = clip_data.id

		InputManager.undo_redo.add_do_method(add_clip.bind(clip_data))
		InputManager.undo_redo.add_undo_method(delete_clip.bind(clip_data))

	InputManager.undo_redo.commit_action()
	

func delete_clips(data: PackedInt64Array) -> void:
	InputManager.undo_redo.create_action("Removing clip(s)")

	for clip_id: int in data:
		var clip: ClipData = get_clip(clip_id)

		InputManager.undo_redo.add_do_method(delete_clip.bind(clip))
		InputManager.undo_redo.add_undo_method(add_clip.bind(clip))

	InputManager.undo_redo.commit_action()


func move_clips(data: Array[MoveClipRequest]) -> void:
	InputManager.undo_redo.create_action("Moving clip(s)")

	for clip_request: MoveClipRequest in data:
		print("TODO")

	InputManager.undo_redo.commit_action()
#	InputManager.undo_redo.create_action("Moving clips on timeline")
#
#	InputManager.undo_redo.add_do_method(_move_clips.bind(
#			draggable,
#			draggable.differences.y,
#			draggable.differences.x + _offset))
#	InputManager.undo_redo.add_undo_method(_move_clips.bind(
#			draggable,
#			-draggable.differences.y,
#			-(draggable.differences.x + _offset)))

func set_clip(id: int, clip: ClipData) -> void:
	clip.id = id
	clips[id] = clip
	Project.unsaved_changes = true


func add_clip(clip_data: ClipData) -> void:
	# Used for undoing the deletion of a file.
	clips[clip_data.id] = clip_data
	TrackHandler.set_frame_to_clip(clip_data.track_id, clip_data)
	clip_added.emit(clip_data.id)
	Project.unsaved_changes = true


func delete_clip(clip_data: ClipData) -> void:
	var clip_id: int = clip_data.id
	var track_id: int = clip_data.track_id
	var frame_nr: int = clip_data.start_frame

	TrackHandler.remove_clip_from_frame(track_id, frame_nr)
	clips.erase(clip_id)
	clip_deleted.emit(clip_id)
	Project.unsaved_changes = true
