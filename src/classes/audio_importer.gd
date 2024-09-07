class_name AudioImporter
extends Node


enum ERROR {
	OK = 0,
	BAD_EXTENSION,
	NO_RIFF, NO_WAVE, NO_FMT,
	NO_FORMAT_SUPPORT, NO_DATA,
	NO_24_SUPPORT, NO_32_SUPPORT,
	ZERO_SAMPLES,
}


static var debug: bool = false
static var last_error: ERROR = ERROR.OK


static func load(a_path: String) -> AudioStream:
	match a_path.get_extension().to_lower():
		"ogg":
			return load_ogg(a_path)
		"mp3":
			return load_mp3(a_path)
		"wav":
			return load_wav(a_path)
		_: 
			last_error = ERROR.BAD_EXTENSION
			return null


static func load_ogg(a_path: String) -> AudioStreamOggVorbis:
	last_error = ERROR.OK
	return AudioStreamOggVorbis.load_from_file(a_path)


static func load_mp3(a_path: String) -> AudioStreamMP3:
	last_error = ERROR.OK
	var l_stream: AudioStreamMP3 = AudioStreamMP3.new()
	l_stream.data = FileAccess.get_file_as_bytes(a_path)
	return l_stream
	


static func load_wav(a_path: String) -> AudioStream:
	last_error = ERROR.OK
	var l_bytes: PackedByteArray = FileAccess.get_file_as_bytes(a_path)
	var l_stream: AudioStreamWAV = AudioStreamWAV.new()
	var l_samples: int = 0

	# Checking RIFF chunk
	if l_bytes.slice(0, 4).get_string_from_utf8() != "RIFF":
		last_error = ERROR.NO_RIFF
		return null
	if l_bytes.slice(8, 12).get_string_from_utf8() != "WAVE":
		last_error = ERROR.NO_WAVE
		return null

	# Checking fmt
	if l_bytes.slice(12, 16).get_string_from_utf8() != "fmt ":
		last_error = ERROR.NO_FMT
		return null
	
	l_stream.format = l_bytes.decode_s16(20) as AudioStreamWAV.Format
	if not l_stream.format in [0,1,2]:
		l_stream.format = 1  as AudioStreamWAV.Format
	elif l_stream.format == 2:
		last_error = ERROR.NO_FORMAT_SUPPORT
		return null
	l_stream.stereo = l_bytes.decode_s16(22) == 2
	l_stream.mix_rate = l_bytes.decode_s64(24)
	l_samples = l_bytes.decode_s16(34)

	# Getting the data
	if l_bytes.slice(36, 40).get_string_from_utf8() != "data":
		last_error = ERROR.NO_DATA
		return null
	elif l_samples == 0:
		last_error = ERROR.ZERO_SAMPLES
		return null

	l_stream.data = l_bytes.slice(40, 40 + l_bytes.decode_s64(40))
	if l_samples == 24:
		last_error = ERROR.NO_24_SUPPORT
		return null
	elif l_samples == 32:
		last_error = ERROR.NO_32_SUPPORT
		printerr("32 bit audio not supported right now!")
		return null

	return l_stream


