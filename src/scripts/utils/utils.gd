class_name Utils
extends Node

# Const variables for get_fuzzy_score().
const FUZZY_SCORE_POINT: int = 1
const FUZZY_SCORE_BONUS: int = 10

const INT_32_MAX: int = 2_147_483_647



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


static func get_unique_id(keys: Array[int]) -> int:
	var id: int = abs(randi())
	while keys.has(id):
		randomize()
		if keys.has(id):
			id = get_unique_id(keys)
	return id


## Easier way to check if a value is within a range.
static func in_range(value: int, min_value: int, max_value: int, include_last: bool = true) -> bool:
	return value >= min_value and (value <= max_value if include_last else value < max_value)


## Same as in_range but for floats
static func in_rangef(value: float, min_value: float, max_value: float, include_last: bool = true) -> bool:
	return value >= min_value and (value <= max_value if include_last else value < max_value)


static func format_time_str_from_frame(frame_count: int, framerate: float, short: bool) -> String:
	return format_time_str(float(frame_count) / framerate, short)


## Short = 00:00:00
## Long = 00:00:00.00
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
			if FileLogic.check(path):
				actual_files.append(path)
		elif DirAccess.dir_exists_absolute(path):
			folders.append(path)

	while !folders.is_empty():
		var new_folders: PackedStringArray = []

		for path: String in folders:
			for file_path: String in DirAccess.get_files_at(path):
				var full_path: String = path + '/' + file_path
				if FileLogic.check(full_path):
					actual_files.append(full_path)
			for dir_path: String in DirAccess.get_directories_at(path):
				new_folders.append(path + '/' + dir_path)

		folders = new_folders

	return actual_files


static func get_sample_count(frames: int, framerate: float) -> int:
	return (int((float(frames) / framerate) * RenderManager.MIX_RATE)) * 4


static func get_video_extension(video_codec: Encoder.VIDEO_CODEC) -> String:
	match video_codec:
		Encoder.VIDEO_CODEC.V_HEVC: return ".mp4"
		Encoder.VIDEO_CODEC.V_H264: return ".mp4"
		Encoder.VIDEO_CODEC.V_MPEG4: return ".mp4"
		Encoder.VIDEO_CODEC.V_MPEG2: return ".mpg"
		Encoder.VIDEO_CODEC.V_MPEG1: return ".mpg"
		Encoder.VIDEO_CODEC.V_MJPEG: return ".mov"
		Encoder.VIDEO_CODEC.V_AV1: return ".webm"
		Encoder.VIDEO_CODEC.V_VP9: return ".webm"
		Encoder.VIDEO_CODEC.V_VP8: return ".webm"

	printerr("Utils: Unrecognized codec! ", video_codec)
	return ""


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


## Cleaning up render stuff.
static func cleanup_rid(device: RenderingDevice, rid: RID) -> RID:
	if rid.is_valid():
		device.free_rid(rid)

	return RID()


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


## For fuzzy searching.
static func get_fuzzy_score(query: String, text: String) -> int:
	if query.is_empty():
		return 1
	elif query.length() > text.length():
		return 0

	var query_index: int = 0
	var text_index: int = 0
	var score : int = 0

	query = query.to_lower()
	text = text.to_lower()

	while query_index < query.length() and text_index < text.length():
		if query[query_index] == text[text_index]:
			score += FUZZY_SCORE_POINT # Match found

			# Bonus for start of word
			if text_index == 0 or text[text_index - 1] == " " or text[text_index - 1] == "_":
				score += FUZZY_SCORE_BONUS # Start word found so extra bonus
			query_index += 1
		text_index += 1

	return score if query_index == query.length() else 0


static func calculate_fade(frame_nr: int, clip: ClipData, is_visual: bool) -> float:
	var fade: Vector2i = clip.effects.fade_visual if is_visual else clip.effects.fade_audio
	var fade_in: float = 1.0 if fade.x == 0 else min(frame_nr / float(fade.x), 1.0)
	var fade_out: float = 1.0 if fade.y == 0 else min((clip.duration - frame_nr) / float(fade.y), 1.0)
	return fade_in * fade_out


static func apply_scale(new_theme: Theme, ui_scale: float) -> void:
	ui_scale = maxf(0.1, ui_scale) # Can't be null.
	new_theme.default_font_size = roundi(new_theme.default_font_size * ui_scale)

	var processed: PackedInt64Array = [] ## So we can avoid scaling same resource.
	for type_name: String in new_theme.get_type_list():
		for font_type_name: String in new_theme.get_font_size_list(type_name):
			var current_size: int = new_theme.get_font_size(font_type_name, type_name)
			var new_size: int = roundi(current_size * ui_scale)
			new_theme.set_font_size(font_type_name, type_name, new_size)
		for const_type_name: String in new_theme.get_constant_list(type_name):
			var current_const: int = new_theme.get_constant(const_type_name, type_name)
			var new_const: int = roundi(current_const * ui_scale)
			new_theme.set_constant(const_type_name, type_name, new_const)
		for stylebox_name: String in new_theme.get_stylebox_list(type_name):
			var stylebox: StyleBox = new_theme.get_stylebox(stylebox_name, type_name)
			var id: int = stylebox.get_instance_id()
			if not processed.has(id):
				_scale_stylebox(stylebox, ui_scale)
				processed.append(id)


static func _scale_stylebox(stylebox: StyleBox, ui_scale: float) -> void:
	stylebox.content_margin_top *= ui_scale
	stylebox.content_margin_left *= ui_scale
	stylebox.content_margin_right *= ui_scale
	stylebox.content_margin_bottom *= ui_scale

	if stylebox is StyleBoxFlat:
		var stylebox_flat: StyleBoxFlat = stylebox
		stylebox_flat.border_width_top = roundi(stylebox_flat.border_width_top * ui_scale)
		stylebox_flat.border_width_left = roundi(stylebox_flat.border_width_left * ui_scale)
		stylebox_flat.border_width_right = roundi(stylebox_flat.border_width_right * ui_scale)
		stylebox_flat.border_width_bottom = roundi(stylebox_flat.border_width_bottom * ui_scale)

		stylebox_flat.corner_radius_top_left = roundi(stylebox_flat.corner_radius_top_left * ui_scale)
		stylebox_flat.corner_radius_top_right = roundi(stylebox_flat.corner_radius_top_right * ui_scale)
		stylebox_flat.corner_radius_bottom_left = roundi(stylebox_flat.corner_radius_bottom_left * ui_scale)
		stylebox_flat.corner_radius_bottom_right = roundi(stylebox_flat.corner_radius_bottom_right * ui_scale)

		stylebox_flat.expand_margin_left *= ui_scale
		stylebox_flat.expand_margin_right *= ui_scale
		stylebox_flat.expand_margin_top *= ui_scale
		stylebox_flat.expand_margin_bottom *= ui_scale
	elif stylebox is StyleBoxTexture:
		var stylebox_tex: StyleBoxTexture = stylebox
		stylebox_tex.texture_margin_left *= ui_scale
		stylebox_tex.texture_margin_right *= ui_scale
		stylebox_tex.texture_margin_top *= ui_scale
		stylebox_tex.texture_margin_bottom *= ui_scale

		stylebox_tex.expand_margin_left *= ui_scale
		stylebox_tex.expand_margin_right *= ui_scale
		stylebox_tex.expand_margin_top *= ui_scale
		stylebox_tex.expand_margin_bottom *= ui_scale
	elif stylebox is StyleBoxLine:
		var stylebox_line: StyleBoxLine = stylebox
		stylebox_line.thickness = roundi(stylebox_line.thickness * ui_scale)
		stylebox_line.grow_begin *= ui_scale
		stylebox_line.grow_end *= ui_scale
