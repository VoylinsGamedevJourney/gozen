extends Node

# TODO: For double speed, change mix_rate or pitch (mix rate is easier)

# Numbers are: mix_rate, stereo, 16 bits so 2 bytes per sample
static var bytes_per_frame: int


var players: Array[AudioStreamPlayer] = []
var streams: Array[AudioStreamWAV] = []



func _ready() -> void:
	bytes_per_frame = int(float(44100 * 2 * 2) / Project.framerate)

	for i: int in 6:
		var l_player: AudioStreamPlayer = AudioStreamPlayer.new()
		var l_stream: AudioStreamWAV = AudioStreamWAV.new()

		players.append(l_player)
		streams.append(l_stream)

		l_stream.format = AudioStreamWAV.FORMAT_16_BITS
		l_stream.stereo = true
		l_player.stream = l_stream


func set_audio(a_track: int, a_audio: PackedByteArray, a_frame: int) -> void:
	if a_audio.size() == 0 or RenderMenu.is_rendering:
		stop_audio(a_track)
		return

	streams[a_track].data = a_audio
	players[a_track].play(float(a_frame) / Project.framerate)
	players[a_track].stream_paused = !View.is_playing


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

