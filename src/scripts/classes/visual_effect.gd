@abstract
class_name VisualEffect
extends Resource


#---- VARIABLES ----
@export var is_enabled: bool = true
@export var keyframes: Dictionary[String, Dictionary] = {} ## { property_name: { frame_nr: value } }



#---- Abstract functions ----
@abstract func get_effect_name() -> String ## Name to display in the UI.
@abstract func get_effects_panel() -> Container ## The panel which will appear in the effects panel in it's own foldable container with all the options to adjust the variables for the effect.
@abstract func get_buffer_data(frame_nr: int) -> PackedByteArray ## Returns the stream for binding 2 of the effect's compute shader.



#---- Helper functions ----
func get_shader_rid() -> RID:
	var script_path: String = get_script().resource_path
	var shader_path: String = script_path.get_basename() + ".glsl"

	if !FileAccess.file_exists(shader_path):
		printerr("VisualEffect: No shader found at %s!" % shader_path)
		return RID()

	var shader_file: Variant = load(shader_path)

	if shader_file is RDShaderFile:
		return shader_file.get_spirv()

	printerr("VisualEffect: File '%s' is not an RDShaderFile!" % shader_path)
	return RID()



func get_value_at(property: String, default_value: Variant, frame_nr: int) -> Variant:
	if not keyframes.has(property) or keyframes[property].is_empty:
		return default_value

	return _interpolate_keyframes(keyframes[property], frame_nr)


func _interpolate_keyframes(data: Dictionary[int, Variant], frame_nr: int) -> Variant:
	var sorted_frames: PackedInt64Array = data.keys()

	sorted_frames.sort()

	if sorted_frames.size() == 0:
		return null
	elif frame_nr <= sorted_frames[0]:
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
	return "<VideoEffect: %s-%s>" % [get_effect_name(), get_instance_id()]



#---- Buffer helper functions ----
func push_int(stream: StreamPeerBuffer, value: int) -> void:
	stream.put_32(value)


func push_float(stream: StreamPeerBuffer, value: float) -> void:
	stream.put_float(value)


func push_vec2(stream: StreamPeerBuffer, value: Vector2) -> void:
	_pad_stream(stream, 8)
	stream.put_float(value.x)
	stream.put_float(value.y)


func push_vec3(stream: StreamPeerBuffer, value: Vector3) -> void:
	_pad_stream(stream, 16)
	stream.put_float(value.x)
	stream.put_float(value.y)
	stream.put_float(value.z)
	stream.put_float(0.0)


func push_vec4(stream: StreamPeerBuffer, value: Vector4) -> void:
	_pad_stream(stream, 16)
	stream.put_float(value.x)
	stream.put_float(value.y)
	stream.put_float(value.z)
	stream.put_float(value.w)


func push_color(stream: StreamPeerBuffer, value: Color) -> void:
	_pad_stream(stream, 16)
	stream.put_float(value.r)
	stream.put_float(value.g)
	stream.put_float(value.b)
	stream.put_float(value.a)


func push_mat3(stream: StreamPeerBuffer, value: PackedFloat32Array) -> void:
	if value.size() != 9:
		push_error("VisualEffect: push_mat3 expects 9 floats! Only got %d!" % value.size())
		return

	_pad_stream(stream, 16)
	
	# Column 0
	stream.put_float(value[0])
	stream.put_float(value[1])
	stream.put_float(value[2])
	stream.put_float(0.0) # Padding
	
	# Column 0
	stream.put_float(value[3])
	stream.put_float(value[4])
	stream.put_float(value[5])
	stream.put_float(0.0) # Padding

	# Column 1
	stream.put_float(value[6])
	stream.put_float(value[7])
	stream.put_float(value[8])
	stream.put_float(0.0) # Padding


func push_mat4(stream: StreamPeerBuffer, value: PackedFloat32Array) -> void:
	if value.size() != 16:
		push_error("VisualEffect: push_mat4 expects 16 floats! Only got %d!" % value.size())
		return

	_pad_stream(stream, 16)

	for float_value: float in value:
		stream.put_float(float_value)


func _pad_stream(stream: StreamPeerBuffer, alignment: int) -> void:
	var offset: int = stream.get_position()
	var padding: int = (alignment - (offset % alignment)) % alignment

	for i: int in padding:
		stream.put_8(0)
