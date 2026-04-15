extends Node


signal update_encoder_status(status: STATUS)


enum STATUS { ## The progress amounts.
	ERROR_OPEN = -1,
	ERROR_AUDIO = -2,
	ERROR_CANCELED = -3,
	SETUP = 0,
	COMPILING_AUDIO = 3,
	SENDING_AUDIO = 4,
	SENDING_FRAMES = 5,
	FRAMES_SEND = 6,
	LAST_FRAMES = 99,
	FINISHED = 100,
}


const MIX_RATE: float = 44100.0
const AUDIO_MIN: int = -32768
const AUDIO_MAX: int = 32767


var project_data: ProjectData
var encoder: Encoder
var viewport: ViewportTexture

var cancel_encoding: bool = false
var start_time: int = 0
var encoding_time: int = 0

var buffer_size: int = 5
var frame_queue: Array[PackedByteArray] = []
var thread: Thread

var rendering_device: RenderingDevice
var yuv_shader: RID
var yuv_pipeline: RID
var yuv_output_tex: RID
var yuv_sampler: RID
var yuv_params_buffer: RID
var yuv_input_texture: RID

var proxies_used: bool
var original_vsync_mode: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED
var original_video_frame_cache_size: int = 30

var stop_encoding: bool = false


var _audio_cache: Dictionary = {}



func _ready() -> void:
	@warning_ignore("return_value_discarded")
	Project.project_ready.connect(_on_project_ready)


func _on_project_ready() -> void:
	project_data = Project.data


# --- Render logic ---

func start_encoder(start_frame: int = 0, end_frame: int = -1) -> void:
	if end_frame == -1:
		end_frame = project_data.timeline_end
	if encoder != null and encoder.is_open():
		return printerr("RenderManager: Can't encode whilst another encoder is still busy!")
	if viewport == null:
		viewport = EditorCore.viewport.get_texture()

	# VSync stuff.
	original_vsync_mode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	original_video_frame_cache_size = Settings.get_video_cache_size()
	Settings.set_video_cache_size(0)

	# Making certain proxies aren't being used for this
	proxies_used = Settings.get_use_proxies()
	if proxies_used:
		Settings.set_use_proxies(false)
		# Necessary waiting time to make certain all clips are ready.
		await RenderingServer.frame_post_draw
		await get_tree().process_frame

	# Setup encoder.
	update_encoder_status.emit(STATUS.SETUP)
	await RenderingServer.frame_post_draw
	start_time = Time.get_ticks_msec()
	encoding_time = 0

	if !encoder.open(viewport.get_image().get_format() == Image.FORMAT_RGBA8):
		stop_encoder()
		update_encoder_status.emit(STATUS.ERROR_OPEN)
		await RenderingServer.frame_post_draw
		return printerr("RenderManager: Couldn't open encoder!")

	# Creating + sending audio.
	if encoder.audio_codec_set():
		update_encoder_status.emit(STATUS.COMPILING_AUDIO)
		await RenderingServer.frame_post_draw

		var audio_thread: Thread = Thread.new()
		if !audio_thread.start(_encode_and_send_audio.bind(start_frame, end_frame)):
			printerr("RenderManager: Couldn't start audio thread!")
			stop_encoder()
			update_encoder_status.emit(STATUS.ERROR_AUDIO)
			await RenderingServer.frame_post_draw
			return
		while audio_thread.is_alive():
			await get_tree().process_frame

		var success: bool = audio_thread.wait_to_finish()
		if cancel_encoding:
			stop_encoder()
			update_encoder_status.emit(STATUS.ERROR_CANCELED)
			await RenderingServer.frame_post_draw
			return
		if !success:
			stop_encoder()
			update_encoder_status.emit(STATUS.ERROR_AUDIO)
			await RenderingServer.frame_post_draw
			return printerr("RenderManager: Something went wrong encoding/sending audio!")

	# RGBA to YUV shader setup.
	if !rendering_device:
		rendering_device = RenderingServer.get_rendering_device()
	var render_resolution: Vector2i = Project.data.resolution
	var shader_file: RDShaderFile = load("res://effects/shaders/rgba_to_yuv.glsl")
	yuv_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv())
	yuv_pipeline = rendering_device.compute_pipeline_create(yuv_shader)

	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.width = render_resolution.x
	texture_format.height = int(render_resolution.y * 1.5)
	texture_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	yuv_output_tex = rendering_device.texture_create(texture_format, RDTextureView.new())
	yuv_sampler = rendering_device.sampler_create(RDSamplerState.new())

	var input_format: RDTextureFormat = RDTextureFormat.new()
	input_format.width = render_resolution.x
	input_format.height = render_resolution.y
	input_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	input_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	yuv_input_texture = rendering_device.texture_create(input_format, RDTextureView.new())

	# BT709 Limited range matrix.
	var bt709_rgb_to_yuv: PackedFloat32Array = PackedFloat32Array([
		0.182586, -0.100642,  0.439216, 0.0,
		0.614231, -0.338574, -0.398942, 0.0,
		0.062007,  0.439216, -0.040276, 0.0,
		0.062745,  0.500000,  0.500000, 1.0 ])
	var params_bytes: PackedByteArray = PackedByteArray()
	if params_bytes.resize(80):
		printerr("RenderManager: Couldn't resize params_bytes array!")

	for index: int in 16:
		params_bytes.encode_float(index * 4, bt709_rgb_to_yuv[index])

	params_bytes.encode_s32(64, render_resolution.x)
	params_bytes.encode_s32(68, render_resolution.y)
	yuv_params_buffer = rendering_device.uniform_buffer_create(params_bytes.size(), params_bytes)

	# Sending the video frame data.
	update_encoder_status.emit(STATUS.SENDING_FRAMES)

	frame_queue.clear()
	stop_encoding = false
	thread = Thread.new()
	if !thread.start(_encoding_loop):
		printerr("RenderManager: Couldn't start encoder thread!")
		stop_encoder()
		update_encoder_status.emit(STATUS.ERROR_CANCELED)
		await EditorCore.frame_changed
		return

	# Because of labels and other draw() stuff which takes a frame to show, we
	# need to prepare the data in one frame and show it in the next frame.
	EditorCore.frame_nr = start_frame # We set the first frame data ready.
	if EditorCore.data_ready:
		await EditorCore.frame_changed # View should be ready.
	EditorCore.frame_nr = start_frame + 1 # We prepare the second frame data directly.

	for i: int in range(start_frame, end_frame + 1):
		if cancel_encoding:
			break

		await get_tree().process_frame
		var frame_data: PackedByteArray = _convert_rgba_to_yuv(viewport.get_rid(), render_resolution)
		var frame_pushed: bool = false
		while not frame_pushed and not cancel_encoding:
			if not thread.is_alive():
				break # Error happened in Encoder.

			Threader.mutex.lock()
			if frame_queue.size() < buffer_size: # Limiting RAM usage.
				frame_queue.append(frame_data)
				frame_pushed = true
			Threader.mutex.unlock()
			if frame_pushed:
				Threader.semaphore.post()
			else:
				await get_tree().process_frame

		if i + 1 <= end_frame:
			if EditorCore.data_ready:
				await EditorCore.frame_changed
			if i + 2 <= end_frame:
				EditorCore.frame_nr = i + 2

	# Flushing the system.
	stop_encoding = true
	Threader.semaphore.post() # Wake up Encoder one last time to flush.
	if thread.is_started():
		while thread.is_alive():
			await get_tree().process_frame
		thread.wait_to_finish()

	if cancel_encoding:
		update_encoder_status.emit(STATUS.ERROR_CANCELED)
		await RenderingServer.frame_post_draw
		return stop_encoder()

	encoding_time = Time.get_ticks_msec() - start_time
	update_encoder_status.emit(STATUS.FINISHED)
	await RenderingServer.frame_post_draw
	NotificationManager.notify("Render finished!")
	stop_encoder()


func stop_encoder() -> void:
	if encoder.is_open():
		encoder.close()
	if proxies_used:
		Settings.set_use_proxies(true)
	cancel_encoding = false
	_audio_cache.clear()

	Threader.mutex.lock()
	frame_queue.clear()
	Threader.mutex.unlock()

	DisplayServer.window_set_vsync_mode(original_vsync_mode)
	Settings.set_video_cache_size(original_video_frame_cache_size)

	if rendering_device:
		if yuv_pipeline.is_valid():
			rendering_device.free_rid(yuv_pipeline)
			yuv_pipeline = RID()
		if yuv_shader.is_valid():
			rendering_device.free_rid(yuv_shader)
			yuv_shader = RID()
		if yuv_output_tex.is_valid():
			rendering_device.free_rid(yuv_output_tex)
			yuv_output_tex = RID()
		if yuv_sampler.is_valid():
			rendering_device.free_rid(yuv_sampler)
			yuv_sampler = RID()
		if yuv_params_buffer.is_valid():
			rendering_device.free_rid(yuv_params_buffer)
			yuv_params_buffer = RID()
		if yuv_input_texture.is_valid():
			rendering_device.free_rid(yuv_input_texture)
			yuv_input_texture = RID()


func _encoding_loop() -> void:
	while true:
		Threader.semaphore.wait()
		Threader.mutex.lock()
		var has_frames: bool = not frame_queue.is_empty()
		var frame_data: PackedByteArray = PackedByteArray()
		if has_frames:
			frame_data = frame_queue.pop_front()
		update_encoder_status.emit.call_deferred(STATUS.FRAMES_SEND)
		Threader.mutex.unlock()

		if not frame_data.is_empty():
			if not encoder.send_frame(frame_data):
				call_deferred("stop_encoder")
				printerr("RenderManager: Something went wrong sending frame(s)!")
				break # Error happened in encoder.
		if stop_encoding:
			Threader.mutex.lock()
			var is_empty: bool = frame_queue.is_empty()
			Threader.mutex.unlock()
			if is_empty:
				update_encoder_status.emit.call_deferred(STATUS.LAST_FRAMES)
				encoder.close()
				break


# --- Audio handling ---

func _encode_and_send_audio(start_frame: int, end_frame: int) -> bool:
	_prepare_audio_cache(start_frame, end_frame)
	if cancel_encoding:
		return false
	var audio_data: PackedByteArray = encode_audio(start_frame, end_frame)
	_audio_cache.clear() # Clear cache immediately to free up RAM before video rendering.

	if cancel_encoding or !audio_data or audio_data.is_empty():
		return false

	update_encoder_status.emit.call_deferred(STATUS.SENDING_AUDIO)
	if !encoder.send_audio(audio_data):
		return false
	return true


func _prepare_audio_cache(start_frame: int, end_frame: int) -> void:
	_audio_cache.clear()
	var file_counts: Dictionary = {}
	var file_min_start: Dictionary = {}
	var file_max_end: Dictionary = {}

	for track: int in TrackLogic.tracks.size():
		if TrackLogic.tracks[track].is_muted: continue
		for clip: ClipData in TrackLogic.track_clips[track].clips:
			if clip.start > end_frame or clip.end < start_frame or clip.effects.is_muted:
				continue
			elif clip.type in EditorCore.AUDIO_TYPES:
				var info: Dictionary = _get_clip_audio_info(clip)
				var path: String = info.path
				file_counts[path] = file_counts.get(path, 0) + 1

				var framerate: float = project_data.framerate
				var region_start_frames: int = maxi(clip.start, start_frame)
				var region_end_frames: int = mini(clip.end, end_frame + 1)
				var start_offset_frames: int = region_start_frames - clip.start
				var region_duration_frames: int = region_end_frames - region_start_frames

				var required_start: float = info.start + (float(start_offset_frames) / framerate * clip.speed)
				var required_end: float = required_start + (float(region_duration_frames) / framerate * clip.speed)

				if !file_min_start.has(path) or required_start < file_min_start[path]:
					file_min_start[path] = required_start
				if !file_max_end.has(path) or required_end > file_max_end[path]:
					file_max_end[path] = required_end

	var sorted_files: Array = file_counts.keys()
	sorted_files.sort_custom(func(a: String, b: String) -> bool: return file_counts[a] > file_counts[b])

	var cache_limit: int = 3
	var cached_count: int = 0
	for path: String in sorted_files:
		if cancel_encoding or cached_count >= cache_limit: break
		elif file_counts[path] > 1: # Only cache if it's re-used across multiple clips.
			var frame_start: float = maxf(0.0, file_min_start[path] as float)
			var frame_duration: float = file_max_end[path] - frame_start
			_audio_cache[path] = {
				"data": Audio.get_audio_data(path, -1, frame_start, frame_duration),
				"start_time": frame_start
			}
			cached_count += 1


func _get_clip_audio_info(clip: ClipData) -> Dictionary:
	var framerate: float = project_data.framerate
	var start_sec: float = float(clip.begin) / framerate
	var duration_sec: float = float(clip.duration) / framerate
	var file_path: String

	if clip.effects.ato_active and clip.effects.ato_file != -1:
		start_sec -= clip.effects.ato_offset
		file_path = FileLogic.files[clip.effects.ato_file].path
	else:
		var target_file: FileData = FileLogic.files[clip.file]
		if target_file.ato_active and target_file.ato_file != -1:
			start_sec -= target_file.ato_offset
			file_path = FileLogic.files[target_file.ato_file].path
		else:
			file_path = target_file.path

	return { "path": file_path, "start": start_sec, "duration": duration_sec }


func encode_audio(start_frame: int = 0, end_frame: int = -1) -> PackedByteArray:
	if end_frame == -1: end_frame = project_data.timeline_end
	var audio: PackedByteArray = []
	var framerate: float = project_data.framerate
	var total_frames: int = end_frame - start_frame + 1
	var length: int = Utils.get_sample_count(total_frames, framerate)
	if audio.resize(length):
		printerr("RenderManager: Couldn't resize audio PackedByteArray for encoding!")

	for track: int in TrackLogic.tracks.size():
		if cancel_encoding:
			break
		if !TrackLogic.tracks[track].is_muted:
			for clip: ClipData in TrackLogic.track_clips[track].clips:
				if cancel_encoding:
					break
				if clip.start > end_frame or clip.end < start_frame or clip.effects.is_muted:
					continue
				if clip.type in EditorCore.AUDIO_TYPES:
					audio = _handle_audio(clip, audio, start_frame, end_frame)

	return audio


func _handle_audio(clip: ClipData, master_audio: PackedByteArray, region_start: int, region_end: int) -> PackedByteArray:
	if cancel_encoding:
		return master_audio
	var framerate: float = project_data.framerate
	var samples_per_frame: float = MIX_RATE / framerate

	var info: Dictionary = _get_clip_audio_info(clip)

	var clip_render_start: int = maxi(clip.start, region_start)
	var clip_render_end: int = mini(clip.end, region_end + 1)
	var render_frames: int = clip_render_end - clip_render_start
	if render_frames <= 0:
		return master_audio

	var offset_in_clip_frames: int = clip_render_start - clip.start
	var required_start_sec: float = info.start + (float(offset_in_clip_frames) / framerate * clip.speed)
	var required_duration_sec: float = float(render_frames) / framerate * clip.speed

	var audio_data: PackedByteArray

	if _audio_cache.has(info.path):
		var cache_dict: Dictionary = _audio_cache[info.path]
		var cached_data: PackedByteArray = cache_dict["data"]
		var cache_start_time: float = cache_dict["start_time"]

		var relative_start_sec: float = required_start_sec - cache_start_time
		var start_bytes: int = floori(relative_start_sec * MIX_RATE) * 4
		var duration_bytes: int = floori(required_duration_sec * MIX_RATE) * 4

		if start_bytes < 0:
			var silence_bytes: int = abs(start_bytes)
			if audio_data.resize(silence_bytes):
				printerr("RenderManager: Couldn't resize audio PackedByteArray for adding silence_bytes!")
			var slice_start: int = 0
			var slice_end: int = mini(duration_bytes - silence_bytes, cached_data.size())
			if slice_end > 0:
				audio_data.append_array(cached_data.slice(slice_start, slice_end))
		else:
			var slice_end: int = mini(start_bytes + duration_bytes, cached_data.size())
			if start_bytes < cached_data.size():
				audio_data = cached_data.slice(start_bytes, slice_end)

		if audio_data.size() < duration_bytes and audio_data.resize(duration_bytes):
			printerr("RenderManager: Couldn't resize audio PackedByteArray for adding end bytes!")
	else:
		audio_data = Audio.get_audio_data(info.path as String, -1, required_start_sec, required_duration_sec)

	if audio_data.is_empty():
		return master_audio

	# First apply fades utilizing offset indices.
	var fade_in: int = clip.effects.fade_audio.x
	var fade_out: int = clip.effects.fade_audio.y
	if fade_in > 0 or fade_out > 0:
		var fade_in_samples: int = floori(fade_in * samples_per_frame)
		var fade_out_samples: int = floori(fade_out * samples_per_frame)
		var start_sample: int = floori(offset_in_clip_frames * samples_per_frame)
		var total_samples: int = floori(clip.duration * samples_per_frame)
		audio_data = Audio.apply_fade(audio_data, fade_in_samples, fade_out_samples, start_sample, total_samples)

	# Apply all other effects to the clip audio data.
	for effect: EffectAudio in clip.effects.audio:
		if !effect.is_enabled:
			continue

		match effect.id:
			"volume": audio_data = _apply_effect_volume(audio_data, effect, offset_in_clip_frames)
			"volume": audio_data = _apply_effect_volume(audio_data, effect, offset_in_clip_frames)
			_: printerr("RenderManager: Unknown effect '%s'!" % effect.nickname)

	# Place in correct position natively using combine offset relative to render region.
	return Audio.combine_data(
			master_audio,	audio_data,
			Utils.get_sample_count(clip_render_start - region_start, framerate))


func _apply_effect_volume(audio_data: PackedByteArray, effect: EffectAudio, offset_frames: int) -> PackedByteArray:
	var sample_count: int = floori(audio_data.size() / 4.0) # 16 bit stereo.
	var framerate: float = project_data.framerate
	var volume_param: EffectParam = effect.params[0]

	var samples_per_frame: int = ceili(MIX_RATE / framerate)
	var frame_count: int = ceili(float(sample_count) / samples_per_frame)

	var frame_volumes: PackedFloat32Array = PackedFloat32Array()
	if frame_volumes.resize(frame_count):
		printerr("RenderManager: Couldn't resize frame volumes array!")

	var all_one: bool = true
	for frame: int in frame_count:
		if cancel_encoding:
			break
		var actual_frame: int = frame + offset_frames
		var volume_db: float = effect.get_value(volume_param, actual_frame)
		var volume_linear: float = db_to_linear(volume_db)
		frame_volumes[frame] = volume_linear
		if not is_equal_approx(volume_linear, 1.0):
			all_one = false

	if all_one:
		return audio_data
	return Audio.apply_dynamic_volume(audio_data, frame_volumes, MIX_RATE, framerate)


# --- RGBA to YUV handling ---

func _convert_rgba_to_yuv(input_texture_rid: RID, res: Vector2i) -> PackedByteArray:
	var rd_input_tex: RID = RenderingServer.texture_get_rd_texture(input_texture_rid)
	if rendering_device.texture_copy(rd_input_tex, yuv_input_texture, Vector3.ZERO, Vector3.ZERO, Vector3(res.x, res.y, 1), 0, 0, 0, 0):
		printerr("RenderManager: Failed to copy texture in rendering device to convert RGBA to YUV!")

	var uniform_input: RDUniform = RDUniform.new()
	uniform_input.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform_input.binding = 0
	uniform_input.add_id(yuv_sampler)
	uniform_input.add_id(yuv_input_texture)

	var uniform_output: RDUniform = RDUniform.new()
	uniform_output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_output.binding = 1
	uniform_output.add_id(yuv_output_tex)

	var uniform_params: RDUniform = RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform_params.binding = 2
	uniform_params.add_id(yuv_params_buffer)

	var uniform_set: RID = rendering_device.uniform_set_create([uniform_input, uniform_output, uniform_params], yuv_shader, 0)
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, yuv_pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rendering_device.compute_list_dispatch(compute_list, ceili(res.x / 8.0), ceili(res.y / 8.0), 1)
	rendering_device.compute_list_end()
	rendering_device.free_rid(uniform_set)
	return rendering_device.texture_get_data(yuv_output_tex, 0)
