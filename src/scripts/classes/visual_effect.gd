@abstract
class_name VisualEffect
extends Resource


#---- VARIABLES ----
@export var effect_name: String = "Base Effect" ## Name to display in the UI.
@export var is_enabled: bool = true

@export var keyframes: Dictionary[String, Dictionary] = {} ## { property_name: { frame_nr: value } }



#---- Abstract functions ----
@abstract func get_shader_rid() -> RID ## Returns the RID of the compiled SPIR-V shader.
@abstract func get_effects_panel() -> Container ## The panel which will appear in the effects panel in it's own foldable container with all the options to adjust the variables for the effect.
@abstract func get_buffer_data(frame_nr: int, context_data: Dictionary) -> PackedByteArray


#---- Helper functions ----
func get_value_at(property: String, default_value: Variant, frame_nr: int) -> Variant:
	if not keyframes.has(property) or keyframes[property].is_empty:
		return default_value

	return _interpolate_keyframes(keyframes[property], frame_nr)


func _interpolate_keyframes(data: Dictionary[int, Variant], frame_nr: int) -> Variant:
	var sorted_frames: PackedInt64Array = data.keys()

	sorted_frames.sort()

	if frame_nr <= sorted_frames[0]:
		return data[sorted_frames[0]]
	elif frame_nr >= sorted_frames[-1]:
		return data[sorted_frames[-1]]

	var prev_frame_nr: int = sorted_frames[0]
	var next_frame_nr: int = sorted_frames[-1]

	for sorted_frame_nr: int in sorted_frames:
		if sorted_frame_nr <= frame_nr:
			prev_frame_nr = sorted_frame_nr
		if sorted_frame_nr > frame_nr:
			next_frame_nr = sorted_frame_nr
			break

	var weight: float = float(frame_nr - prev_frame_nr) / float(next_frame_nr - prev_frame_nr)

	return lerp(data[prev_frame_nr], data[next_frame_nr], weight)


func _to_string() -> String:
	return "<VideoEffect: %s>" % effect_name


#---- Buffer helper functions ----
func push_int(buffer: StreamPeerBuffer, value: int) -> void:
	buffer.put_32(value)


func push_float(buffer: StreamPeerBuffer, value: float) -> void:
	buffer.put_float(value)


func push_vec2(buffer: StreamPeerBuffer, value: Vector2) -> void:
	_align_buffer(buffer, 8)
	buffer.put_float(value.x)
	buffer.put_float(value.y)


func push_vec3(buffer: StreamPeerBuffer, value: Vector3) -> void:
	_align_buffer(buffer, 16)
	buffer.put_float(value.x)
	buffer.put_float(value.y)
	buffer.put_float(value.z)
	buffer.put_float(0.0)


func push_vec4(buffer: StreamPeerBuffer, value: Vector4) -> void:
	_align_buffer(buffer, 16)
	buffer.put_float(value.x)
	buffer.put_float(value.y)
	buffer.put_float(value.z)
	buffer.put_float(value.w)


func push_color(buffer: StreamPeerBuffer, value: Color) -> void:
	_align_buffer(buffer, 16)
	buffer.put_float(value.r)
	buffer.put_float(value.g)
	buffer.put_float(value.b)
	buffer.put_float(value.a)


func push_mat3(buffer: StreamPeerBuffer, value: PackedFloat32Array) -> void:
	if value.size() != 9:
		push_error("VisualEffect: push_mat3 expects 9 floats! Only got %d!" % value.size())
		return

	_align_buffer(buffer, 16)
	
	# Column 0
	buffer.put_float(value[0])
	buffer.put_float(value[1])
	buffer.put_float(value[2])
	buffer.put_float(0.0) # Padding
	
	# Column 0
	buffer.put_float(value[3])
	buffer.put_float(value[4])
	buffer.put_float(value[5])
	buffer.put_float(0.0) # Padding

	# Column 1
	buffer.put_float(value[6])
	buffer.put_float(value[7])
	buffer.put_float(value[8])
	buffer.put_float(0.0) # Padding


func push_mat4(buffer: StreamPeerBuffer, value: PackedFloat32Array) -> void:
	if value.size() != 16:
		push_error("VisualEffect: push_mat4 expects 16 floats! Only got %d!" % value.size())
		return

	_align_buffer(buffer, 16)

	for float_value: float in value:
		buffer.put_float(float_value)


func _align_buffer(buffer: StreamPeerBuffer, alignment: int) -> void:
	var offset: int = buffer.get_position()
	var padding: int = (alignment - (offset % alignment)) % alignment

	for i: int in padding:
		buffer.put_8(0)
