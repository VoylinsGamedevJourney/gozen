class_name FileData
extends Node


signal update_wave


# For the audio 16 bits/2 (stereo)
const MAX_16_BIT_VALUE: float = 32767.0


var id: int


var videos: Array[Video] = []
var video_meta: VideoMeta = null
var audio: AudioStreamWAV = null
var image: ImageTexture = null

var current_frame: PackedInt64Array = []

var audio_wave_data: PackedFloat32Array = []

var padding: int = 0
var resolution: Vector2i = Vector2i.ZERO
var uv_resolution: Vector2i = Vector2i.ZERO
var frame_count: int = 0
var framerate: float = 0.0



func _update_duration() -> void:
	var l_file: File = Project.get_file(id)

	match l_file.type:
		File.TYPE.IMAGE:
			l_file.duration = Settings.get_image_duration()
		File.TYPE.AUDIO:
			l_file.duration = floor(float(audio.data.size()) / (4 * 44101) * Project.get_framerate())
		File.TYPE.VIDEO:
			l_file.duration = floor(floor(video_meta.get_frame_count() /
					video_meta.get_framerate()) * Project.get_framerate())

	if l_file.duration == 0:
		printerr("Something went wrong loading file '%s', duration is 0!" % id)


func init_data(a_id: int) -> void:
	id = a_id

	var l_file: File = Project.get_file(id)

	if l_file.type == File.TYPE.IMAGE:
		if l_file.temp_file != null:
			image = l_file.temp_file.image_data
			return

		image = ImageTexture.create_from_image(Image.load_from_file(l_file.path))
	elif l_file.type == File.TYPE.VIDEO:
		video_meta = VideoMeta.new()

		if video_meta.load_meta(l_file.path):
			printerr("Failed loading video file meta data!")

		# Set necessary metadata
		resolution = video_meta.get_resolution()
		padding = video_meta.get_padding()
		uv_resolution = Vector2i(int((resolution.x + padding) / 2.), int(resolution.y / 2.))
		frame_count = video_meta.get_frame_count()
		framerate = video_meta.get_framerate()

		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_video_data.bind(l_file.path))))

		for i: int in 5:
			Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
						_load_video_data.bind(l_file.path))))

	if l_file.type in Editor.AUDIO_TYPES:
		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_audio_data.bind(l_file.path)), create_wave))


func _load_audio_data(a_file_path: String) -> void:
	audio = AudioStreamWAV.new()
	audio.mix_rate = 44100
	audio.stereo = true
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.data = Audio.get_audio_data(a_file_path)


func _load_video_data(a_file_path: String) -> void:
	var l_video: Video = Video.new()

	if l_video.open(a_file_path):
		printerr("Couldn't open video at path '%s'!" % a_file_path)
		return

	Threader.mutex.lock()
	videos.append(l_video)
	if current_frame.append(0):
		printerr("Couldn't append to current frame!")
	Threader.mutex.unlock()


func create_wave() -> void:
	Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
		_create_wave), update_wave.emit))


func _create_wave() -> void:
	var l_data: PackedByteArray = audio.data
	audio_wave_data.clear()

	if l_data.is_empty():
		push_warning("Audio data is empty!")
		return

	var l_bytes_size: float = 4 # 16 bit * stereo
	var l_total_frames: int = int(l_data.size() / l_bytes_size)
	var l_frames_per_block: int = floori(44100.0 / Project.get_framerate())
	var l_total_blocks: int = ceili(float(l_total_frames) / l_frames_per_block)
	var l_current_frame_index: int = 0

	if audio_wave_data.resize(l_total_blocks):
		Toolbox.print_resize_error()

	for i: int in l_total_blocks:
		var l_max_abs_amplitude: float = 0.0
		var l_start_frame: int = l_current_frame_index
		var l_end_frame: int = min(l_start_frame + l_frames_per_block, l_total_frames)

		for l_frame_index: int in range(l_start_frame, l_end_frame):
			var l_byte_offset: int = int(l_frame_index * l_bytes_size)
			var l_frame_max_abs_amplitude: float = 0.0

			if l_byte_offset + l_bytes_size > l_data.size():
				push_warning("Attempted to read past end of audio data at frame %d." % l_frame_index)
				break

			var l_left_sample: int = l_data.decode_s16(l_byte_offset)
			var l_right_sample: int = l_data.decode_s16(l_byte_offset + 2)

			l_frame_max_abs_amplitude = max(abs(float(l_left_sample)), abs(float(l_right_sample)))

			if l_frame_max_abs_amplitude > l_max_abs_amplitude:
				l_max_abs_amplitude = l_frame_max_abs_amplitude

		audio_wave_data[i] = clamp(l_max_abs_amplitude / MAX_16_BIT_VALUE, 0.0, 1.0)
		l_current_frame_index = l_end_frame

