class_name EffectCache
extends RefCounted

var shader: RID
var pipeline: RID

var param_buffer: RID
var param_buffer_size: int
var param_data: PackedByteArray = PackedByteArray()

var _frame_nr: int = 0
var _matrix_data_map: Dictionary[String, MatrixData]



func initialize(device: RenderingDevice, spirv: RDShaderSPIRV, effect: VisualEffect) -> void:
	var empty_buffer: PackedByteArray = PackedByteArray()

	shader = device.shader_create_from_spirv(spirv)
	pipeline = device.compute_pipeline_create(shader)
	param_buffer_size = calculate_std140_size(effect)
	empty_buffer.resize(param_buffer_size)
	param_buffer = device.uniform_buffer_create(param_buffer_size, empty_buffer)


func pack_effect_params(effect: VisualEffect, frame_nr: int) -> void:
	var stream_writer: StreamPeerBuffer = StreamPeerBuffer.new()
	_matrix_data_map = effect.matrix_data
	var processed_matrices: Array[MatrixData.MATRIX] = []

	_frame_nr = frame_nr

	for effect_param: EffectParam in effect.params:
		var param_id: String = effect_param.param_id

		# Matrix handling
		if _matrix_data_map.has(param_id):
			var matrix_data: MatrixData = _matrix_data_map[param_id]
			var matrix_type: MatrixData.MATRIX = matrix_data.matrix

			if matrix_type in processed_matrices:
				continue
			elif matrix_type == MatrixData.MATRIX.TRANSFORM:
				var matrix_floats: PackedFloat32Array = _handle_matrix_transform(effect, matrix_type)

				_pad_stream(stream_writer, 16)
				for value: float in matrix_floats:
					stream_writer.put_float(value)

				processed_matrices.append(matrix_type)
			continue
			
		# Individual variable handling
		var value: Variant = effect.get_param_value(effect_param.param_id, _frame_nr)

		if effect_param.type == EffectParam.PARAM_TYPE.FLOAT:
			_pad_stream(stream_writer, 4)
			stream_writer.put_float(value)
		elif effect_param.type == EffectParam.PARAM_TYPE.INT:
			_pad_stream(stream_writer, 4)
			stream_writer.put_32(value)
		elif effect_param.type == EffectParam.PARAM_TYPE.COLOR: #Color should be RGBA
			_pad_stream(stream_writer, 16)
			stream_writer.put_float(value.r)
			stream_writer.put_float(value.g)
			stream_writer.put_float(value.b)
			stream_writer.put_float(value.a)
		elif effect_param.type == EffectParam.PARAM_TYPE.VEC2:
			stream_writer.put_float(value.x)
			stream_writer.put_float(value.y)
		elif effect_param.type == EffectParam.PARAM_TYPE.VEC3:
			_pad_stream(stream_writer, 16)
			stream_writer.put_float(value.x)
			stream_writer.put_float(value.y)
			stream_writer.put_float(value.z)
		elif effect_param.type == EffectParam.PARAM_TYPE.VEC4:
			_pad_stream(stream_writer, 16)
			stream_writer.put_float(value.x)
			stream_writer.put_float(value.y)
			stream_writer.put_float(value.z)
			stream_writer.put_float(value.w)

	param_data = stream_writer.data_array

	if param_data.size() < param_buffer_size:
		param_data.resize(param_buffer_size) # Add padding if needed to end


func calculate_std140_size(effect: VisualEffect) -> int:
	var added_matrix: Array[MatrixData.MATRIX] = []
	var offset: int = 0

	_matrix_data_map = effect.matrix_data

	for effect_param: EffectParam in effect.params:
		var type: EffectParam.PARAM_TYPE = effect_param.type
		var size: int = 0
		var align: int = 16

		if _matrix_data_map.has(effect_param.param_id):
			if added_matrix.has(_matrix_data_map[effect_param.param_id]):
				continue # Already been added

			type = _matrix_data_map[effect_param.param_id].matrix_type

		match type:
			EffectParam.PARAM_TYPE.FLOAT, EffectParam.PARAM_TYPE.INT:
				size = 4
				align = 4
			EffectParam.PARAM_TYPE.VEC2, EffectParam.PARAM_TYPE.IVEC2:
				size = 8
				align = 8
			EffectParam.PARAM_TYPE.COLOR: size = 12
			EffectParam.PARAM_TYPE.VEC3, EffectParam.PARAM_TYPE.IVEC3: size = 12
			EffectParam.PARAM_TYPE.VEC4, EffectParam.PARAM_TYPE.IVEC4: size = 16
			EffectParam.PARAM_TYPE.MAT3: size = 48
			EffectParam.PARAM_TYPE.MAT4: size = 64
			_: continue

		offset += (align - (offset % align)) % align # Padding
		offset += size

	# Adding final padding to offset
	return offset + ((16 - (offset % 16)) % 16)


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


func _handle_matrix_transform(effect: VisualEffect, type: MatrixData.MATRIX) -> PackedFloat32Array:
	var position: Vector2 = Vector2.ZERO
	var scale: float = 1.0
	var rotation: float = 0.0
	var pivot: Vector2 = Vector2.ZERO

	for param: EffectParam in effect.params:
		if not _matrix_data_map.has(param.param_id):
			continue
		
		var matrix_data: MatrixData = _matrix_data_map[param.param_id]

		if matrix_data.matrix != type:
			continue

		var value: Variant = effect.get_param_value(param.param_id, _frame_nr)
		
		match matrix_data.var_type:
			MatrixData.MATRIX_VAR.POSITION: position = value
			MatrixData.MATRIX_VAR.ROTATION: rotation = value
			MatrixData.MATRIX_VAR.SCALE: scale = value
			MatrixData.MATRIX_VAR.PIVOT: pivot = value

	# Calculate matrix
	return MatrixData.calculate_transform_matrix(position, scale, rotation, pivot)
