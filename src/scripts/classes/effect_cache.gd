class_name EffectCache
extends RefCounted

var nickname: String

var shader: RID
var pipeline: RID

var _effect: GoZenEffectVisual
var _frame_nr: int = -1
var _resolution: Vector2i


func initialize(device: RenderingDevice, spirv: RDShaderSPIRV, effect: GoZenEffectVisual) -> void:
	nickname = effect.nickname
	shader = device.shader_create_from_spirv(spirv)
	pipeline = device.compute_pipeline_create(shader)


func get_buffer_data(effect: GoZenEffectVisual, frame_nr: int, resolution: Vector2i) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	var processed_matrices: Array[Matrix.TYPE] = []

	_effect = effect
	_frame_nr = frame_nr
	_resolution = resolution

	for effect_param: EffectParam in effect.params:
		# First do matrix handling
		if effect_param.id in effect.matrix_map:
			var matrix_type: Matrix.TYPE = effect.matrix_map[effect_param.id]

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
				stream.put_32(value as int)
			TYPE_FLOAT:
				_pad_stream(stream, 4)
				stream.put_float(value as float)
			TYPE_VECTOR2, TYPE_VECTOR2I:
				_pad_stream(stream, 8)
				stream.put_float(value.x as float)
				stream.put_float(value.y as float)
			TYPE_VECTOR3, TYPE_VECTOR3I:
				_pad_stream(stream, 16)
				stream.put_float(value.x as float)
				stream.put_float(value.y as float)
				stream.put_float(value.z as float)
			TYPE_VECTOR4, TYPE_VECTOR4I:
				_pad_stream(stream, 16)
				stream.put_float(value.x as float)
				stream.put_float(value.y as float)
				stream.put_float(value.z as float)
				stream.put_float(value.w as float)
			TYPE_COLOR:
				_pad_stream(stream, 16)
				stream.put_float(value.r as float)
				stream.put_float(value.g as float)
				stream.put_float(value.b as float)
				stream.put_float(value.a as float)
			_: printerr("EffectCache: Unsupported type! %s-%s" % [value, typeof(value)])

	var buffer_data: PackedByteArray = stream.data_array
	var padding: int = 16 - (buffer_data.size() % 16)

	if padding != 0: # Add final padding
		buffer_data.resize(buffer_data.size() + padding)

	return buffer_data


func _handle_matrix(type: Matrix.TYPE) -> PackedFloat32Array:
	var data: Dictionary[String, Variant] = {}
	var param_map: Dictionary[String, EffectParam] = {}

	for effect_param: EffectParam in _effect.params:
		param_map[effect_param.id] = effect_param

	# Proxy adjustments
	var project_resolution: Vector2 = Vector2(Project.get_resolution())
	var current_resolution: Vector2 = Vector2(_resolution)
	var ratio: Vector2 = Vector2(1, 1)

	ratio = current_resolution / project_resolution

	match type:
		Matrix.TYPE.TRANSFORM:
			for key: String in Matrix.get_transform_matrix_variables():
				data[key] = _effect.get_value(param_map[key], _frame_nr)

				if key == "position" or key == "size" or key == "pivot":
					data[key] = data[key] * ratio
			return Matrix.calculate_transform_matrix(data, _resolution)
		_:
			printerr("EffectCache: Invalid matrix data type! %s" % type)
			return []


func free_rids(device: RenderingDevice) -> void:
	pipeline = Utils.cleanup_rid(device, pipeline)
	shader = Utils.cleanup_rid(device, shader)


func _pad_stream(stream_buffer: StreamPeerBuffer, alignment: int) -> void:
	var current_offset: int = stream_buffer.get_position()
	var remainder: int = current_offset % alignment

	if remainder != 0:
		for i: int in alignment - remainder:
			stream_buffer.put_8(0)


func _to_string() -> String:
	return "<EffectCache:%s-%s>" % [nickname, get_instance_id()]
