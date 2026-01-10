class_name VisualEffect
extends Resource

enum PARAM_TYPE { FLOAT, COLOR, INT, VEC2, VEC3, VEC4, IVEC2, IVEC3, IVEC4, MAT4 }


@export var effect_name: String
@export var shader_path: String
@export var params: Array[VisualEffectParam] = []


# { frame_nr : (dictionary of all changed params) }
# Each dictionary is { param_id: value }
var frames: Dictionary[int, Dictionary] = {}
var enabled: bool = true

var _frames_cache: Array[int] = [] # Sorted cache
var _cache_dirty: bool = true



func add_keyframe(frame_nr: int, param_id: String, value: Variant) -> void:
	if not frames.has(frame_nr):
		frames[frame_nr] = {}
	
	frames[frame_nr][param_id] = value
	_cache_dirty = true


func remove_keyframe(frame_nr: int, param_id: String) -> void:
	if frames.has(frame_nr):
		frames[frame_nr].erase(param_id)

		if frames[frame_nr].is_empty():
			frames.erase(frame_nr)
			_cache_dirty = true


func get_param_value(param_id: String, frame_nr: int) -> Variant:
	# Update cache if needed
	if _cache_dirty:
		_frames_cache = frames.keys()
		_frames_cache.sort()
		_cache_dirty = false

	# Filter frames
	# TODO: probably not the best way of doing this:
	var relevant_frames: Array[int] = []

	for cache_frame_nr: int in _frames_cache:
		if frames[cache_frame_nr].has(param_id):
			relevant_frames.append(cache_frame_nr)

	# Return default if nothing found
	if relevant_frames.is_empty():
		return _get_default_value(param_id)

	# Find keyframes before and after current frame
	var prev_frame: int = -1
	var next_frame: int = -1

	for relevant_frame_nr: int in relevant_frames:
		if relevant_frame_nr <= frame_nr:
			prev_frame = relevant_frame_nr
		elif relevant_frame_nr > frame_nr:
			next_frame = relevant_frame_nr
			break

	if prev_frame == -1:
		return frames[next_frame][param_id] # Should not happen, but just in case
	elif next_frame == -1:
		return frames[prev_frame][param_id] # This is the last frame_nr
	elif prev_frame == frame_nr:
		return frames[prev_frame][param_id] # Exact match

	# Linear interpolation
	# TODO: Find a way to let users choose which interpolation they want
	return _interpolate(frames[prev_frame][param_id], frames[next_frame][param_id],
						float(frame_nr - prev_frame) / float(next_frame - prev_frame))


func get_param_types() -> Array[PARAM_TYPE]:
	var types: Array[VisualEffect.PARAM_TYPE] = []

	for param: VisualEffectParam in params:
		types.append(param.type)

	return types


func _get_default_value(param_id: String) -> Variant:
	for param: VisualEffectParam in params:
		if param.param_id == param_id:
			return param.default_value

	return 0.0 # Error


func _interpolate(value_a: Variant, value_b: Variant, weight: float) -> Variant:
	# GDScript types handle lerping differently
	if typeof(value_a) == TYPE_FLOAT or typeof(value_a) == TYPE_INT:
		return lerp(float(value_a), float(value_b), weight)
	elif value_a is Vector2:
		return value_a.lerp(value_b, weight)
	elif value_a is Vector3:
		return value_a.lerp(value_b, weight)
	elif value_a is Color:
		return value_a.lerp(value_b, weight)
	
	return value_a # For bools and strings


func _to_string() -> String:
	return "<VideoEffect: %s>" % effect_name
