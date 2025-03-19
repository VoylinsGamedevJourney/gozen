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
var begin: int = 0 # Only for video files



func get_end_frame() -> int:
	return start_frame + duration


func load_video_frame(a_nr: int) -> void:
	# Changing from global frame nr to clip frame nr
	var l_file_data: FileData = Project.get_file_data(file_id)
	var l_video: Video = l_file_data.videos[track_id]

	a_nr = a_nr - start_frame + begin

	# Check if not reloading same frame
	if a_nr == l_file_data.current_frame[track_id]:
		return

	# Check if frame is before current one or after max skip
	var l_skips: int = a_nr - l_file_data.current_frame[track_id]

	if a_nr < l_file_data.current_frame[track_id] or l_skips > MAX_FRAME_SKIPS:
		l_file_data.current_frame[track_id] = a_nr

		if !l_video.seek_frame(a_nr):
			printerr("Couldn't seek frame!")

		return

	# Go through skips and set frame
	for i: int in l_skips - 1:
		if !l_video.next_frame(true):
			print("Something went wrong skipping next frame!")

	l_file_data.current_frame[track_id] = a_nr

	if !l_video.next_frame(false):
		print("Something went wrong skipping next frame!")


func get_clip_audio_data() -> PackedByteArray:
	var l_file_data: FileData = Project.get_file_data(file_id)

	return l_file_data.audio.data.slice(begin, begin + duration)
		
