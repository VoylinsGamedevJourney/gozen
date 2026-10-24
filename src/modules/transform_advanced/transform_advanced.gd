class_name AdvancedTransformEffect
extends Effect


@export var velocities: Dictionary = {}



func get_value(effect_param: EffectParam, frame_nr: int) -> Variant:
	var param_id: String = effect_param.id
	if not keyframes.has(param_id):
		return effect_param.default_value

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
	if difference == 0.0:
		return keyframes[param_id][prev_frame]

	var weight: float = float(frame_nr - prev_frame) / difference
	var value_a: Variant = keyframes[param_id][prev_frame]
	var value_b: Variant = keyframes[param_id][next_frame]
	if typeof(value_a) == TYPE_VECTOR2 or typeof(value_a) == TYPE_VECTOR2I:
		var out_x: Vector2 = _get_bezier_handle(param_id, "x", prev_frame, true)
		var in_x: Vector2 = _get_bezier_handle(param_id, "x", next_frame, false)
		var bezier_x: float = _solve_bezier_param(weight, out_x.x, in_x.x)
		var interpolation_x: float = _bezier_value(
				bezier_x, value_a.x as float, value_a.x as float + out_x.y, value_b.x as float + in_x.y, value_b.x as float)

		var out_y: Vector2 = _get_bezier_handle(param_id, "y", prev_frame, true)
		var in_y: Vector2 = _get_bezier_handle(param_id, "y", next_frame, false)
		var bezier_y: float = _solve_bezier_param(weight, out_y.x, in_y.x)
		var interpolation_y: float = _bezier_value(
				bezier_y, value_a.y as float, value_a.y as float + out_y.y, value_b.y as float + in_y.y, value_b.y as float)
		if typeof(value_a) == TYPE_VECTOR2I:
			return Vector2i(roundi(interpolation_x), roundi(interpolation_y))
		return Vector2(interpolation_x, interpolation_y)
	# Standalone values (floats/ints).
	var out_value: Vector2 = _get_bezier_handle(param_id, "", prev_frame, true)
	var in_value: Vector2 = _get_bezier_handle(param_id, "", next_frame, false)
	var bezier: float = _solve_bezier_param(weight, out_value.x, in_value.x)
	var interpolation: float = _bezier_value(
			bezier, value_a as float, value_a as float + out_value.y, value_b as float + in_value.y, value_b as float)

	if typeof(value_a) == TYPE_INT:
		return roundi(interpolation)
	return interpolation


#--- Bezier handling ---

func _get_bezier_handle(param_id: String, component: String, frame_nr: int, is_out: bool) -> Vector2:
	var handle_data: Vector4 = Vector4(0.33, 0.0, 0.33, 0.0)
	var handle_key: String = param_id + ":" + component + ":" + str(frame_nr)
	if velocities.has(handle_key):
		handle_data = velocities[handle_key]
	elif velocities.has(frame_nr):
		handle_data = velocities[frame_nr]
		handle_data.y = 0.0
		handle_data.w = 0.0

	if is_out:
		return Vector2(handle_data.z, handle_data.w)
	else:
		return Vector2(1.0 - handle_data.x, handle_data.y)


func _solve_bezier_param(target_progress: float, first_control: float, second_control: float) -> float:
	if target_progress <= 0.0 or target_progress >= 1.0:
		return clampf(target_progress, 0.0, 1.0)

	var current_bezier: float = target_progress
	for iteration: int in 8:
		var current_x: float = _bezier_value(current_bezier, 0.0, first_control, second_control, 1.0)
		var difference: float = current_x - target_progress
		if abs(difference) < 0.001:
			break

		var inverse_bezier: float = 1.0 - current_bezier
		var start: float = 3.0 * inverse_bezier * inverse_bezier * first_control
		var middle: float = 6.0 * inverse_bezier * current_bezier * (second_control - first_control)
		var end: float = 3.0 * current_bezier * current_bezier * (1.0 - second_control)
		var bezier_slope_x: float = start + middle + end
		if abs(bezier_slope_x) < 1e-6:
			break

		current_bezier -= difference / bezier_slope_x
	return current_bezier


func _bezier_value(bezier: float, start: float, first_control: float, second_control: float, end: float) -> float:
	var inversed_param: float = 1.0 - bezier
	var inversed_param_squared: float = inversed_param * inversed_param
	var param_squared: float = bezier * bezier

	var new_start: float = inversed_param_squared * inversed_param * start
	var new_first_control: float = 3.0 * inversed_param_squared * bezier * first_control
	var new_second_control: float = 3.0 * inversed_param * param_squared * second_control
	var new_end: float = param_squared * bezier * end
	return new_start + new_first_control + new_second_control + new_end


#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = super.serialize()
	var serialized_velocities: Dictionary = {}
	for k: Variant in velocities:
		var velocity: Vector4 = velocities[k]
		serialized_velocities[str(k)] = [velocity.x, velocity.y, velocity.z, velocity.w]

	data["velocities"] = serialized_velocities
	return data


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	if dict.has("velocities"):
		velocities.clear()
		var serialized_velocities: Dictionary = dict["velocities"]

		for k_str: String in serialized_velocities:
			var array_val: Array = serialized_velocities[k_str]
			var parsed_key: Variant = k_str
			if k_str.is_valid_int():
				parsed_key = k_str.to_int()

			velocities[parsed_key] = Vector4(
					array_val[0] as float, array_val[1] as float,
					array_val[2] as float, array_val[3] as float)


func deep_copy() -> Effect:
	var copy: AdvancedTransformEffect = deep_copy() as AdvancedTransformEffect
	copy.velocities = velocities.duplicate()
	return copy
