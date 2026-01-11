class_name EffectCache
extends RefCounted

var shader: RID
var pipeline: RID

var buffer: RID
var buffer_size: int
var data: PackedByteArray = PackedByteArray()

var _frame_nr: int = 0
var _matrix_data_map: Dictionary[String, MatrixData]



func initialize(device: RenderingDevice, spirv: RDShaderSPIRV, effect: VisualEffect) -> void:
	var empty_buffer: PackedByteArray = PackedByteArray()

	_matrix_data_map = effect.matrix_data

	shader = device.shader_create_from_spirv(spirv)
	pipeline = device.compute_pipeline_create(shader)
	buffer_size = calculate_std140_size(effect)
	empty_buffer.resize(buffer_size)
	buffer = device.uniform_buffer_create(buffer_size, empty_buffer)


func pack_effect_params(effect: VisualEffect, frame_nr: int) -> void:
	var stream_writer: StreamPeerBuffer = StreamPeerBuffer.new()
	var processed_matrices: Array[MatrixData.MATRIX] = []

	_frame_nr = frame_nr
	_matrix_data_map = effect.matrix_data

	for effect_param: EffectParam in effect.params:
		var param_id: String = effect_param.param_id

		# Matrix handling
		if _matrix_data_map.has(param_id):
			var matrix_data: MatrixData = _matrix_data_map[param_id]
			var matrix_type: MatrixData.MATRIX = matrix_data.matrix

			if matrix_type in processed_matrices:
				continue
			elif matrix_type == MatrixData.MATRIX.TRANSFORM:
				var matrix_floats: PackedFloat32Array = _matrix_transform(effect, matrix_type)

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

	data = stream_writer.data_array

	if data.size() < buffer_size:
		data.resize(buffer_size) # Add padding if needed to end


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

			# MAT4 = 64, MAT3 = 48
			match _matrix_data_map[effect_param.param_id].matrix:
				MatrixData.MATRIX.TRANSFORM: size = 64
				_: continue
		else:
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
				_: continue

		offset += (align - (offset % align)) % align # Padding
		offset += size

	# Adding final padding to offset
	return offset + ((16 - (offset % 16)) % 16)


func free_rids(device: RenderingDevice) -> void:
	shader = Utils.cleanup_rid(device, shader)
	pipeline = Utils.cleanup_rid(device, pipeline)
	buffer = Utils.cleanup_rid(device, buffer)


func _pad_stream(stream_buffer: StreamPeerBuffer, alignment: int) -> void:
	var current_offset: int = stream_buffer.get_position()
	var remainder: int = current_offset % alignment
	
	if remainder != 0:
		for i: int in alignment - remainder:
			stream_buffer.put_8(0)


func _matrix_transform(effect: VisualEffect, type: MatrixData.MATRIX) -> PackedFloat32Array:
	var position: Vector2 = Vector2.ZERO
	var scale: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var pivot: Vector2 = Vector2.ZERO

	for param: EffectParam in effect.params:
		if not _matrix_data_map.has(param.param_id):
			continue
		
		var matrix_data: MatrixData = _matrix_data_map[param.param_id]

		if matrix_data.matrix != type:
			continue

		var value: Variant = effect.get_param_value(param.param_id, _frame_nr)
		
		match matrix_data.type:
			MatrixData.MATRIX_VAR.POSITION: position = value
			MatrixData.MATRIX_VAR.SIZE: scale = Vector2(value) / Vector2(Project.get_resolution())
			MatrixData.MATRIX_VAR.ROTATION: rotation = value
			MatrixData.MATRIX_VAR.PIVOT: pivot = value

	# Calculate matrix
	return MatrixData.calculate_transform_matrix(position, scale, rotation, pivot)
