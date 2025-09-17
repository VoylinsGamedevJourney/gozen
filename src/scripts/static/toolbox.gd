class_name Toolbox
extends Node



static func format_file_nickname(file_name: String, size: int) -> String:
	var new_name: String = ""

	while file_name.length() > size:
		if new_name.length() != 0:
			new_name += "\n"

		var data: String = file_name.left(size)
		new_name += data
		file_name = file_name.trim_prefix(data)

	new_name += file_name

	return new_name


static func get_file_dialog(title: String, mode: FileDialog.FileMode, filters: PackedStringArray = []) -> FileDialog:
	var dialog: FileDialog = FileDialog.new()

	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.title = title
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = filters

	return dialog


static func get_popup(permanent: bool = false) -> PopupMenu:
	var popup: PopupMenu = PopupMenu.new()

	if !permanent:
		connect_func(popup.mouse_exited, popup.queue_free)

	popup.size = Vector2i(100,0)
	return popup


static func show_popup(popup: PopupMenu) -> void:
	var mouse_pos: Vector2 = Project.get_viewport().get_mouse_position()

	popup.position.x = int(mouse_pos.x)
	popup.position.y = int(mouse_pos.y + (popup.size.y / 2.0))

	Project.add_child(popup)
	popup.popup()


static func connect_func(connect_signal: Signal, connect_callable: Callable) -> void:
	# This function is needed to handle the error in a good way for when
	# connecting a callable to a signal wasn't successful.
	if connect_signal.connect(connect_callable):
		push_error("Error connecting to signal '%s' to '%s'!" % [
				connect_signal.get_name(), connect_callable.get_method()])


static func print_header(text: String, color: String = "white") -> void:
	print_rich("[color=%s][b]" % color, text)


static func print_info(title: String, context: Variant, color: String = "white") -> void:
	print_rich("[color=%s][b]" % color, title, "[/b]: [color=gray]", context)

	
static func print_resize_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't resize array!")
	printerr(get_stack())


static func print_append_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't append to array!")
	printerr(get_stack())


static func print_insert_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't insert to array!")
	printerr(get_stack())
	

static func print_erase_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't erase entry!")
	printerr(get_stack())


static func open_url(url: String) -> void:
	if url.begins_with("http") or url.begins_with("www"):
		@warning_ignore("return_value_discarded")
		OS.shell_open(url)
	else:
		url = url.trim_prefix("urls/") # Just in case
		@warning_ignore("return_value_discarded")
		OS.shell_open(str(ProjectSettings.get_setting("urls/%s" % url)))


static func get_unique_id(keys: PackedInt64Array) -> int:
	var id: int = abs(randi())

	randomize()
	if keys.has(id):
		id = get_unique_id(keys)

	return id


static func in_range(value: int, min_value: int, max_value: int, include_last: bool = true) -> bool:
	## Easier way to check if a value is within a range.
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


static func in_rangef(value: float, min_value: float, max_value: float, include_last: bool = true) -> bool:
	## Same as in_range but for floats
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


static func format_time_str_from_frame(frame_count: int) -> String:
	return format_time_str(float(frame_count) / Project.get_framerate())
	

static func format_time_str(total_seconds: float, short: bool = false) -> String:
	var total_seconds_int: int = floor(total_seconds)

	var hours: int = int(float(total_seconds_int) / 3600)
	var remaining_seconds: int = total_seconds_int % 3600
	var minutes: int = int(float(remaining_seconds) / 60)
	var seconds: int = total_seconds_int % 60
	var micro: int = int(float(total_seconds - total_seconds_int) * 100)

	if short:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	else:
		return "%02d:%02d:%02d.%02d" % [hours, minutes, seconds, micro]
	

static func find_subfolder_files(files: PackedStringArray) -> PackedStringArray:
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


static func get_sample_count(frames: int) -> int:
	return int(44100 * 4 * float(frames) / Project.get_framerate())


static func get_video_extension(video_codec: GoZenEncoder.VIDEO_CODEC) -> String:
	match video_codec:
		GoZenEncoder.VIDEO_CODEC.V_HEVC: return ".mp4"
		GoZenEncoder.VIDEO_CODEC.V_H264: return ".mp4"
		GoZenEncoder.VIDEO_CODEC.V_MPEG4: return ".mp4"
		GoZenEncoder.VIDEO_CODEC.V_MPEG2: return ".mpg"
		GoZenEncoder.VIDEO_CODEC.V_MPEG1: return ".mpg"
		GoZenEncoder.VIDEO_CODEC.V_MJPEG: return ".mov"
		GoZenEncoder.VIDEO_CODEC.V_AV1: return ".webm"
		GoZenEncoder.VIDEO_CODEC.V_VP9: return ".webm"
		GoZenEncoder.VIDEO_CODEC.V_VP8: return ".webm"

	printerr("Unrecognized codec! ", video_codec)
	return ""


static func calculate_fade(frame_nr: int, fade_limit: float) -> float:
	return lerpf(1, 0, float(frame_nr) / fade_limit)


static func get_previous(frame: int, array: PackedInt64Array) -> int:
	## A function to help getting the number lower than the given number.
	var prev: int = -1

	for i: int in array:
		if i >= frame:
			break
		prev = i

	return prev


static func get_next(frame: int, array: PackedInt64Array) -> int:
	## A function to help getting the number higher than the given number.
	for i: int in array:
		if i > frame:
			return i

	return -1

