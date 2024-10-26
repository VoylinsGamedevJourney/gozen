class_name VideoData
extends Node


var data: Video = Video.new()
var audio_data: AudioStream = null

var current_frame: int = -1 # Current frame in timeline
var frame_nr: int = 0 # Current frame in video file
var frame_skip: int = 0

var err: int = 0



func open(a_path: String, a_load_audio: bool) -> bool:
	err = data.open(a_path, a_load_audio)
	if err:
		printerr("Something went wrong opening video file! ", err)
		return false
	audio_data = data.get_audio()
	return true


func check_open() -> bool:
	return data.is_open()


func get_frame() -> ImageTexture:
	if frame_skip < 0 or frame_skip	> 8 or (!GoZenServer.is_playing and frame_skip > 8): 
		frame_nr = current_frame
		return ImageTexture.create_from_image(data.seek_frame(frame_nr))
	for i: int in frame_skip:
		if i + 1 == frame_skip:
			frame_nr = current_frame
			return ImageTexture.create_from_image(data.next_frame())
		if data.next_frame() == null:
			printerr("Skipped frame was null!")

	printerr("Something went wrong fetching video frame!")
	return null

	
func next_available(a_frame_nr: int, a_clip: ClipData) -> bool:
	a_frame_nr = int(a_frame_nr / float(Project.framerate) * data.get_framerate())
	current_frame = max(round(a_frame_nr - a_clip.pts - a_clip.start / float(Project.framerate) * data.get_framerate()), 0)
	if current_frame != frame_nr:
		frame_skip = -1 if current_frame < frame_nr else current_frame - frame_nr
		return true
	frame_skip = -1
	return false

