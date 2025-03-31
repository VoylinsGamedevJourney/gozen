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


func init_data(file_data_id: int) -> void:
	id = file_data_id

	var file: File = Project.get_file(id)

	if file.type == File.TYPE.IMAGE:
		if file.temp_file != null:
			image = file.temp_file.image_data
			return

		image = ImageTexture.create_from_image(Image.load_from_file(file.path))
	elif file.type == File.TYPE.VIDEO:
		video_meta = VideoMeta.new()

		# TODO: Re-implement the VideoMeta clas
		if !video_meta.load_meta(file.path):
			printerr("Failed loading video file meta data!")

		# Set necessary metadata
		resolution = video_meta.get_resolution()
		padding = video_meta.get_padding()
		uv_resolution = Vector2i(int((resolution.x + padding) / 2.), int(resolution.y / 2.))
		frame_count = video_meta.get_frame_count()
		framerate = video_meta.get_framerate()

		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_video_data.bind(file.path))))

		for i: int in 5:
			Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
						_load_video_data.bind(file.path))))

	if file.type in Editor.AUDIO_TYPES:
		Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
				_load_audio_data.bind(file.path)), create_wave))


func _load_audio_data(file_path: String) -> void:
	audio = AudioStreamWAV.new()
	audio.mix_rate = 44100
	audio.stereo = true
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.data = Audio.get_audio_data(file_path)


func _load_video_data(file_path: String) -> void:
	var video: Video = Video.new()

	if video.open(file_path):
		printerr("Couldn't open video at path '%s'!" % file_path)
		return

	Threader.mutex.lock()
	videos.append(video)
	if current_frame.append(0):
		printerr("Couldn't append to current frame!")
	Threader.mutex.unlock()


func create_wave() -> void:
	Threader.tasks.append(Threader.Task.new(WorkerThreadPool.add_task(
		_create_wave), update_wave.emit))


func _create_wave() -> void:
	var data: PackedByteArray = audio.data
	audio_wave_data.clear()

	if data.is_empty():
		push_warning("Audio data is empty!")
		return

	var bytes_size: float = 4 # 16 bit * stereo
	var total_frames: int = int(data.size() / bytes_size)
	var frames_per_block: int = floori(44100.0 / Project.get_framerate())
	var total_blocks: int = ceili(float(total_frames) / frames_per_block)
	var current_frame_index: int = 0

	if audio_wave_data.resize(total_blocks):
		Toolbox.print_resize_error()

	for i: int in total_blocks:
		var max_abs_amplitude: float = 0.0
		var start_frame: int = current_frame_index
		var end_frame: int = min(start_frame + frames_per_block, total_frames)

		for frame_index: int in range(start_frame, end_frame):
			var byte_offset: int = int(frame_index * bytes_size)
			var frame_max_abs_amplitude: float = 0.0

			if byte_offset + bytes_size > data.size():
				push_warning("Attempted to read past end of audio data at frame %d." % frame_index)
				break

			var left_sample: int = data.decode_s16(byte_offset)
			var right_sample: int = data.decode_s16(byte_offset + 2)

			frame_max_abs_amplitude = max(abs(float(left_sample)), abs(float(right_sample)))

			if frame_max_abs_amplitude > max_abs_amplitude:
				max_abs_amplitude = frame_max_abs_amplitude

		audio_wave_data[i] = clamp(max_abs_amplitude / MAX_16_BIT_VALUE, 0.0, 1.0)
		current_frame_index = end_frame

