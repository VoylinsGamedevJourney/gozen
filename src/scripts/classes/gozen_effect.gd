class_name GoZenEffect
extends Resource


@export var effect_id: String
@export var effect_name: String
@export var effect_tooltip: String

@export var params: Array[EffectParam]
@export var is_enabled: bool = true


var keyframes: Dictionary = {} ## { param_id: { frame_number: value }}


var _key_cache: Dictionary = {}
var _cache_dirty: bool = true



func get_value(effect_param: EffectParam, frame_nr: int) -> Variant:
	var id: String = effect_param.param_id
	var sorted_keys: Array = _validate_cache(id)

	if sorted_keys.is_empty():
		return effect_param.default_value
	elif frame_nr <= sorted_keys[0]:
		return keyframes[id][sorted_keys[0]]
	elif frame_nr >= sorted_keys[-1]:
		return keyframes[id][sorted_keys[-1]]

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
		return keyframes[id][prev_frame]

	var weight: float = float(frame_nr - prev_frame) / difference
	var value_a: Variant = keyframes[id][prev_frame]
	var value_b: Variant = keyframes[id][next_frame]

	return _interpolate_variant(value_a, value_b, weight)


func change_default_param(param_id: String, new_default: Variant) -> void:
	for effect_param: EffectParam in params:
		if effect_param.param_id == param_id:
			effect_param.default_value = new_default
			return


func set_default_keyframe() -> void:
	for effect_param: EffectParam in params:
		var param_id: String = effect_param.param_id

		if not keyframes.has(param_id):
			keyframes[param_id] = {}
		if not keyframes[param_id].has(0):
			keyframes[param_id][0] = effect_param.default_value

	_cache_dirty = true


func _validate_cache(param_id: String) -> PackedInt64Array:
	if _cache_dirty:
		_key_cache.clear()
		_cache_dirty = false

	if not _key_cache.has(param_id):
		var keys: PackedInt64Array = []

		if keyframes.has(param_id):
			keys = keyframes[param_id].keys()
			keys.sort()

		_key_cache[param_id] = keys

	return _key_cache[param_id]


# TODO: Implement different interpolation types
func _interpolate_variant(value_a: Variant, value_b: Variant, weight: float) -> Variant:
	if typeof(value_a) == TYPE_FLOAT or typeof(value_a) == TYPE_INT:
		return lerp(float(value_a), float(value_b), weight)
	elif value_a is Vector2:
		return value_a.lerp(value_b, weight)
	elif value_a is Vector2i:
		return Vector2i(Vector2(value_a).lerp(Vector2(value_b), weight))
	elif value_a is Vector3:
		return value_a.lerp(value_b, weight)
	elif value_a is Vector3i:
		return Vector3i(Vector3(value_a).lerp(Vector3(value_b), weight))
	elif value_a is Color:
		return value_a.lerp(value_b, weight)

	return value_a # Fallback
