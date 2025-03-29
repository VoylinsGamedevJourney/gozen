extends Node



func format_file_nickname(a_name: String, a_size: int) -> String:
	var l_new_name: String = ""

	while a_name.length() > a_size:
		if l_new_name.length() != 0:
			l_new_name += "\n"

		var l_data: String = a_name.left(a_size)
		l_new_name += l_data
		a_name = a_name.trim_prefix(l_data)

	l_new_name += a_name

	return l_new_name



func get_file_dialog(a_title: String, a_mode: FileDialog.FileMode, a_filters: PackedStringArray) -> FileDialog:
	var l_dialog: FileDialog = FileDialog.new()

	l_dialog.force_native = true
	l_dialog.use_native_dialog = true
	l_dialog.title = a_title
	l_dialog.access = FileDialog.ACCESS_FILESYSTEM
	l_dialog.file_mode = a_mode
	l_dialog.filters = a_filters

	return l_dialog


func connect_func(a_signal: Signal, a_callable: Callable) -> void:
	# This function is needed to handle the error in a good way for when
	# connecting a callable to a signal wasn't successful.
	if a_signal.connect(a_callable):
		push_error("Error connecting to signal '%s' to '%s'!" % [
				a_signal.get_name(), a_callable.get_method()])

	
func print_resize_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't resize array!")
	printerr(get_stack())


func print_append_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't append to array!")
	printerr(get_stack())


func print_erase_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't erase entry!")
	printerr(get_stack())


func open_url(a_url: String) -> void:
	@warning_ignore("return_value_discarded")
	OS.shell_open(a_url)


func get_unique_id(a_keys: PackedInt64Array) -> int:
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

