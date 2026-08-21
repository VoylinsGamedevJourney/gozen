class_name Utils
extends Node


# Const variables for get_fuzzy_score().
const FUZZY_SCORE_POINT: int = 1
const FUZZY_SCORE_BONUS: int = 10

const INT_32_MAX: int = 2_147_483_647



static func get_unique_id(keys: Array[int]) -> int:
	var id: int = abs(randi())
	while keys.has(id):
		randomize()
		if keys.has(id):
			id = get_unique_id(keys)
	return id



static func find_subfolder_files(dropped_paths: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	var folders: Array[Dictionary] = []

	for path: String in dropped_paths:
		path = path.replace("\\", "/")
		if FileAccess.file_exists(path):
			if FileLogic.check(path):
				result[path] = "/"
		elif DirAccess.dir_exists_absolute(path):
			var folder_name: String = path.trim_suffix("/").get_file()
			folders.append({"path": path, "virtual": "/" + folder_name + "/"})

	while !folders.is_empty():
		var new_folders: Array[Dictionary] = []

		for folder_data: Dictionary in folders:
			var dir_path: String = folder_data["path"]
			var virtual_path: String = folder_data["virtual"]

			for file_name: String in DirAccess.get_files_at(dir_path):
				var full_path: String = dir_path + "/" + file_name
				if FileLogic.check(full_path):
					result[full_path] = virtual_path

			for subdir_name: String in DirAccess.get_directories_at(dir_path):
				new_folders.append({
					"path": dir_path + "/" + subdir_name,
					"virtual": virtual_path + subdir_name + "/"
				})
		folders = new_folders
	return result


static func get_video_extension(video_codec: Encoder.VideoCodec) -> String:
	match video_codec:
		Encoder.VideoCodec.V_HEVC: return ".mp4"
		Encoder.VideoCodec.V_H264: return ".mp4"
		Encoder.VideoCodec.V_MPEG4: return ".mp4"
		Encoder.VideoCodec.V_MPEG2: return ".mpg"
		Encoder.VideoCodec.V_MPEG1: return ".mpg"
		Encoder.VideoCodec.V_MJPEG: return ".mov"
		Encoder.VideoCodec.V_AV1: return ".webm"
		Encoder.VideoCodec.V_VP9: return ".webm"
		Encoder.VideoCodec.V_VP8: return ".webm"
	printerr("Utils: Unrecognized codec! ", video_codec)
	return ""


## A function to help getting the number lower than the given number.
static func get_previous_in_array(frame: int, array: Array[int]) -> int:
	var prev: int = -1

	for i: int in array:
		if i >= frame:
			break
		prev = i

	return prev


## A function to help getting the number higher than the given number.
static func get_next_in_array(frame: int, array: Array[int]) -> int:
	for i: int in array:
		if i > frame:
			return i

	return -1


## Cleaning up render stuff.
static func cleanup_rid(device: RenderingDevice, rid: RID) -> void:
	if rid.is_valid():
		device.free_rid(rid)


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
