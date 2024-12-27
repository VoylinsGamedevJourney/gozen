class_name AudioHandler extends Node

# TODO: For double speed, change mix_rate or pitch (mix rate is easier)


static var instance: AudioHandler

# Numbers are: mix_rate, stereo, 16 bits so 2 bytes per sample
static var bytes_per_frame: int

var players: Array[AudioStreamPlayer] = []
var streams: Array[AudioStreamWAV] = []



func _ready() -> void:
	instance = self
	bytes_per_frame = int(float(44100 * 2 * 2) / Project.framerate)

	for i: int in 6:
		players.append(get_child(i))
	
	for l_player: AudioStreamPlayer in players:
		var l_stream: AudioStreamWAV = AudioStreamWAV.new()

		streams.append(l_stream)
		l_stream.format = AudioStreamWAV.FORMAT_16_BITS
		l_stream.stereo = true
		l_player.stream = l_stream


func set_audio(a_track: int, a_audio: PackedByteArray, a_frame: int, a_play: bool = false) -> void:
	streams[a_track].data = a_audio
	players[a_track].play(float(a_frame) / Project.framerate)
	players[a_track].stream_paused = !a_play


func play_audio(a_track:int) -> void:
	players[a_track].stream_paused = false


func play_all_audio() -> void:
	for i: int in 6:
		play_audio(i)


func stop_audio(a_track: int) -> void:
	players[a_track].stream_paused = true


func stop_all_audio() -> void:
	for i: int in 6:
		stop_audio(i)

	
func reset_audio_stream(a_track: int) -> void:
	stop_audio(a_track)
	streams[a_track].data = []


func reset_audio_streams() -> void:
	for i: int in 6:
		reset_audio_stream(i)
