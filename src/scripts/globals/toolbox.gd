extends Node



func format_file_nickname(file_name: String, size: int) -> String:
	var new_name: String = ""

	while file_name.length() > size:
		if new_name.length() != 0:
			new_name += "\n"

		var data: String = file_name.left(size)
		new_name += data
		file_name = file_name.trim_prefix(data)

	new_name += file_name

	return new_name



func get_file_dialog(title: String, mode: FileDialog.FileMode, filters: PackedStringArray) -> FileDialog:
	var dialog: FileDialog = FileDialog.new()

	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.title = title
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = filters

	return dialog


func connect_func(connect_signal: Signal, connect_callable: Callable) -> void:
	# This function is needed to handle the error in a good way for when
	# connecting a callable to a signal wasn't successful.
	if connect_signal.connect(connect_callable):
		push_error("Error connecting to signal '%s' to '%s'!" % [
				connect_signal.get_name(), connect_callable.get_method()])

	
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


func open_url(url: String) -> void:
	@warning_ignore("return_value_discarded")
	OS.shell_open(url)


func get_unique_id(keys: PackedInt64Array) -> int:
	var id: int = abs(randi())

	randomize()
	if keys.has(id):
		id = get_unique_id(keys)

	return id


## Easier way to check if a value is within a range.
func in_range(value: int, min_value: int, max_value: int, include_last: bool = true) -> bool:
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


## Same as in_range but for floats
func in_rangef(value: float, min_value: float, max_value: float, include_last: bool = true) -> bool:
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value

