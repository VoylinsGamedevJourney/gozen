extends Node


func open_url(a_url: String) -> void:
	@warning_ignore("return_value_discarded")
	OS.shell_open(a_url)


func get_unique_id(a_keys: PackedInt32Array) -> int:
	var l_id: int = abs(randi())

	randomize()
	if a_keys.has(l_id):
		l_id = get_unique_id(a_keys)

	return l_id


## Easier way to check if a value is within a range.
func in_range(a_value: int, a_min: int, a_max: int, a_include_last: bool = true) -> bool:
	if a_include_last:
		return a_value >= a_min and a_value <= a_max
	return a_value >= a_min and a_value < a_max


## Same as in_range but for floats
func in_rangef(a_value: float, a_min: float, a_max: float, a_include_last: bool = true) -> bool:
	if a_include_last:
		return a_value >= a_min and a_value <= a_max
	return a_value >= a_min and a_value < a_max

