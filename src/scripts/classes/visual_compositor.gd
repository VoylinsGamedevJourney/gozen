class_name VisualCompositor
extends RefCounted


const YUV_PARAM_BUFFER_SIZE: int = 80

const USAGE_BITS_R8: int = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT)
const USAGE_BITS_RGBA: int = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT)

const BT709: PackedFloat32Array = [
	 1.164,  1.164,  1.164, 0.0,
	 0.000, -0.213,  2.112, 0.0,
	 1.793, -0.533,  0.000, 0.0,
	-0.969,  0.301, -1.129, 1.0]

const BT601_LIMITED: PackedFloat32Array = [
	 1.164,  1.164,  1.164, 0.0,
	 0.000, -0.392,  2.017, 0.0,
	 1.596, -0.813,  0.000, 0.0,
	-0.871,  0.530, -1.086, 1.0]
const BT601_FULL: PackedFloat32Array = [
	 1.000,  1.000,  1.000, 0.0,
	 0.000, -0.344,  1.772, 0.0,
	 1.402, -0.714,  0.000, 0.0,
	-0.701,  0.529, -0.886, 1.0]

const BT2020_LIMITED: PackedFloat32Array = [
	 1.1640,  1.16400,  1.1640, 0.0,
	 0.0000, -0.16455,  1.8814, 0.0,
	 1.4746, -0.57135,  0.0000, 0.0,
	-0.8130,  0.29600, -1.0170, 1.0]
const BT2020_FULL: PackedFloat32Array = [
	 1.0000,  1.00000,  1.00000, 0.0,
	 0.0000, -0.18733,  1.85563, 0.0,
	 1.4746, -0.46813,  0.00000, 0.0,
	-0.7373,  0.33130, -0.92780, 1.0]


var device: RenderingDevice = RenderingServer.get_rendering_device()

# For videos
var y_texture: RID
var u_texture: RID
var v_texture: RID
var a_texture: RID

var yuv_params: RID
var pipeline_yuv: RID
var shader_yuv: RID

# For images
var base_image: RID

var ping_texture: RID
var pong_texture: RID
var display_texture: Texture2DRD

var effects_cache: Dictionary[String, EffectCache] = {} # { shader_path : shader cache }

var resolution: Vector2i
var initialized: bool = false

# Compute shaders use x=8, y=8, and z=1
var groups_x: int
var groups_y: int


func _init_start(p_resolution: Vector2i) -> void:
	if initialized:
		cleanup()

	resolution = p_resolution
	display_texture = Texture2DRD.new()

	groups_x = ceili(resolution.x / 8.0)
	groups_y = ceili(resolution.x / 8.0)


func _init_ping_pong() -> void:
	# Create RGBA8 format
	var format_rgba: RDTextureFormat = RDTextureFormat.new()

	format_rgba.format = device.DATA_FORMAT_R8G8B8A8_UNORM
	format_rgba.width = resolution.x
	format_rgba.height = resolution.y
	format_rgba.usage_bits = USAGE_BITS_RGBA
	format_rgba.texture_type = device.TEXTURE_TYPE_2D

	# Create textures
	ping_texture = device.texture_create(format_rgba, RDTextureView.new(), [])
	pong_texture = device.texture_create(format_rgba, RDTextureView.new(), [])
	display_texture.texture_rd_rid = ping_texture
	initialized = true


func initialize_image(image: Texture2D) -> void:
	_init_start(image.get_size())

	var format: RDTextureFormat = RDTextureFormat.new()
	var new_image: Image = image.get_image()

	format.format = device.DATA_FORMAT_R8G8B8A8_UNORM
	format.width = new_image.get_width()
	format.height = new_image.get_height()
	format.usage_bits = USAGE_BITS_RGBA
	format.texture_type = device.TEXTURE_TYPE_2D

	if new_image.get_format() != Image.FORMAT_RGBA8:
		new_image.convert(Image.FORMAT_RGBA8)

	base_image = device.texture_create(format, RDTextureView.new(), [new_image.get_data()])
	_init_ping_pong()


func initialize_video(video: GoZenVideo) -> void:
	_init_start(video.get_resolution())

	var spirv: RDShaderSPIRV = preload("res://shaders/yuv_to_rgba.glsl").get_spirv()
	var format_y: RDTextureFormat = RDTextureFormat.new()
	var format_uv: RDTextureFormat = RDTextureFormat.new()

	# Setup YUV pipeline
	shader_yuv = device.shader_create_from_spirv(spirv)
	pipeline_yuv = device.compute_pipeline_create(shader_yuv)

	# Creating the Y format
	format_y.format = device.DATA_FORMAT_R8_UNORM
	format_y.width = resolution.x
	format_y.height = resolution.y
	format_y.usage_bits = USAGE_BITS_R8
	format_y.texture_type = device.TEXTURE_TYPE_2D

	# Creating the UV format
	format_uv.format = device.DATA_FORMAT_R8_UNORM
	format_uv.width = floori(resolution.x / 2.0)
	format_uv.height = floori(resolution.y / 2.0)
	format_uv.usage_bits = USAGE_BITS_R8
	format_uv.texture_type = device.TEXTURE_TYPE_2D

	# Create YUV textures
	y_texture = device.texture_create(format_y, RDTextureView.new(), [])
	u_texture = device.texture_create(format_uv, RDTextureView.new(), [])
	v_texture = device.texture_create(format_uv, RDTextureView.new(), [])

	if video.get_has_alpha():
		a_texture = device.texture_create(format_y, RDTextureView.new(), [])
	else:
		var white_image: Image = Image.create(resolution.x, resolution.y, false, Image.FORMAT_R8)

		white_image.fill(Color.WHITE)
		a_texture = device.texture_create(format_y, RDTextureView.new(), [white_image.get_data()])

	yuv_params = _create_yuv_params(video)
	_init_ping_pong()


func process_video_frame(video: GoZenVideo, effects: Array[VisualEffect], current_frame: int) -> void:
	if not initialized:
		return

	# Update the YUV input textures
	device.texture_update(y_texture, 0, video.get_y_data().get_data())
	device.texture_update(u_texture, 0, video.get_u_data().get_data())
	device.texture_update(v_texture, 0, video.get_v_data().get_data())

	if video.get_has_alpha():
		device.texture_update(a_texture, 0, video.get_a_data().get_data())

	_update_effect_buffers(effects, current_frame)

	# Start of compute list
	# Convert YUV to RGBA (and write to ping)
	var compute_list: int = device.compute_list_begin()
	
	device.compute_list_bind_compute_pipeline(compute_list, pipeline_yuv)

	# Create uniform set for YUV pass
	var yuv_uniforms: Array[RDUniform] = [
		_create_sampler_uniform(y_texture, 0), # Input
		_create_sampler_uniform(u_texture, 1), # Input
		_create_sampler_uniform(v_texture, 2), # Input
		_create_sampler_uniform(a_texture, 3), # Input
		_create_image_uniform(ping_texture, 4), # Output
		_create_buffer_uniform(yuv_params, 5)] # Video info
	var yuv_set: RID = device.uniform_set_create(yuv_uniforms, shader_yuv, 0)

	device.compute_list_bind_uniform_set(compute_list, yuv_set, 0)
	device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	device.compute_list_add_barrier(compute_list)

	_process_frame(compute_list, effects, current_frame)


func process_image_frame(effects: Array[VisualEffect], current_frame: int) -> void:
	if not initialized:
		return

	_update_effect_buffers(effects, current_frame)

	device.texture_copy(
		base_image, ping_texture,
		Vector3.ZERO, Vector3.ZERO,
		Vector3(resolution.x, resolution.y, 1),
		0, 0, 0, 0)

	_process_frame(device.compute_list_begin(), effects, current_frame)


func cleanup() -> void:
	ping_texture = Utils.cleanup_rid(device, ping_texture)
	pong_texture = Utils.cleanup_rid(device, pong_texture)

	# Video cleanup
	y_texture = Utils.cleanup_rid(device, y_texture)
	u_texture = Utils.cleanup_rid(device, u_texture)
	v_texture = Utils.cleanup_rid(device, v_texture)
	a_texture = Utils.cleanup_rid(device, a_texture)
	yuv_params = Utils.cleanup_rid(device, yuv_params)
	pipeline_yuv = Utils.cleanup_rid(device, pipeline_yuv)
	shader_yuv = Utils.cleanup_rid(device, shader_yuv)

	# Image cleanup
	base_image = Utils.cleanup_rid(device, base_image)

	for shader_path: String in effects_cache:
		effects_cache[shader_path].free_rids(device)

	effects_cache.clear()


func _update_effect_buffers(effects: Array[VisualEffect], current_frame: int) -> void:
	for effect: VisualEffect in effects:
		if not effect.enabled:
			continue

		var cache: EffectCache = _get_effect_pipeline(effect.shader_path, effect)
		if not cache: continue

		cache.pack_effect_params(effect, current_frame)
		device.buffer_update(cache.buffer, 0, cache.buffer_size, cache.data)


func _process_frame(compute_list: int, effects: Array[VisualEffect], current_frame: int) -> void:
	# Start handling the effects
	for effect: VisualEffect in effects:
		if not effect.enabled:
			continue

		var cache: EffectCache = _get_effect_pipeline(effect.shader_path, effect)
		if not cache: continue

		device.compute_list_bind_compute_pipeline(compute_list, cache.pipeline)

		# Create uniforms for effect
		# - binding 0: input image
		# - binding 1: output image
		# - binding 2: params
		var effect_uniforms: Array[RDUniform] = [
			_create_sampler_uniform(ping_texture, 0),
			_create_image_uniform(pong_texture, 1),
			_create_buffer_uniform(cache.buffer, 2)]
		var effect_set: RID = device.uniform_set_create(effect_uniforms, cache.shader, 0)

		device.compute_list_bind_uniform_set(compute_list, effect_set, 0)
		device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
		device.compute_list_add_barrier(compute_list)

		# Swap buffers
		var temp_texture: RID = ping_texture

		ping_texture = pong_texture
		pong_texture = temp_texture

	device.compute_list_end()
	display_texture.texture_rd_rid = ping_texture


func _create_yuv_params(video: GoZenVideo) -> RID:
	var yuv_buffer_data: PackedByteArray = PackedByteArray()
	var stream_writer: StreamPeerBuffer = StreamPeerBuffer.new()
	var matrix_data: PackedFloat32Array

	yuv_buffer_data.resize(YUV_PARAM_BUFFER_SIZE)
	stream_writer.data_array = yuv_buffer_data

	match video.get_color_profile():
		"bt2020", "bt2100":
			matrix_data = BT2020_FULL if video.is_full_color_range() else BT2020_LIMITED
		"bt601", "bt470":
			matrix_data = BT601_FULL if video.is_full_color_range() else BT601_LIMITED
		_: # bt709 and unknown
			matrix_data = BT709 

	for value: float in matrix_data:
		stream_writer.put_float(value)

	stream_writer.put_32(resolution.x)
	stream_writer.put_32(resolution.y)
	stream_writer.put_32(video.get_interlaced())
	stream_writer.put_32(0) # Necessary padding

	return device.uniform_buffer_create(stream_writer.data_array.size(), stream_writer.data_array)


func _create_storage_buffer(size_bytes: int) -> RID:
	var buffer_data: PackedByteArray = []

	buffer_data.resize(size_bytes)
	return device.storage_buffer_create(size_bytes, buffer_data)


func _create_sampler_uniform(texture_rid: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	var sampler_state: RDSamplerState = RDSamplerState.new()
	var sampler_rid: RID = device.sampler_create(sampler_state)

	uniform.uniform_type = device.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler_rid)
	uniform.add_id(texture_rid)

	return uniform


func _create_image_uniform(texture_rid: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()

	uniform.uniform_type = device.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture_rid)

	return uniform


func _create_buffer_uniform(buffer_rid: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()

	uniform.uniform_type = device.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform.binding = binding
	uniform.add_id(buffer_rid)

	return uniform


func _get_effect_pipeline(shader_path: String, effect: VisualEffect) -> EffectCache:
	if effects_cache.has(shader_path):
		return effects_cache[shader_path]

	var shader_file: RDShaderFile = load(shader_path)
	var effect_cache: EffectCache = EffectCache.new()

	if not shader_file is RDShaderFile:
		printerr("Effect shader is not RDShaderFile (compute shader): ", shader_path)
		return null

	effect_cache.initialize(device, shader_file.get_spirv(), effect)
	effects_cache[shader_path] = effect_cache

	return effect_cache
