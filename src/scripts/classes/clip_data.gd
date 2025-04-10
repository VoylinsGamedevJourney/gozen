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



func get_end_frame() -> int:
	return start_frame + duration


func get_frame(frame_nr: int) -> Texture:
	var type: File.TYPE = Project.get_clip_type(clip_id)

	if type not in Editor.VISUAL_TYPES:
		return null
	elif type == File.TYPE.VIDEO:
		# For the video stuff, we load in the data for the shader. The FileData
		# has a placeholder texture of the size of the video so in the end we
		# do the same as for the images, we return the picture. Only difference
		# is that we need to update the data which we send to the shader
		# through the editor.

		# Changing from global frame nr to clip frame nr
		var file_data: FileData = Project.get_file_data(file_id)
		var video_frame_nr: int = file_data.video.get_current_frame()
		frame_nr = frame_nr - start_frame + begin

		# check if not reloading same frame
		if frame_nr == video_frame_nr:
			return

		# check if frame is before current one or after max skip
		var skips: int = frame_nr - video_frame_nr

		if frame_nr < video_frame_nr or skips > MAX_FRAME_SKIPS:
			if !file_data.video.seek_frame(frame_nr):
				printerr("Couldn't seek frame!")

			return Project.get_file_data(file_id).image

		# go through skips and set frame
		for i: int in skips:
			if !file_data.video.next_frame(i == skips):
				print("Something went wrong skipping next frame!")
		
	return Project.get_file_data(file_id).image


func get_clip_audio_data() -> PackedByteArray:
	var file_data: FileData = Project.get_file_data(file_id)

	return file_data.audio.data.slice(begin, begin + duration)
		
