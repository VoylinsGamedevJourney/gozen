extends Node


func _ready() -> void:
	_print_startup_info()


func _print_startup_info() -> void:
	var header: Callable = (func(text: String) -> void:
			print_rich("[color=purple][b]", text))
	var info: Callable = (func(title: String, context: Variant) -> void:
			print_rich("[color=purple][b]", title, "[/b]: [color=gray]", context))

	header.call("--==  GoZen - Video Editor  ==--")
	info.call("GoZen Version", ProjectSettings.get_setting("application/config/version"))
	info.call("OS", OS.get_model_name())
	info.call("OS Version", OS.get_version())
	info.call("Distribution", OS.get_distribution_name())
	info.call("Processor", OS.get_processor_name())
	info.call("Threads", OS.get_processor_count())
	info.call("Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
				  	str("%0.2f" % (OS.get_memory_info().physical/1_073_741_824)), 
				  	str("%0.2f" % (OS.get_memory_info().available/1_073_741_824))])
	info.call("Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
				  	RenderingServer.get_video_adapter_name(),
				  	RenderingServer.get_video_adapter_api_version(),
				  	RenderingServer.get_video_adapter_type()])
	info.call("Locale", OS.get_locale())
	info.call("Startup args", OS.get_cmdline_args())
	header.call("--==--================--==--")


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


func print_insert_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't insert to array!")
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


func in_range(value: int, min_value: int, max_value: int, include_last: bool = true) -> bool:
	## Easier way to check if a value is within a range.
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


func in_rangef(value: float, min_value: float, max_value: float, include_last: bool = true) -> bool:
	## Same as in_range but for floats
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


func format_time_str_from_frame(frame_count: int) -> String:
	return format_time_str(float(frame_count) / Project.get_framerate())
	

func format_time_str(total_seconds: float) -> String:
	var total_seconds_int: int = floor(total_seconds)

	var hours: int = int(float(total_seconds_int) / 3600)
	var remaining_seconds: int = total_seconds_int % 3600
	var minutes: int = int(float(remaining_seconds) / 60)
	var seconds: int = total_seconds_int % 60
	var micro: int = int(float(total_seconds - total_seconds_int) * 100)

	return "%02d:%02d:%02d.%02d" % [hours, minutes, seconds, micro]
	

func find_subfolder_files(files: PackedStringArray) -> PackedStringArray:
	var folders: PackedStringArray = []
	var actual_files: PackedStringArray = []

	for path: String in files:
		if FileAccess.file_exists(path):
			if File.check_valid(path) and actual_files.append(path):
				print_append_error()
		elif DirAccess.dir_exists_absolute(path):
			if folders.append(path):
				print_append_error()

	while folders.size() != 0:
		var new_folders: PackedStringArray = []

		for path: String in folders:
			for file_path: String in DirAccess.get_files_at(path):
				var full_path: String = path + '/' + file_path

				if File.check_valid(full_path) and actual_files.append(full_path):
					print_append_error()
			for dir_path: String in DirAccess.get_directories_at(path):
				if new_folders.append(path + '/' + dir_path):
					print_append_error()

		folders = new_folders
	
	return actual_files

