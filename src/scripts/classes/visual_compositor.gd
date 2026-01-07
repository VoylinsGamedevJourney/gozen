class_name VisualCompositor
extends RefCounted

const PARAM_BUFFER_SIZE: int = 128

const USAGE_BITS_R8: int = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT)
const USAGE_BITS_RGBA: int = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)


var device: RenderingDevice = RenderingServer.get_rendering_device()

var y_texture: RID
var u_texture: RID
var v_texture: RID
var yuv_params: RID

var ping_texture: RID
var pong_texture: RID
var display_texture: Texture2DRD

var pipeline_yuv: RID
var shader_yuv: RID

var effects_cache: Dictionary[String, EffectCache] = {} # { shader_path : shader cache }

var resolution: Vector2i
var initialized: bool = false



func initialize(p_resolution: Vector2i, is_video: bool = true) -> void:
	if initialized:
		cleanup()

	resolution = p_resolution

	if is_video:
		# Creating the Y input texture
		var format_y: RDTextureFormat = RDTextureFormat.new()

		format_y.format = device.DATA_FORMAT_R8_UNORM
		format_y.width = resolution.x
		format_y.height = resolution.y
		format_y.usage_bits = USAGE_BITS_R8
		format_y.texture_type = device.TEXTURE_TYPE_2D

		y_texture = device.texture_create(format_y, RDTextureView.new(), [])

		# Creating the UV input textures
		var format_uv: RDTextureFormat = RDTextureFormat.new()

		format_uv.format = device.DATA_FORMAT_R8_UNORM
		format_uv.width = floori(resolution.x / 2.0)
		format_uv.height = floori(resolution.y / 2.0)
		format_uv.usage_bits = USAGE_BITS_R8
		format_uv.texture_type = device.TEXTURE_TYPE_2D
		u_texture = device.texture_create(format_uv, RDTextureView.new(), [])
		v_texture = device.texture_create(format_uv, RDTextureView.new(), [])

	# Create RGBA8 output textures
	var format_rgba: RDTextureFormat = RDTextureFormat.new()

	format_rgba.format = device.DATA_FORMAT_R8G8B8A8_UNORM
	format_rgba.width = resolution.x
	format_rgba.height = resolution.y
	format_rgba.usage_bits = USAGE_BITS_RGBA
	format_rgba.texture_type = device.TEXTURE_TYPE_2D

	ping_texture = device.texture_create(format_rgba, RDTextureView.new(), [])
	pong_texture = device.texture_create(format_rgba, RDTextureView.new(), [])

	# Create display texture
	display_texture = Texture2DRD.new()
	display_texture.texture_rd_rid = ping_texture

	# Allocate space for YUV params
	yuv_params = _create_storage_buffer(64)

	initialized = true
	print("VisualCompositor: initialization complete")


func setup_yuv_pipeline(shader_file: RDShaderFile) -> void:
	var spirv: RDShaderSPIRV = shader_file.get_spirv()

	# Quick cleanup check
	if shader_yuv.is_valid():
		device.free_rid(shader_yuv)
	if pipeline_yuv.is_valid():
		device.free_rid(pipeline_yuv)

	shader_yuv = device.shader_create_from_spirv(spirv)
	pipeline_yuv = device.compute_pipeline_create(shader_yuv)


func process_video_frame(y_data: Image, u_data: Image, v_data: Image, rotation: float,
						 color_profile: Vector4, interlaced: float,
						 effects: Array[VisualEffect], current_frame: int) -> void:
	if not initialized:
		return

	var yuv_buffer_data: PackedByteArray = PackedByteArray()
	var stream_writer: StreamPeerBuffer = StreamPeerBuffer.new()

	# Update the YUV input textures
	device.texture_update(y_texture, 0, y_data.get_data())
	device.texture_update(u_texture, 0, u_data.get_data())
	device.texture_update(v_texture, 0, v_data.get_data())

	# YUV params buffer
	# - ivec2 resolution; offset 0
	# - vec4 color_prof;  offset 16
	# - float rotation;   offset 32
	# - float rotation;   offset 32
	yuv_buffer_data.resize(64)
	stream_writer.data_array = yuv_buffer_data

	stream_writer.put_32(resolution.x)
	stream_writer.put_32(resolution.y)
	stream_writer.put_64(0) # Padding to reach 16 bytes for vec4 alignment

	stream_writer.put_float(color_profile.x)
	stream_writer.put_float(color_profile.y)
	stream_writer.put_float(color_profile.z)
	stream_writer.put_float(color_profile.w)

	stream_writer.put_float(rotation)
	stream_writer.put_float(interlaced)

	device.buffer_update(yuv_params, 0, stream_writer.data_array.size(), stream_writer.data_array)

	# Start of compute list
	# Convert YUV to RGBA (and write to ping)
	var compute_list: int = device.compute_list_begin()
	
	device.compute_list_bind_compute_pipeline(compute_list, pipeline_yuv)

	# Create uniform set for YUV pass
	var yuv_uniforms: Array[RDUniform] = [
		_create_sampler_uniform(y_texture, 0), # Input
		_create_sampler_uniform(u_texture, 1), # Input
		_create_sampler_uniform(v_texture, 2), # Input
		_create_image_uniform(ping_texture, 3) # Output
	]
	
	var yuv_set: RID = device.uniform_set_create(yuv_uniforms, shader_yuv, 0)

	device.compute_list_bind_uniform_set(compute_list, yuv_set, 0)

	# Compute shaders use x=8, y=8, and z=1
	var groups_x: int = ceili(resolution.x / 8.0)
	var groups_y: int = ceili(resolution.x / 8.0)

	device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)

	# Make certain that YUV conversion finished before continuing
	device.compute_list_add_barrier(compute_list)

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


func cleanup() -> void:
	if y_texture.is_valid(): device.free_rid(y_texture)
	if u_texture.is_valid(): device.free_rid(u_texture)
	if v_texture.is_valid(): device.free_rid(v_texture)

	if ping_texture.is_valid(): device.free_rid(ping_texture)
	if pong_texture.is_valid(): device.free_rid(pong_texture)

	if yuv_params.is_valid(): device.free_rid(yuv_params)
	if shader_yuv.is_valid(): device.free_rid(shader_yuv)
	if pipeline_yuv.is_valid(): device.free_rid(pipeline_yuv)


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
				stream_writer.put_float(value)
			elif value == VisualEffect.PARAM_TYPE.INT:
				stream_writer.put_32(value)
			elif value == VisualEffect.PARAM_TYPE.COLOR: #Color should be RGBA
				stream_writer.put_float(value.r)
				stream_writer.put_float(value.g)
				stream_writer.put_float(value.b)
				stream_writer.put_float(value.a)
			elif value == VisualEffect.PARAM_TYPE.VEC2:
				stream_writer.put_float(value.x)
				stream_writer.put_float(value.y)

		param_data = stream_writer.data_array

		if param_data.size() < 128:
			param_data.resize(128) # Add padding if needed
