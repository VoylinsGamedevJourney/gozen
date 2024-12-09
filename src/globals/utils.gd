extends Node


## Generates a unique id, which is used for the file and clip id's.
func generate_unique_id(a_data: PackedInt32Array) -> int:
	var l_id: int = 0

	while true:
		randomize()
		l_id = randi()

		if !a_data.has(l_id):
			break

	return l_id


## Calculate the position in timeline to the correct frame number.
func pos_to_frame(a_pos: float, a_zoom: float) -> int:
	return floor(a_pos / a_zoom)


## Calculate the frame number to the correct position in timeline.
func frame_to_pos(a_frame_nr: int, a_zoom: float) -> float:
	return a_frame_nr * a_zoom


## Calculates the frame duration of a video according to the project framerate.
func calculate_duration_video(a_video: Video) -> int:
	return roundi(a_video.get_frame_duration() /
				  a_video.get_framerate() *
				  Project.get_framerate())


## Calculates the frame duration of a wav according to the project framerate.
func calculate_duration_audio(a_stream: AudioStreamWAV) -> int:
	return roundi(a_stream.get_length() * Project.get_framerate())

