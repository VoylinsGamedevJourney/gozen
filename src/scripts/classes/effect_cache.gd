class_name EffectCache
extends RefCounted

var effect_name: String

var shader: RID
var pipeline: RID

var buffer: RID
var buffer_data: PackedByteArray

var _effect: GoZenEffectVisual
var _frame_nr: int = -1
var _resolution: Vector2i



func initialize(device: RenderingDevice, spirv: RDShaderSPIRV, effect: GoZenEffectVisual) -> void:
	effect_name = effect.effect_name
	shader = device.shader_create_from_spirv(spirv)
	pipeline = device.compute_pipeline_create(shader)

	process_buffer(effect, 0, Vector2i(1920, 1080)) # Dummy run
	buffer = device.uniform_buffer_create(buffer_data.size(), buffer_data)


func process_buffer(effect: GoZenEffectVisual, frame_nr: int, resolution: Vector2i) -> void:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	var processed_matrices: Array[MatrixHandler.TYPE] = []

	_effect = effect
	_frame_nr = frame_nr
	_resolution = resolution

	for effect_param: EffectParam in effect.params:
		# First do matrix handling
		if effect_param.param_id in effect.matrix_map:
			var matrix_type: MatrixHandler.TYPE = effect.matrix_map[effect_param.param_id]

			if matrix_type not in processed_matrices:
				_pad_stream(stream, 16)
				for value: float in _handle_matrix(matrix_type):
					stream.put_float(value)

				processed_matrices.append(matrix_type)
			continue

		# Next up individual variable handling
		var value: Variant = effect.get_value(effect_param, _frame_nr)

		match typeof(value):
			TYPE_INT:
				_pad_stream(stream, 4)
				stream.put_32(value)
			TYPE_FLOAT:
				_pad_stream(stream, 4)
				stream.put_float(value)
			TYPE_VECTOR2, TYPE_VECTOR2I:
				_pad_stream(stream, 8)
				stream.put_float(value.x)
				stream.put_float(value.y)
			TYPE_VECTOR3, TYPE_VECTOR3I:
				_pad_stream(stream, 16)
				stream.put_float(value.x)
				stream.put_float(value.y)
				stream.put_float(value.z)
			TYPE_VECTOR4, TYPE_VECTOR4I:
				_pad_stream(stream, 16)
				stream.put_float(value.x)
				stream.put_float(value.y)
				stream.put_float(value.z)
				stream.put_float(value.w)
			TYPE_COLOR:
				_pad_stream(stream, 16)
				stream.put_float(value.r)
				stream.put_float(value.g)
				stream.put_float(value.b)
				stream.put_float(value.a)
			_: printerr("EffectCache: Unsupported type! %s-%s" % [value, typeof(value)])

	buffer_data = stream.data_array

	var padding: int = 16 - (buffer_data.size() % 16)

	if padding != 0: # Add final padding
		buffer_data.resize(buffer_data.size() + padding)


func _handle_matrix(type: MatrixHandler.TYPE) -> PackedFloat32Array:
	var data: Dictionary[String, Variant] = {}
	var param_map: Dictionary[String, EffectParam] = {}
	
	for effect_param: EffectParam in _effect.params:
		param_map[effect_param.param_id] = effect_param

	match type:
		MatrixHandler.TYPE.TRANSFORM:
			for key: String in MatrixHandler.get_transform_matrix_variables():
				data[key] = _effect.get_value(param_map[key], _frame_nr)

			return MatrixHandler.calculate_transform_matrix(data, _resolution)
		_:
			printerr("EffectCache: Invalid matrix data type! %s" % type)
			return []


func free_rids(device: RenderingDevice) -> void:
	pipeline = Utils.cleanup_rid(device, pipeline)
	shader = Utils.cleanup_rid(device, shader)
	buffer = Utils.cleanup_rid(device, buffer)


func _pad_stream(stream_buffer: StreamPeerBuffer, alignment: int) -> void:
	var current_offset: int = stream_buffer.get_position()
	var remainder: int = current_offset % alignment
	
	if remainder != 0:
		for i: int in alignment - remainder:
			stream_buffer.put_8(0)


func _to_string() -> String:
	return "<EffectCache:%s-%s>" % [effect_name, get_instance_id()]
