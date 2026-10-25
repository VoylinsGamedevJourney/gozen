class_name Math


#--- Interpolation handling ---

static func simple_interpolate(a: Variant, b: Variant, weight: float) -> Variant:
	var type: int = typeof(a)
	if type in [TYPE_FLOAT, TYPE_INT]:
		return lerp(a as float, b as float, weight)
	elif type == TYPE_VECTOR2:
		return (a as Vector2).lerp(b as Vector2, weight)
	elif type == TYPE_VECTOR2I:
		return Vector2i((a as Vector2).lerp(b as Vector2, weight))
	elif type == TYPE_VECTOR3:
		return (a as Vector3).lerp(b as Vector3, weight)
	elif type == TYPE_VECTOR3I:
		return Vector3i((a as Vector3).lerp(b as Vector3, weight))
	elif type == TYPE_COLOR:
		return (a as Color).lerp(b as Color, weight)
	elif type == TYPE_PACKED_VECTOR2_ARRAY:
		var array_a: PackedVector2Array = a
		var array_b: PackedVector2Array = b
		var result: PackedVector2Array = PackedVector2Array()
		var size: int = maxi(array_a.size(), array_b.size())
		for i: int in size:
			var point_a: Vector2
			if i < array_a.size():
				point_a = array_a[i]
			elif array_a.is_empty():
				point_a = array_b[i]
			else:
				point_a = array_a[-1]

			var point_b: Vector2
			if i < array_b.size():
				point_b = array_b[i]
			elif array_b.is_empty():
				point_b = array_a[i]
			else:
				point_b = array_b[-1]
			result.append(point_a.lerp(point_b, weight))
		return result
	else:
		return a # Fallback.


static func smooth_interpolate(a: Variant, b: Variant, weight: float) -> Variant:
	return simple_interpolate(a, b, smoothstep(0.0, 1.0, weight))


## Easier way to check if a value is within a range.
static func in_range(value: int, min_value: int, max_value: int, include_last: bool = true) -> bool:
	return value >= min_value and (value <= max_value if include_last else value < max_value)


## Same as in_range but for floats
static func in_rangef(value: float, min_value: float, max_value: float, include_last: bool = true) -> bool:
	return value >= min_value and (value <= max_value if include_last else value < max_value)


static func get_sample_count(frames: int, framerate: float) -> int:
	return (int((float(frames) / framerate) * RenderManager.MIX_RATE)) * 4


#--- Fade calculations ---

static func calculate_fade_in(frame_nr: int, clip: ClipData) -> float:
	var fade: Vector2i = clip.effects.fade_visual
	return 1.0 if fade.x == 0 else clamp(frame_nr / float(fade.x), 0.0, 1.0)


static func calculate_fade_out(frame_nr: int, clip: ClipData) -> float:
	var fade: Vector2i = clip.effects.fade_visual
	return 1.0 if fade.y == 0 else clamp((clip.duration - frame_nr) / float(fade.y), 0.0, 1.0)


static func calculate_fade(frame_nr: int, clip: ClipData, is_visual: bool) -> float:
	var fade: Vector2i = clip.effects.fade_visual if is_visual else clip.effects.fade_audio
	var fade_in: float = 1.0 if fade.x == 0 else clamp(frame_nr / float(fade.x), 0.0, 1.0)
	var fade_out: float = 1.0 if fade.y == 0 else clamp((clip.duration - frame_nr) / float(fade.y), 0.0, 1.0)
	return fade_in * fade_out
