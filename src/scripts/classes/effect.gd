class_name Effect
extends Resource

@export var id: String
@export var nickname: String
@export var tooltip: String

@export var custom_ui_path: String ## UID which leads to the EffectUI.

@export var params: Array[EffectParam]
@export var is_enabled: bool = true


var keyframes: Dictionary = {} ## { param_id: { frame_number: value }}

var _key_cache: Dictionary = {}
var _cache_dirty: bool = true



func get_custom_ui() -> EffectUI:
	if not custom_ui_path.is_empty() and ResourceLoader.exists(custom_ui_path):
		return (load(custom_ui_path) as GDScript).new()
	return null


func get_value(effect_param: EffectParam, frame_nr: int) -> Variant:
	var param_id: String = effect_param.id
	var sorted_keys: PackedInt64Array = _validate_cache(param_id)

	if sorted_keys.is_empty():
		return effect_param.default_value
	elif frame_nr <= sorted_keys[0]:
		return keyframes[param_id][sorted_keys[0]]
	elif frame_nr >= sorted_keys[-1]:
		return keyframes[param_id][sorted_keys[-1]]

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
		return keyframes[param_id][prev_frame]

	var weight: float = float(frame_nr - prev_frame) / difference
	var value_a: Variant = keyframes[param_id][prev_frame]
	var value_b: Variant = keyframes[param_id][next_frame]
	return _interpolate_variant(value_a, value_b, weight)


func deep_copy() -> Effect:
	var copy: Effect = self.duplicate(true)
	copy.keyframes = duplicate_keyframes(self.keyframes)
	copy._cache_dirty = true

	var new_params: Array[EffectParam] = []
	for param: EffectParam in self.params:
		new_params.append(param.duplicate(true))
	copy.params = new_params

	return copy


static func duplicate_keyframes(source_keyframes: Dictionary) -> Dictionary:
	var duplicated_keyframes: Dictionary = {}
	for param_id: String in source_keyframes:
		var param_keyframes: Dictionary = source_keyframes[param_id]
		var new_param_keyframes: Dictionary = {}
		for frame: int in param_keyframes:
			var value: Variant = param_keyframes[frame]

			@warning_ignore_start("unsafe_method_access")
			if value is Resource:
				new_param_keyframes[frame] = value.duplicate(true)
			elif typeof(value) == TYPE_ARRAY or typeof(value) == TYPE_DICTIONARY:
				new_param_keyframes[frame] = value.duplicate(true)
			else:
				new_param_keyframes[frame] = value
			@warning_ignore_restore("unsafe_method_access")

		duplicated_keyframes[param_id] = new_param_keyframes
	return duplicated_keyframes


func change_default_param(param_id: String, new_default: Variant) -> void:
	for effect_param: EffectParam in params:
		if effect_param.id == param_id:
			effect_param.default_value = new_default
			return


func set_default_keyframe() -> void:
	for effect_param: EffectParam in params:
		var param_id: String = effect_param.id
		if not keyframes.has(param_id):
			var typed_dict: Dictionary[int, Variant] = {}
			keyframes[param_id] = typed_dict
		var param_keyframe: Dictionary = keyframes[param_id]
		if not param_keyframe.has(0):
			keyframes[param_id][0] = effect_param.default_value
	_cache_dirty = true


func _validate_cache(param_id: String) -> PackedInt64Array:
	if _cache_dirty:
		_key_cache.clear()
		_cache_dirty = false

	if not _key_cache.has(param_id):
		var param_keyframes: Dictionary = keyframes[param_id]
		var keys: Array = param_keyframes.keys()
		keys.sort()
		_key_cache[param_id] = PackedInt64Array(keys)

	return _key_cache[param_id]


#--- Data handling ---

func serialize() -> Dictionary:
	var keyframe_dict: Dictionary = {}
	for param_id: String in keyframes:
		keyframe_dict[param_id] = {}
		for frame: int in keyframes[param_id]:
			keyframe_dict[param_id][frame] = keyframes[param_id][frame]

	var data: Dictionary = { "id": id, "keyframes": keyframe_dict }
	if !is_enabled:
		data["is_enabled"] = false
	return data


func deserialize(dict: Dictionary) -> void:
	is_enabled = dict.get("is_enabled", true)
	if dict.has("keyframes"):
		var keyframe_dict: Dictionary = dict["keyframes"]
		keyframes.clear()
		for param_id: String in keyframe_dict:
			var frames: Dictionary = keyframe_dict[param_id]
			var typed_frames: Dictionary[int, Variant] = {}
			for frame_key: int in frames:
				typed_frames[frame_key] = frames[frame_key]
			keyframes[param_id] = typed_frames
	_cache_dirty = true


#--- Interpolation handling ---

# TODO: Implement different interpolation types
static func _interpolate_variant(value_a: Variant, value_b: Variant, weight: float) -> Variant:
	match typeof(value_a):
		TYPE_FLOAT, TYPE_INT:
			return lerp(value_a as float, value_b as float, weight)
		TYPE_VECTOR2:
			return (value_a as Vector2).lerp(value_b as Vector2, weight)
		TYPE_VECTOR2I:
			return Vector2i((value_a as Vector2).lerp(value_b as Vector2, weight))
		TYPE_VECTOR3:
			return (value_a as Vector3).lerp(value_b as Vector3, weight)
		TYPE_VECTOR3I:
			return Vector3i((value_a as Vector3).lerp(value_b as Vector3, weight))
		TYPE_COLOR:
			return (value_a as Color).lerp(value_b as Color, weight)
		TYPE_PACKED_VECTOR2_ARRAY:
			var arr_a: PackedVector2Array = value_a
			var arr_b: PackedVector2Array = value_b
			var result: PackedVector2Array = PackedVector2Array()
			var size: int = maxi(arr_a.size(), arr_b.size())
			for i: int in size:
				var pt_a: Vector2 = arr_a[i] if i < arr_a.size() else (arr_b[i] if arr_a.is_empty() else arr_a[-1])
				var pt_b: Vector2 = arr_b[i] if i < arr_b.size() else (arr_a[i] if arr_b.is_empty() else arr_b[-1])
				var _err: int = result.append(pt_a.lerp(pt_b, weight))
			return result
		_: return value_a # Fallback.
