class_name VisualCompositor
extends RefCounted

const PARAM_BUFFER_SIZE: int = 128
const YUV_PARAM_BUFFER_SIZE: int = 80

const USAGE_BITS_R8: int = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT)
const USAGE_BITS_RGBA: int = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)

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

var y_texture: RID
var u_texture: RID
var v_texture: RID
var a_texture: RID
var yuv_params: RID

var ping_texture: RID
var pong_texture: RID
var display_texture: Texture2DRD

var pipeline_yuv: RID
var shader_yuv: RID

var effects_cache: Dictionary[String, EffectCache] = {} # { shader_path : shader cache }

var resolution: Vector2i
var initialized: bool = false

# Compute shaders use x=8, y=8, and z=1
var groups_x: int
var groups_y: int



func initialize(p_resolution: Vector2i, video: GoZenVideo = null) -> void:
	if initialized:
		cleanup()

	resolution = p_resolution
	display_texture = Texture2DRD.new()

	groups_x = ceili(resolution.x / 8.0)
	groups_y = ceili(resolution.x / 8.0)

	if video != null:
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


func process_video_frame(video: GoZenVideo, effects: Array[VisualEffect], current_frame: int) -> void:
	if not initialized:
		return

	# Update the YUV input textures
	device.texture_update(y_texture, 0, video.get_y_data().get_data())
	device.texture_update(u_texture, 0, video.get_u_data().get_data())
	device.texture_update(v_texture, 0, video.get_v_data().get_data())

	if video.get_has_alpha():
		device.texture_update(a_texture, 0, video.get_a_data().get_data())

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


func process_image_frame(_data: Image, effects: Array[VisualEffect], current_frame: int) -> void:
	# TODO: Add data to ping_texture,
	#ping_texture = _create_image_uniform(data.get_rid(), 0)
	_process_frame(device.compute_list_begin(), effects, current_frame)


func cleanup() -> void:
	if y_texture.is_valid():
		device.free_rid(y_texture)
		y_texture = RID()
	if u_texture.is_valid():
		device.free_rid(u_texture)
		u_texture = RID()
	if v_texture.is_valid():
		device.free_rid(v_texture)
		v_texture = RID()

	if ping_texture.is_valid():
		device.free_rid(ping_texture)
		ping_texture = RID()
	if pong_texture.is_valid():
		device.free_rid(pong_texture)
		pong_texture = RID()

	if yuv_params.is_valid():
		device.free_rid(yuv_params)
		yuv_params = RID()
	if pipeline_yuv.is_valid():
		device.free_rid(pipeline_yuv)
		pipeline_yuv = RID()
	if shader_yuv.is_valid():
		device.free_rid(shader_yuv)
		shader_yuv = RID()

	for shader_path: String in effects_cache:
		effects_cache[shader_path].free_rids(device)

	effects_cache.clear()


func _process_frame(compute_list: int, effects: Array[VisualEffect], current_frame: int) -> void:
	# Start handling the effects
	for effect: VisualEffect in effects:
		if not effect.enabled:
			continue

		var cache: EffectCache = _get_effect_pipeline(effect.shader_path)
		if not cache: continue

		device.compute_list_bind_compute_pipeline(compute_list, cache.pipeline)
		cache.pack_effect_params(effect, current_frame)
		device.buffer_update(cache.param_buffer, 0, cache.param_size, cache.param_data)

		# Create uniforms for effect
		# - binding 0: input image
		# - binding 1: output image
		# - binding 2: params
		var effect_uniforms: Array[RDUniform] = [
			_create_sampler_uniform(ping_texture, 0),
			_create_image_uniform(pong_texture, 1),
			_create_buffer_uniform(cache.param_buffer, 2)
		]

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


func _get_effect_pipeline(shader_path: String) -> EffectCache:
	if effects_cache.has(shader_path):
		return effects_cache[shader_path]

	var shader_file: RDShaderFile = load(shader_path)
	var effect_cache: EffectCache = EffectCache.new()

	if not shader_file is RDShaderFile:
		printerr("Effect shader is not RDShaderFile (compute shader): ", shader_path)
		return null

	effect_cache.initialize(device, shader_file.get_spirv(), PARAM_BUFFER_SIZE)
	effects_cache[shader_path] = effect_cache

	return effect_cache



class EffectCache:
	var shader: RID
	var pipeline: RID

	var param_buffer: RID
	var param_size: int
	var param_data: PackedByteArray = PackedByteArray()


	func initialize(device: RenderingDevice, spirv: RDShaderSPIRV, buffer_size: int) -> void:
		shader = device.shader_create_from_spirv(spirv)
		pipeline = device.compute_pipeline_create(shader)

		var empty_buffer: PackedByteArray = PackedByteArray()

		empty_buffer.resize(buffer_size)
		param_buffer = device.uniform_buffer_create(buffer_size, empty_buffer)


	func pack_effect_params(effect: VisualEffect, frame_nr: int) -> void:
		var stream_writer: StreamPeerBuffer = StreamPeerBuffer.new()

		for param: VisualEffectParam in effect.params:
			var value: Variant = effect.get_param_value(param.param_id, frame_nr)

			if param.type == VisualEffect.PARAM_TYPE.FLOAT:
				_pad_stream(stream_writer, 4)
				stream_writer.put_float(value)
			elif param.type == VisualEffect.PARAM_TYPE.INT:
				_pad_stream(stream_writer, 4)
				stream_writer.put_32(value)
			elif param.type == VisualEffect.PARAM_TYPE.COLOR: #Color should be RGBA
				_pad_stream(stream_writer, 16)
				stream_writer.put_float(value.r)
				stream_writer.put_float(value.g)
				stream_writer.put_float(value.b)
				stream_writer.put_float(value.a)
			elif param.type == VisualEffect.PARAM_TYPE.VEC2:
				stream_writer.put_float(value.x)
				stream_writer.put_float(value.y)
			elif param.type == VisualEffect.PARAM_TYPE.VEC3:
				_pad_stream(stream_writer, 16)
				stream_writer.put_float(value.x)
				stream_writer.put_float(value.y)
				stream_writer.put_float(value.z)
			elif param.type == VisualEffect.PARAM_TYPE.VEC4:
				_pad_stream(stream_writer, 16)
				stream_writer.put_float(value.x)
				stream_writer.put_float(value.y)
				stream_writer.put_float(value.z)
				stream_writer.put_float(value.w)

		param_data = stream_writer.data_array

		if param_data.size() < PARAM_BUFFER_SIZE:
			param_data.resize(PARAM_BUFFER_SIZE) # Add padding if needed to end


	func free_rids(device: RenderingDevice) -> void:
		if shader.is_valid(): device.free_rid(shader)
		if pipeline.is_valid(): device.free_rid(pipeline)
		if param_buffer.is_valid(): device.free_rid(param_buffer)


	func _pad_stream(stream_buffer: StreamPeerBuffer, alignment: int) -> void:
		var current_offset: int = stream_buffer.get_position()
		var remainder: int = current_offset % alignment
		
		if remainder != 0:
			for i: int in alignment - remainder:
				stream_buffer.put_8(0)
