extends Node

# This is the amount that we allow to use next_frame before using seek_frame
# for the video data since seek_frame is usually slower
# TODO: Make this into a setting
const MAX_FRAME_SKIPS: int = 20



func _get_data(clip_id: int) -> ClipData:
	return Project.get_clip(clip_id)


func get_end_frame(clip_id: int, clip: ClipData = _get_data(clip_id)) -> int:
	return clip.start_frame + clip.duration - 1



func get_frame(clip_id: int, frame_nr: int, clip: ClipData = _get_data(clip_id)) -> Texture:
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
		var file_data: FileData = FileManager.get_file_data(clip.file_id)
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
			return FileManager.get_file_data(clip.file_id).image

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

	return FileManager.get_file_data(clip.file_id).image


func get_clip_audio_data(clip_id: int, clip: ClipData = _get_data(clip_id)) -> PackedByteArray:
	var file_data: FileData = FileManager.get_file_data(clip.file_id)
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

