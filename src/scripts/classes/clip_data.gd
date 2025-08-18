class_name ClipData
extends Node


# This is the amount that we allow to use next_frame before using seek_frame
# for the video data since seek_frame is usually slower
# TODO: Make this into a setting
const MAX_FRAME_SKIPS: int = 20


var clip_id: int
var file_id: int
var track_id: int

var start_frame: int # Timeline begin position of clip
var end_frame: int: get = get_end_frame
var duration: int
var begin: int = 0 # Only for video and audio files

var effects_video: EffectsVideo
var effects_audio: EffectsAudio



func get_end_frame() -> int:
	return start_frame + duration - 1


func get_frame(frame_nr: int) -> Texture:
	var type: File.TYPE = Project.get_clip_type(clip_id)

	if type not in EditorCore.VISUAL_TYPES:
		return null
	elif type == File.TYPE.VIDEO:
		# For the video stuff, we load in the data for the shader. The FileData
		# has a placeholder texture of the size of the video so in the end we
		# do the same as for the images, we return the picture. Only difference
		# is that we need to update the data which we send to the shader
		# through the editor.

		# Changing from global frame nr to clip frame nr
		var file_data: FileData = FileManager.get_file_data(file_id)
		var video: GoZenVideo

		if file_data.clip_only_video.has(clip_id):
			video = file_data.clip_only_video[clip_id]
		else:
			video = file_data.video

		var video_framerate: float = video.get_framerate()
		var video_frame_nr: int = video.get_current_frame()

		frame_nr = frame_nr - start_frame + begin
		frame_nr = int((frame_nr / Project.get_framerate()) * video_framerate)

		# check if not reloading same frame
		if frame_nr == video_frame_nr:
			return FileManager.get_file_data(file_id).image

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

	return FileManager.get_file_data(file_id).image


func get_clip_audio_data() -> PackedByteArray:
	var file_data: FileData = FileManager.get_file_data(file_id)
	var sample_size: int = Toolbox.get_sample_count(1)
	var data: PackedByteArray = file_data.audio.data.slice(
			Toolbox.get_sample_count(begin),
			Toolbox.get_sample_count(begin+duration))

	if effects_audio.mute:
		data.fill(0)
		return data

	data = GoZenAudio.change_db(data, effects_audio.gain[0])

	if effects_audio.fade_in != 0:
		var new_data: PackedByteArray = []

		for i: int in effects_audio.fade_in:
			var gain: float = Toolbox.calculate_fade(i, effects_audio.fade_in) * effects_audio.FADE_OUT_LIMIT
			var pos: int = sample_size * i

			new_data.append_array(GoZenAudio.change_db(data.slice(pos, pos + sample_size), gain))

		new_data.append_array(data.slice(sample_size * (effects_audio.fade_in + 1), data.size()))
		data = new_data
	if effects_audio.fade_out != 0:
		var new_data: PackedByteArray = []
		var start_pos: int = duration - effects_audio.fade_out

		for i: int in effects_audio.fade_out:
			var gain: float = Toolbox.calculate_fade(effects_audio.fade_out - i, effects_audio.fade_out) * effects_audio.FADE_OUT_LIMIT
			var pos: int = sample_size * (i + start_pos)

			new_data.append_array(GoZenAudio.change_db(data.slice(pos, pos + sample_size), gain))

		data = data.slice(0, sample_size * (duration - effects_audio.fade_out - 1))
		data.append_array(new_data)

	if effects_audio.mono != effects_audio.MONO.DISABLE:
		data = GoZenAudio.change_to_mono(data, effects_audio.mono == effects_audio.MONO.LEFT_CHANNEL)

	return data

