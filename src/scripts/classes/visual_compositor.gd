class_name VisualCompositor
extends RefCounted

const YUV_PARAM_BUFFER_SIZE: int = 96

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

# For videos.
var y_texture: RID
var u_texture: RID
var v_texture: RID
var a_texture: RID

var yuv_params: RID
var yuv_pipeline: RID
var yuv_shader: RID

# For images.
var base_image: RID

# Fading stuff.
var fade_shader: RID
var fade_pipeline: RID
var fade_buffer: RID
var fade_in_buffer: RID
var fade_out_buffer: RID
var copy_buffer: RID

var ping_texture: RID
var pong_texture: RID
var display_texture: Texture2DRD
var default_sampler: RID

var effects_cache: Dictionary[String, EffectCache] = {} # { shader_path : shader cache }
var effect_buffers: Dictionary[int, Array] = {} # { effect_instance_id : [RID, RID, ...] }

var resolution: Vector2i
var initialized: bool = false

# Compute shaders use x=8, y=8, and z=1
var groups_x: int
var groups_y: int



func _init_start(p_resolution: Vector2i) -> void:
	if initialized and resolution != p_resolution:
		cleanup()

	if not fade_in_buffer.is_valid():
		var fade_buffer_data: PackedByteArray = PackedByteArray()
		var err: int = fade_buffer_data.resize(16)
		if err != OK:
			printerr("VisualCompositor: Resizing 'fade_buffer_data' failed with '%s'!" % err)

		fade_in_buffer = device.uniform_buffer_create(16, fade_buffer_data)
		fade_out_buffer = device.uniform_buffer_create(16, fade_buffer_data)

	if not default_sampler.is_valid():
		var sampler_state: RDSamplerState = RDSamplerState.new()
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		default_sampler = device.sampler_create(sampler_state)

	resolution = p_resolution
	if not display_texture:
		display_texture = Texture2DRD.new()

	groups_x = ceili(resolution.x / 8.0)
	groups_y = ceili(resolution.y / 8.0)

	if not fade_shader.is_valid():
		var fade_spirv: RDShaderSPIRV = preload("res://effects/shaders/internal_copy.glsl").get_spirv()
		var fade_buffer_data: PackedByteArray = PackedByteArray()

		fade_shader = device.shader_create_from_spirv(fade_spirv)
		fade_pipeline = device.compute_pipeline_create(fade_shader)
		var err: int = fade_buffer_data.resize(16)
		if err != OK:
			printerr("VisualCompositor: Resizing 'fade_buffer_data' failed with '%s'!" % err)

		fade_buffer_data.encode_float(0, 1.0)
		copy_buffer = device.uniform_buffer_create(fade_buffer_data.size(), fade_buffer_data)


func _init_ping_pong() -> void:
	if ping_texture.is_valid(): return # Already created and valid for this resolution

	# Create RGBA8 format
	var format_rgba: RDTextureFormat = RDTextureFormat.new()
	format_rgba.format = device.DATA_FORMAT_R8G8B8A8_UNORM
	format_rgba.width = resolution.x
	format_rgba.height = resolution.y
	format_rgba.usage_bits = USAGE_BITS_RGBA
	format_rgba.texture_type = device.TEXTURE_TYPE_2D

	# Create textures
	ping_texture = device.texture_create(format_rgba, RDTextureView.new(),[])
	pong_texture = device.texture_create(format_rgba, RDTextureView.new(),[])
	display_texture.texture_rd_rid = ping_texture
	initialized = true


func initialize_texture(size: Vector2i) -> void:
	if initialized and resolution != size: cleanup()

	_init_start(size)
	_init_ping_pong()


func initialize_video(video: Video) -> void:
	if !video: return

	if initialized and resolution != Project.data.resolution:
		cleanup()

	_init_start(Project.data.resolution)

	if not yuv_shader.is_valid():
		var spirv: RDShaderSPIRV = preload("res://effects/shaders/yuv_to_rgba.glsl").get_spirv()
		yuv_shader = device.shader_create_from_spirv(spirv)
		yuv_pipeline = device.compute_pipeline_create(yuv_shader)

	y_texture = Utils.cleanup_rid(device, y_texture)
	u_texture = Utils.cleanup_rid(device, u_texture)
	v_texture = Utils.cleanup_rid(device, v_texture)
	a_texture = Utils.cleanup_rid(device, a_texture)
	yuv_params = Utils.cleanup_rid(device, yuv_params)

	var format_y: RDTextureFormat = RDTextureFormat.new()
	var format_uv: RDTextureFormat = RDTextureFormat.new()
	var y_data: Image = video.get_y_data()
	var u_data: Image = video.get_u_data()

	# Creating the Y format.
	format_y.format = device.DATA_FORMAT_R8_UNORM
	format_y.width = y_data.get_width()
	format_y.height = y_data.get_height()
	format_y.usage_bits = USAGE_BITS_R8
	format_y.texture_type = device.TEXTURE_TYPE_2D

	# Creating the UV format.
	format_uv.format = device.DATA_FORMAT_R8_UNORM
	format_uv.width = u_data.get_width()
	format_uv.height = u_data.get_height()
	format_uv.usage_bits = USAGE_BITS_R8
	format_uv.texture_type = device.TEXTURE_TYPE_2D

	# Create YUV textures.
	y_texture = device.texture_create(format_y, RDTextureView.new(),[])
	u_texture = device.texture_create(format_uv, RDTextureView.new(),[])
	v_texture = device.texture_create(format_uv, RDTextureView.new(),[])

	if video.get_has_alpha():
		a_texture = device.texture_create(format_y, RDTextureView.new(),[])
	else:
		var white_image: Image = Image.create(y_data.get_width(), y_data.get_height(), false, Image.FORMAT_R8)
		white_image.fill(Color.WHITE)
		a_texture = device.texture_create(format_y, RDTextureView.new(), [white_image.get_data()])

	yuv_params = _create_yuv_params(video)
	_init_ping_pong()


func process_video_frame(video: Video, effects: Array[EffectVisual], transition_left: EffectVisual, fade_in: float, transition_right: EffectVisual, fade_out: float, frame_nr: int) -> void:
	if not initialized: return

	if device.texture_update(y_texture, 0, video.get_y_data().get_data()) or \
		device.texture_update(u_texture, 0, video.get_u_data().get_data()) or \
		device.texture_update(v_texture, 0, video.get_v_data().get_data()):
		printerr("VisualCompositor: Failed to update yuv texture in RenderingDevice!")

	if video.get_has_alpha() and device.texture_update(a_texture, 0, video.get_a_data().get_data()):
		printerr("VisualCompositor: Failed to update alpha texture in RenderingDevice!")

	var all_effects: Array[EffectVisual] = effects.duplicate()
	if transition_left and fade_in < 1.0: all_effects.append(transition_left)
	if transition_right and fade_out < 1.0: all_effects.append(transition_right)
	_update_effect_buffers(all_effects, frame_nr)
	_update_transition_buffers(transition_left, fade_in, transition_right, fade_out)

	var compute_list: int = device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, yuv_pipeline)

	var yuv_uniforms: Array[RDUniform] = [
		_create_sampler_uniform(y_texture, 0),
		_create_sampler_uniform(u_texture, 1),
		_create_sampler_uniform(v_texture, 2),
		_create_sampler_uniform(a_texture, 3),
		_create_image_uniform(ping_texture, 4),
		_create_buffer_uniform(yuv_params, 5)]
	var yuv_set: RID = device.uniform_set_create(yuv_uniforms, yuv_shader, 0)

	device.compute_list_bind_uniform_set(compute_list, yuv_set, 0)
	device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	device.compute_list_add_barrier(compute_list)

	_process_frame(compute_list, effects, transition_left, fade_in, transition_right, fade_out, frame_nr)
	device.free_rid(yuv_set)


func process_image_frame(effects: Array[EffectVisual], transition_left: EffectVisual, fade_in: float, transition_right: EffectVisual, fade_out: float, frame_nr: int) -> void:
	if not initialized: return

	var all_effects: Array[EffectVisual] = effects.duplicate()
	if transition_left and fade_in < 1.0: all_effects.append(transition_left)
	if transition_right and fade_out < 1.0: all_effects.append(transition_right)
	_update_effect_buffers(all_effects, frame_nr)
	_update_transition_buffers(transition_left, fade_in, transition_right, fade_out)

	if device.texture_copy(base_image, ping_texture, Vector3.ZERO, Vector3.ZERO, Vector3(resolution.x, resolution.y, 1), 0, 0, 0, 0):
		printerr("VisualCompositor: Failed to copy texture on RenderingDevice for processing image frame!")

	_process_frame(device.compute_list_begin(), effects, transition_left, fade_in, transition_right, fade_out, frame_nr)


func process_texture_frame(texture_rid: RID, effects: Array[EffectVisual], transition_left: EffectVisual, fade_in: float, transition_right: EffectVisual, fade_out: float, frame_nr: int) -> void:
	if not initialized: return

	var rd_input_tex: RID = RenderingServer.texture_get_rd_texture(texture_rid)
	if not rd_input_tex.is_valid(): return

	var all_effects: Array[EffectVisual] = effects.duplicate()
	if transition_left and fade_in < 1.0: all_effects.append(transition_left)
	if transition_right and fade_out < 1.0: all_effects.append(transition_right)
	_update_effect_buffers(all_effects, frame_nr)
	_update_transition_buffers(transition_left, fade_in, transition_right, fade_out)

	if device.texture_copy(rd_input_tex, pong_texture, Vector3.ZERO, Vector3.ZERO, Vector3(resolution.x, resolution.y, 1), 0, 0, 0, 0):
		printerr("VisualCompositor: Failed to copy texture frame on RenderingDevice for processing!")

	var compute_list: int = device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, fade_pipeline)

	var copy_uniforms: Array[RDUniform] = [
			_create_sampler_uniform(pong_texture, 0),
			_create_image_uniform(ping_texture, 1),
			_create_buffer_uniform(copy_buffer, 2)]
	var copy_set: RID = device.uniform_set_create(copy_uniforms, fade_shader, 0)
	device.compute_list_bind_uniform_set(compute_list, copy_set, 0)
	device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
	device.compute_list_add_barrier(compute_list)

	_process_frame(compute_list, effects, transition_left, fade_in, transition_right, fade_out, frame_nr)
	device.free_rid(copy_set)


func cleanup() -> void:
	ping_texture = Utils.cleanup_rid(device, ping_texture)
	pong_texture = Utils.cleanup_rid(device, pong_texture)
	default_sampler = Utils.cleanup_rid(device, default_sampler)

	# Video cleanup
	y_texture = Utils.cleanup_rid(device, y_texture)
	u_texture = Utils.cleanup_rid(device, u_texture)
	v_texture = Utils.cleanup_rid(device, v_texture)
	a_texture = Utils.cleanup_rid(device, a_texture)
	yuv_params = Utils.cleanup_rid(device, yuv_params)
	yuv_pipeline = Utils.cleanup_rid(device, yuv_pipeline)
	yuv_shader = Utils.cleanup_rid(device, yuv_shader)

	# Image cleanup.
	base_image = Utils.cleanup_rid(device, base_image)

	fade_pipeline = Utils.cleanup_rid(device, fade_pipeline)
	fade_shader = Utils.cleanup_rid(device, fade_shader)
	fade_buffer = Utils.cleanup_rid(device, fade_buffer)
	fade_in_buffer = Utils.cleanup_rid(device, fade_in_buffer)
	fade_out_buffer = Utils.cleanup_rid(device, fade_out_buffer)
	copy_buffer = Utils.cleanup_rid(device, copy_buffer)

	for shader_path: String in effects_cache:
		effects_cache[shader_path].free_rids(device)
	effects_cache.clear()

	for buffers: Array in effect_buffers.values():
		for buffer: RID in buffers:
			@warning_ignore("return_value_discarded")
			Utils.cleanup_rid(device, buffer)
	effect_buffers.clear()

	if display_texture:
		display_texture.texture_rd_rid = RID()
	initialized = false


func _update_effect_buffers(effects: Array[EffectVisual], current_frame: int) -> void:
	var active_ids: Array[int] = []
	for effect: EffectVisual in effects:
		if not effect.is_enabled: continue

		var cache: EffectCache = _get_effect_pipeline(effect.shader_path, effect)
		if not cache: continue

		var id: int = effect.get_instance_id()
		active_ids.append(id)
		if not effect_buffers.has(id):
			effect_buffers[id] = []

		var buffers: Array = effect_buffers[id]

		if buffers.size() != effect.shader_passes:
			for buffer: RID in buffers:
				@warning_ignore("return_value_discarded")
				Utils.cleanup_rid(device, buffer)
			buffers.clear()

			for i: int in effect.shader_passes:
				var buffer_data: PackedByteArray = cache.get_buffer_data(effect, current_frame, resolution, i)
				buffers.append(device.uniform_buffer_create(buffer_data.size(), buffer_data))
		else:
			for i: int in effect.shader_passes:
				var buffer_data: PackedByteArray = cache.get_buffer_data(effect, current_frame, resolution, i)
				if device.buffer_update(buffers[i] as RID, 0, buffer_data.size(), buffer_data):
					printerr("VisualCompositor: Coudln't update buffer data!")

	var known_ids: Array = effect_buffers.keys()
	for buffer_id: int in known_ids:
		if buffer_id in active_ids: continue
		for buffer: RID in effect_buffers[buffer_id]:
			@warning_ignore("return_value_discarded")
			Utils.cleanup_rid(device, buffer)

		if !effect_buffers.erase(buffer_id):
			printerr("VisualCompositor: Failed to erase '%s' from effect_buffers!" % buffer_id)


func _process_frame(compute_list: int, effects: Array[EffectVisual], transition_left: EffectVisual, fade_in: float, transition_right: EffectVisual, fade_out: float, _current_frame: int) -> void:
	var sets_to_free: Array[RID] = []
	for effect: EffectVisual in effects:
		if not effect.is_enabled: continue

		var cache: EffectCache = _get_effect_pipeline(effect.shader_path, effect)
		if not cache: continue

		for pass_index: int in effect.shader_passes:
			device.compute_list_bind_compute_pipeline(compute_list, cache.pipeline)

			var effect_uniforms: Array[RDUniform] = [
				_create_sampler_uniform(ping_texture, 0),
				_create_image_uniform(pong_texture, 1),
				_create_buffer_uniform(effect_buffers[effect.get_instance_id()][pass_index] as RID, 2)]
			var effect_set: RID = device.uniform_set_create(effect_uniforms, cache.shader, 0)
			sets_to_free.append(effect_set)

			device.compute_list_bind_uniform_set(compute_list, effect_set, 0)
			device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
			device.compute_list_add_barrier(compute_list)

			var temp_texture: RID = ping_texture
			ping_texture = pong_texture
			pong_texture = temp_texture

	if fade_in < 1.0 and transition_left:
		_apply_transition(compute_list, transition_left, fade_in, fade_in_buffer, sets_to_free)

	if fade_out < 1.0 and transition_right:
		_apply_transition(compute_list, transition_right, fade_out, fade_out_buffer, sets_to_free)

	device.compute_list_end()
	display_texture.texture_rd_rid = ping_texture
	for rid: RID in sets_to_free:
		device.free_rid(rid)


func _update_transition_buffers(transition_left: EffectVisual, fade_in: float, transition_right: EffectVisual, fade_out: float) -> void:
	_update_fade_buffer(fade_in, transition_left, fade_in_buffer)
	_update_fade_buffer(fade_out, transition_right, fade_out_buffer)


func _update_fade_buffer(fade: float, transition: EffectVisual, buffer: RID) -> void:
	if fade >= 1.0 or !transition: return

	var buffer_data: PackedByteArray = PackedByteArray()
	var err: int = buffer_data.resize(16)
	if err != OK:
		printerr("VisualCompositor: Resizing 'fade_buffer_data' failed with '%s'!" % err)

	buffer_data.encode_float(0, fade)
	err = device.buffer_update(buffer, 0, 16, buffer_data)
	if err != OK:
		printerr("VisualCompositor: Updating device 'fade_buffer' failed with '%s'!" % err)


func _apply_transition(compute_list: int, transition: EffectVisual, _progress: float, progress_buffer: RID, sets_to_free: Array[RID]) -> void:
	var cache: EffectCache = _get_effect_pipeline(transition.shader_path, transition)
	if not cache: return

	for pass_index: int in transition.shader_passes:
		device.compute_list_bind_compute_pipeline(compute_list, cache.pipeline)

		var effect_uniforms: Array[RDUniform] = [
			_create_sampler_uniform(ping_texture, 0),
			_create_image_uniform(pong_texture, 1),
			_create_buffer_uniform(effect_buffers[transition.get_instance_id()][pass_index] as RID, 2),
			_create_buffer_uniform(progress_buffer, 3)]
		var effect_set: RID = device.uniform_set_create(effect_uniforms, cache.shader, 0)
		sets_to_free.append(effect_set)

		device.compute_list_bind_uniform_set(compute_list, effect_set, 0)
		device.compute_list_dispatch(compute_list, groups_x, groups_y, 1)
		device.compute_list_add_barrier(compute_list)

		var temp_texture: RID = ping_texture
		ping_texture = pong_texture
		pong_texture = temp_texture


func _create_yuv_params(video: Video) -> RID:
	var yuv_buffer_data: PackedByteArray = PackedByteArray()
	var stream_writer: StreamPeerBuffer = StreamPeerBuffer.new()
	var matrix_data: PackedFloat32Array

	if yuv_buffer_data.resize(YUV_PARAM_BUFFER_SIZE):
		printerr("VisualCompositor: Couldn't resize yuv_buffer_data!")
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
	stream_writer.put_32(video.get_y_data().get_width())
	stream_writer.put_32(video.get_u_data().get_width())
	stream_writer.put_32(video.get_actual_width())
	stream_writer.put_32(video.get_resolution().y)
	stream_writer.put_32(0) # Necessary padding.

	return device.uniform_buffer_create(stream_writer.data_array.size(), stream_writer.data_array)


func _create_storage_buffer(size_bytes: int) -> RID:
	var buffer_data: PackedByteArray = []
	if buffer_data.resize(size_bytes):
		printerr("VisualCompositor: Couldn't resize buffer data for creating storage buffer!")
	return device.storage_buffer_create(size_bytes, buffer_data)


func _create_sampler_uniform(texture_rid: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = device.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(default_sampler)
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


func _get_effect_pipeline(shader_path: String, effect: EffectVisual) -> EffectCache:
	if shader_path.is_empty(): return null
	if effects_cache.has(shader_path):
		return effects_cache[shader_path]

	var shader_file: RDShaderFile
	if EffectsHandler.shader_cache.has(shader_path):
		shader_file = EffectsHandler.shader_cache[shader_path]
	else:
		shader_file = load(shader_path) as RDShaderFile
		EffectsHandler.shader_cache[shader_path] = shader_file

	var effect_cache: EffectCache = EffectCache.new()
	if not shader_file is RDShaderFile:
		printerr("VisualCompositor: Effect shader is not RDShaderFile (compute shader): ", shader_path)
		return null

	effect_cache.initialize(device, shader_file.get_spirv(), effect)
	effects_cache[shader_path] = effect_cache
	return effect_cache
