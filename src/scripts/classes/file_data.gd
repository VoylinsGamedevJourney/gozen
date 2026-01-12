class_name FileData
extends RefCounted


signal video_loaded
signal update_wave


# For the audio 16 bits/2 (stereo)
const MAX_16_BIT_VALUE: float = 32767.0


var id: int

var video: GoZenVideo = null
var audio: AudioStreamFFmpeg = null
var image: Texture2D = null
var color: Color = Color.WHITE
var pck: PCK = null
var pck_scene_instance: Node = null

var audio_wave_data: PackedFloat32Array = []
var color_profile: Vector4 = Vector4.ZERO

var clip_only_video: Dictionary[int, GoZenVideo] = {} # { Clip id: Video }



func _update_duration() -> void:
	var l_file: File = FileHandler.get_file(id)

	match l_file.type:
		FileHandler.TYPE.IMAGE:
			l_file.duration = Settings.get_image_duration()
		FileHandler.TYPE.AUDIO:
			l_file.duration = floor(float(audio.data.size()) / (4 * 44101) * Project.get_framerate())
		FileHandler.TYPE.VIDEO:
			var frame_time: float = video.get_frame_count() / video.get_framerate()
			l_file.duration = floor(frame_time * Project.get_framerate())
		FileHandler.TYPE.COLOR:
			l_file.duration = Settings.get_color_duration()
		FileHandler.TYPE.TEXT:
			l_file.duration = Settings.get_text_duration()
		# TODO: Add duration for PCK file.

	if l_file.duration == 0:
		printerr("FileData: Something went wrong loading file '%s', duration is 0!" % id)


func init_data(file_data_id: int) -> bool:
	id = file_data_id

	var file: File = FileHandler.get_file(id)
	if file == null:
		printerr("FileData: Can't init data as file %s is null!")
		return false

	if file.path == "temp://color":
		file.temp_file.load_image_from_color()
		image = file.temp_file.image_data
	elif file.path == "temp://image":
		image = file.temp_file.image_data
	elif file.type == FileHandler.TYPE.IMAGE:
		image = ImageTexture.create_from_image(Image.load_from_file(file.path))
	elif file.type == FileHandler.TYPE.VIDEO:
		Threader.add_task(_load_video_data.bind(file.path), video_loaded.emit)
	elif file.type == FileHandler.TYPE.PCK:
		if !ProjectSettings.load_resource_pack(file.path):
			printerr("FileData: Something went wrong loading pck data from '%s'!" % file.path)
			return false
		# TODO: Check the path to see if there is an actual folder with the data.
		# TODO: Set the pck_instance correctly.
		pck = load(PCK.MODULES_PATH + file.path.get_basename().to_lower())
		pck_scene_instance = pck.scene.instantiate()

	if file.type in EditorCore.AUDIO_TYPES:
		_load_audio_data(file.path)
		Threader.add_task(_create_wave.bind(file.path), Callable())

	return true


func _load_audio_data(file_path: String) -> void:
	var stream: AudioStreamFFmpeg = AudioStreamFFmpeg.new()
	var error: int = stream.open(file_path)

	if error != OK:
		printerr("FileData: Failed to open audio '%s'!" % file_path)
		return

	audio = stream


func _load_video_data(file_path: String) -> void:
	var temp_video: GoZenVideo = GoZenVideo.new()
	var placeholder: PlaceholderTexture2D = PlaceholderTexture2D.new()

	if temp_video.open(file_path):
		printerr("FileData: Couldn't open video at path '%s'!" % file_path)
		return
	placeholder.size = temp_video.get_resolution()

	if abs(temp_video.get_rotation()) == 90:
		placeholder.size = Vector2(placeholder.size.y, placeholder.size.x)
	else:
		placeholder.size = Vector2(placeholder.size.x, placeholder.size.y)

	match temp_video.get_color_profile():
		"bt601", "bt470": color_profile = Vector4(1.402, 0.344136, 0.714136, 1.772)
		"bt2020", "bt2100": color_profile = Vector4(1.4746, 0.16455, 0.57135, 1.8814)
		_: # bt709 and unknown.
			color_profile = Vector4(1.5748, 0.1873, 0.4681, 1.8556)

	# Loading the clip only video data
	var file: File = FileHandler.get_file(id)

	for clip_id: int in file.clip_only_video_ids:
		if ClipHandler.has_clip(clip_id):
			var clip_video: GoZenVideo = GoZenVideo.new()

			if clip_video.open(file_path) == OK:
				Threader.mutex.lock()
				clip_only_video[clip_id] = clip_video
				Threader.mutex.unlock()
			else:
				printerr("FileData: Failed to create a clip only video instance for clip id: ", clip_id)
		else:
			var clip_id_index: int = file.clip_only_video_ids.find(clip_id)

			Threader.mutex.lock()
			file.clip_only_video_ids.remove_at(clip_id_index)
			Threader.mutex.unlock()

	Threader.mutex.lock()
	video = temp_video
	image = placeholder
	Threader.mutex.unlock()


func _create_wave(file_path: String) -> void:
	# TODO: Large audio lengths will still crash this function. Could possibly
	# use the get_audio improvements by cutting the data into pieces.
	var data: PackedByteArray = GoZenAudio.get_audio_data(file_path, -1)

	audio_wave_data.clear()

	if data.is_empty():
		push_warning("Audio data is empty!")
		return

	var bytes_size: float = 4 # 16 bit * stereo
	var total_frames: int = int(data.size() / bytes_size)
	var frames_per_block: int = floori(44100.0 / Project.get_framerate())
	var total_blocks: int = ceili(float(total_frames) / frames_per_block)
	var current_frame_index: int = 0

	audio_wave_data.resize(total_blocks)

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

		# Incase we close the editor whilst wave data is still being created.
		if audio_wave_data.size() == 0:
			return

		audio_wave_data[i] = clamp(max_abs_amplitude / MAX_16_BIT_VALUE, 0.0, 1.0)
		current_frame_index = end_frame


func generate_audio_thumb() -> Image:
	if !audio_wave_data.size():
		await update_wave
		
	var size: Vector2i = Vector2i(854, 480)
	var thumb: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)

	var data_per_pixel: float = float(audio_wave_data.size()) / size.x
	var center: int = int(float(size.y) / 2)
	var amp: int = int(float(size.y) / 2 * 0.9)

	thumb.fill(Color.DIM_GRAY) # Background color.
	for x_pos: int in size.x: # Data color.
		var start_index: int = floori(x_pos * data_per_pixel)
		var end_index: int = min(ceili((x_pos + 1) * data_per_pixel), audio_wave_data.size())

		if start_index >= end_index:
			continue # No data/End of data

		var max_amp: float = 0.0
		for i: int in range(start_index, end_index):
			max_amp = max(max_amp, audio_wave_data[i])

		var half_height: int = floori(max_amp * amp)
		var y_top: int = clamp(center - half_height, 0, size.y - 1)
		var y_bottom: int = clamp(center + half_height, 0, size.y - 1)

		for y_pos: int in range(y_top, y_bottom + 1):
			thumb.set_pixel(x_pos, y_pos, Color.GHOST_WHITE)

	for x_pos: int in size.x: # Center line.
		thumb.set_pixel(x_pos, center, Color.GRAY)
	
	return thumb

