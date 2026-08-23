class_name Format


static func file_nickname(file_name: String, size: int) -> String:
	var new_name: String = ""
	while file_name.length() > size:
		if new_name.length() == 0:
			new_name += "\n"
		new_name += file_name.left(size)
		file_name = file_name.trim_prefix(file_name.left(size))
	new_name += file_name
	return new_name


## Removind the middle the path so it fits in a certain amount of width without
## bleeding to the next line.
static func path_remove_middle(path: String, max_length: int) -> String:
	if path.length() <= max_length:
		return path

	# "..." takes 3 characters
	var split_size: int = floori((max_length - 3) / 2.0)
	var left_part: String = path.left(split_size)
	var right_part: String = path.right(split_size)

	return "%s...%s" % [left_part, right_part]


## Short = 00:00:00
## Long = 00:00:00.00
static func time_str(total_seconds: float, short: bool = false) -> String:
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


static func time_str_from_frame(frame_count: int, framerate: float, short: bool) -> String:
	return time_str(float(frame_count) / framerate, short)
