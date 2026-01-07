class_name VisualCompositor
extends RefCounted


const USAGE_BITS_R8: int = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
const USAGE_BITS_RGBA: int = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT


var device: RenderingDevice = RenderingServer.get_rendering_device()

var y_texture: RID
var u_texture: RID
var v_texture: RID

var ping_texture: RID
var pong_texture: RID
var display_texture: Texture2DRD

var pipeline_yuv: RID
var shader_yuv: RID

var uniform_set_yuv: RID

var resolution: Vector2i
var initialized: bool = false



func initialize(p_resolution: Vector2i) -> void:
	if initialized:
		cleanup()

	resolution = p_resolution

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
	format_uv.height = resolution.y
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

	initialized = true
	print("VisualCompositor: initialization complete")


func process_video_frame(y_data: Image, u_data: Image, v_data: Image, effects: Array[VideoEffect]) -> void:
	if not initialized:
		return

	# Update the YUV input textures
	device.texture_update(y_texture, 0, y_data.get_data())
	device.texture_update(u_texture, 0, u_data.get_data())
	device.texture_update(v_texture, 0, v_data.get_data())

	# Convert YUV to RGBA
	var compute_list: int = device.compute_list_begin()
	
	device.compute_list_bind_compute_pipeline(compute_list, pipeline_yuv)

	# Create uniform set for YUV pass
	var uniforms: Array[RDUniform] = [
		_create_sampler_uniform(y_texture, 0), # Input
		_create_sampler_uniform(u_texture, 1), # Input
		_create_sampler_uniform(v_texture, 2), # Input
		_create_image_uniform(ping_texture, 3) # Output
		# TODO: create normal uniform buffer for resolution, color_profile, and rotation
	]

	var uniform_set: RID = device.uniform_set_create(uniforms, shader_yuv, 0)

	device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# Compute shaders use x=8, y=8, and z=1
	var groups_x: int = ceili(resolution.x / 8.0)
	var groups_y: int = ceili(resolution.x / 8.0)

	device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)

	# Make certain that YUV conversion finished before continuing
	device.compute_list_add_barrier(compute_list)

	# Start handling the effects
	for effect: VideoEffect in effects:
		if not effect.enabled:
			continue

		# TODO: Handle effects

		# Make certain data is handled and ready
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
	# TODO: Cleanup YUV pipeline and effect shaders


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
