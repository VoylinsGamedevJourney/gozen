class_name AudioHandler extends Node


static var instance: AudioHandler

# Numbers are: mix_rate, stereo, 16 bits so 2 bytes per sample
static var bytes_per_frame: int

var end_frame: int = 0
var audio_streams: Array[AudioStreamWAV] = []



func _ready() -> void:
	instance = self
	bytes_per_frame = int(float(44100 * 2 * 2) / Project.framerate)

	for i: int in 6:
		var l_stream: AudioStreamWAV = AudioStreamWAV.new()
		var l_player: AudioStreamPlayer = get_child(i)

		l_stream.stereo = true
		l_player.stream = l_stream
		audio_streams.append(l_stream)


func play_audio(a_frame: int) -> void:
	for l_player: AudioStreamPlayer in get_children():
		l_player.play(float(a_frame) / Project.framerate)


func add_data(a_track: int, a_frame: int, a_data: PackedByteArray) -> void:
	# First adding the extra frames if timeline_end changed
	_resize_streams()

	# Add the data to the stream
	var l_head: PackedByteArray = audio_streams[a_track].data.slice(
			0, a_frame * bytes_per_frame)
	l_head.append_array(a_data)
	l_head.append_array(audio_streams[a_track].data.slice(l_head.size() * bytes_per_frame))

	audio_streams[a_track].data = l_head


func remove_data(a_track: int, a_frame: int, a_size: int) -> void:
	# First removing the extra frames if timeline_end changed
	_resize_streams()

	# Replace all bytes by 0, break when we are outside of the timeline size
	var l_empty: PackedByteArray = []
	if l_empty.resize(a_size):
		printerr("Problem resizing empty PackedByteArray!")

	var l_head: PackedByteArray = audio_streams[a_track].data.slice(
			0, a_frame * bytes_per_frame)
	l_head.append_array(a_data)
	l_head.append_array(audio_streams[a_track].data.slice(l_head.size() * bytes_per_frame))

	audio_streams[a_track].data = l_head


func _resize_streams() -> void:
	if Project.timeline_end == end_frame:
		return

	var l_new_size: int = Project.timeline_end * bytes_per_frame
	l_new_size += audio_streams[0].data.size()

	for l_audio_stream: AudioStreamWAV in audio_streams:
		var l_data: PackedByteArray = l_audio_stream.data

		if l_data.resize(l_new_size):
			printerr("Problem resizing AudioStreamWav data!")
		l_audio_stream.data = l_data

