class_name Utils
extends Node



static func format_file_nickname(file_name: String, size: int) -> String:
	var new_name: String = ""

	while file_name.length() > size:
		if new_name.length() == 0:
			new_name += "\n"

		new_name += file_name.left(size)
		file_name = file_name.trim_prefix(file_name.left(size))

	new_name += file_name

	return new_name


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


## Easier way to check if a value is within a range.
static func in_range(value: int, min_value: int, max_value: int, include_last: bool = true) -> bool:
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


## Same as in_range but for floats
static func in_rangef(value: float, min_value: float, max_value: float, include_last: bool = true) -> bool:
	if include_last:
		return value >= min_value and value <= max_value
	return value >= min_value and value < max_value


static func format_time_str_from_frame(frame_count: int, framerate: float, short: bool) -> String:
	return format_time_str(float(frame_count) / framerate, short)
	

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
			if File.check_valid(path):
				actual_files.append(path)
		elif DirAccess.dir_exists_absolute(path):
			folders.append(path)

	while folders.size() != 0:
		var new_folders: PackedStringArray = []

		for path: String in folders:
			for file_path: String in DirAccess.get_files_at(path):
				var full_path: String = path + '/' + file_path

				if File.check_valid(full_path):
					actual_files.append(full_path)
			for dir_path: String in DirAccess.get_directories_at(path):
				new_folders.append(path + '/' + dir_path)

		folders = new_folders
	
	return actual_files


static func get_sample_count(frames: int, framerate: float) -> int:
	return int(44100 * 4 * float(frames) / framerate)


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


## A function to help getting the number lower than the given number.
static func get_previous(frame: int, array: PackedInt64Array) -> int:
	var prev: int = -1

	for i: int in array:
		if i >= frame:
			break
		prev = i

	return prev


## A function to help getting the number higher than the given number.
static func get_next(frame: int, array: PackedInt64Array) -> int:
	for i: int in array:
		if i > frame:
			return i

	return -1

