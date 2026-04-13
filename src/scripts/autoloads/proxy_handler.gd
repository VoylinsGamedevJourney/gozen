extends Node
# TODO: We should make it possible to have a UI to see all the proxy clips
# with how much data they use and maybe with when they were last accessed.


signal proxy_loading(file: FileData, progress: int) ## Progess is 0/100.


const PROXY_HEIGHT: int = 540



func _ready() -> void:
	var proxy_path: String = Settings.get_proxies_path()
	if !DirAccess.dir_exists_absolute(proxy_path):
		DirAccess.make_dir_absolute(proxy_path)


func request_generation(file: FileData) -> void:
	var proxy_path: String = Settings.get_proxies_path()
	if file.type != EditorCore.TYPE.VIDEO:
		return # Only proxies for videos possible.
	var new_path: String = proxy_path.path_join(_create_proxy_name(file.path))

	# Check if already exists, if yes, we link.
	if !FileAccess.file_exists(new_path):
		return Threader.add_task(
				_generate_proxy_task.bind(file, new_path),
				_on_proxy_finished.bind(file))

	FileLogic.set_proxy_path(file, new_path)
	if Settings.get_use_proxies():
		FileLogic.reload(file)


func delete_proxy(file: FileData) -> void:
	if !file.proxy_path.is_empty():
		DirAccess.remove_absolute(file.proxy_path)
		FileLogic.set_proxy_path(file, "")


func _generate_proxy_task(file: FileData, output_path: String) -> void:
	var global_output_path: String = ProjectSettings.globalize_path(output_path)
	var global_input_path: String = ProjectSettings.globalize_path(file.path)
	var encoder: Encoder = Encoder.new()
	var video: Video = Video.new()
	if video.open(global_input_path) != OK:
		return printerr("ProxyHandler: Failed to open source!")

	var original_resolution: Vector2i = video.get_resolution()
	var scale: float = float(PROXY_HEIGHT) / float(original_resolution.y)
	var target_resolution: Vector2i = Vector2i(int(original_resolution.x * scale), PROXY_HEIGHT)
	if target_resolution.x % 2 != 0:
		target_resolution.x += 1 # Width needs to be equal

	# Encoder setup
	encoder.set_file_path(global_output_path)
	encoder.set_resolution(target_resolution)
	encoder.set_framerate(video.get_framerate())
	encoder.set_audio_codec_id(Encoder.AUDIO_CODEC.A_NONE) # Only visual is needed
	encoder.set_video_codec_id(Encoder.VIDEO_CODEC.V_H264)
	encoder.set_h264_preset(Encoder.H264_PRESETS.H264_PRESET_ULTRAFAST)
	encoder.set_crf(32)

	if !encoder.open(true):
		printerr("ProxyHandler: Failed to open encoder!")
		return video.close()

	# RGBA to YUV stuff.
	var rendering_device: RenderingDevice = RenderingServer.get_rendering_device()
	var shader_file: RDShaderFile = load("res://effects/shaders/rgba_to_yuv.glsl")
	var rd_yuv_shader: RID = rendering_device.shader_create_from_spirv(shader_file.get_spirv())
	var rd_yuv_pipeline: RID = rendering_device.compute_pipeline_create(rd_yuv_shader)

	var format_in: RDTextureFormat = RDTextureFormat.new()
	format_in.width = target_resolution.x
	format_in.height = target_resolution.y
	format_in.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format_in.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var input_tex: RID = rendering_device.texture_create(format_in, RDTextureView.new())

	var format_out: RDTextureFormat = RDTextureFormat.new()
	format_out.width = target_resolution.x
	format_out.height = int(target_resolution.y * 1.5)
	format_out.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	format_out.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var yuv_output_tex: RID = rendering_device.texture_create(format_out, RDTextureView.new())

	# BT709 limited matrix. (This should be equal to the RenderManager's matrix).
	var bt709_rgb_to_yuv: PackedFloat32Array = PackedFloat32Array([
			0.182586, -0.100642,  0.439216, 0.0,
			0.614231, -0.338574, -0.398942, 0.0,
			0.062007,  0.439216, -0.040276, 0.0,
			0.062745,  0.500000,  0.500000, 1.0 ])
	var yuv_sampler: RID = rendering_device.sampler_create(RDSamplerState.new())
	var params_bytes: PackedByteArray = PackedByteArray()
	params_bytes.resize(80)
	for index: int in 16:
		params_bytes.encode_float(index * 4, bt709_rgb_to_yuv[index])
	params_bytes.encode_s32(64, target_resolution.x)
	params_bytes.encode_s32(68, target_resolution.y)
	var yuv_params_buffer: RID = rendering_device.uniform_buffer_create(params_bytes.size(), params_bytes)

	var uniform_input: RDUniform = RDUniform.new()
	uniform_input.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform_input.binding = 0
	uniform_input.add_id(yuv_sampler)
	uniform_input.add_id(input_tex)

	var uniform_output: RDUniform = RDUniform.new()
	uniform_output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_output.binding = 1
	uniform_output.add_id(yuv_output_tex)

	var uniform_params: RDUniform = RDUniform.new()
	uniform_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform_params.binding = 2
	uniform_params.add_id(yuv_params_buffer)

	# Encoding of the proxy.
	var uniform_set: RID = rendering_device.uniform_set_create([uniform_input, uniform_output, uniform_params], rd_yuv_shader, 0)
	var total_frames: float = float(video.get_frame_count())
	var loaded_amount: int = 0
	video.seek_frame(0)

	for i: int in video.get_frame_count():
		var image: Image = video.generate_thumbnail_at_current_frame() # RGBA Image
		if image:
			image.resize(target_resolution.x, target_resolution.y, Image.INTERPOLATE_BILINEAR)
			rendering_device.texture_update(input_tex, 0, image.get_data())

			var compute_list: int = rendering_device.compute_list_begin()
			rendering_device.compute_list_bind_compute_pipeline(compute_list, rd_yuv_pipeline)
			rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
			rendering_device.compute_list_dispatch(compute_list, ceili(target_resolution.x / 8.0), ceili(target_resolution.y / 8.0), 1)
			rendering_device.compute_list_end()
			var yuv_data: PackedByteArray = rendering_device.texture_get_data(yuv_output_tex, 0)
			encoder.send_frame(yuv_data)

		# We skip decoding since generate_thumbnail_at_frame handles that.
		if !video.next_frame(true):
			break
		loaded_amount += 1
		proxy_loading.emit.call_deferred(file, int((loaded_amount / total_frames) * 100.0))
	proxy_loading.emit.call_deferred(file, 100)
	encoder.close()
	video.close()

	# Cleanup RD Resources.
	rendering_device.free_rid(uniform_set)
	rendering_device.free_rid(rd_yuv_pipeline)
	rendering_device.free_rid(rd_yuv_shader)
	rendering_device.free_rid(input_tex)
	rendering_device.free_rid(yuv_output_tex)
	rendering_device.free_rid(yuv_sampler)
	rendering_device.free_rid(yuv_params_buffer)
	FileLogic.set_proxy_path(file, output_path)


func _create_proxy_name(file_path: String) -> String:
	return  "%s_%s_proxy.mp4" % [FileAccess.get_md5(file_path).left(6), file_path.get_file().get_basename()]


func _on_proxy_finished(file: FileData) -> void:
	if Settings.get_use_proxies():
		FileLogic.reload(file)
	FileLogic.nickname_changed.emit(file) # To update the name
