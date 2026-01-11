class_name GoZenEffect
extends Resource


@export var is_enabled: bool = true
@export var keyframes: Dictionary = {} ## { param_name: { frame_number: value }}


var _key_cache: Dictionary = {}
var _cache_dirty: bool = true # TODO: Set this to true, whenever the UI changes a keyframe!



func get_value(param_name: String, default_value: Variant, frame_nr: int) -> Variant:
	if not keyframes.has(param_name) or keyframes[param_name].is_empty():
		return default_value

	var sorted_keys: Array = _validate_cache(param_name)

	if sorted_keys.is_empty():
		return default_value
	elif frame_nr <= sorted_keys[0]:
		return keyframes[param_name][sorted_keys[0]]
	elif frame_nr >= sorted_keys[-1]:
		return keyframes[param_name][sorted_keys[-1]]

	var prev_frame: int = sorted_keys[0]
	var next_frame: int = sorted_keys[-1]

	for key: int in sorted_keys:
		if key <= frame_nr:
			prev_frame = key
		if key > frame_nr:
			next_frame = key
			break

	var difference: float = float(next_frame - prev_frame)

	if difference == 0:
		return keyframes[param_name][prev_frame]

	var weight: float = float(frame_nr - prev_frame) / difference
	var value_a: Variant = keyframes[param_name][prev_frame]
	var value_b: Variant = keyframes[param_name][next_frame]

	return _interpolate_variant(value_a, value_b, weight)


func _validate_cache(param_name: String) -> PackedInt64Array:
	if _cache_dirty or not _key_cache.has(param_name):
		var keys: PackedInt64Array = []

		if keyframes.has(param_name):
			keys = keyframes[param_name].keys()
			keys.sort()

		_key_cache[param_name] = keys
	return _key_cache[param_name]


# TODO: Implement different interpolation types
func _interpolate_variant(value_a: Variant, value_b: Variant, weight: float) -> Variant:
	if typeof(value_a) == TYPE_FLOAT or typeof(value_a) == TYPE_INT:
		return lerp(float(value_a), float(value_b), weight)
	elif value_a is Vector2:
		return value_a.lerp(value_b, weight)
	elif value_a is Vector3:
		return value_a.lerp(value_b, weight)
	elif value_a is Color:
		return value_a.lerp(value_b, weight)

	return value_a # Fallback
