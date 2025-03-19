extends Node


signal project_ready


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData
var file_data: Dictionary [int, FileData] = {}



func _update_recent_projects(a_new_path: String) -> void:
	var l_content: String = ""
	var l_file: FileAccess

	if FileAccess.file_exists(RECENT_PROJECTS_FILE):
		l_file = FileAccess.open(RECENT_PROJECTS_FILE, FileAccess.READ)
		l_content = l_file.get_as_text()
		l_file.close()
		
	l_file = FileAccess.open(RECENT_PROJECTS_FILE, FileAccess.WRITE)
	@warning_ignore("return_value_discarded")
	l_file.store_string(a_new_path + "\n" + l_content)


func new_project(a_path: String, a_res: Vector2i, a_framerate: float) -> void:
	data = ProjectData.new()

	for i: int in 6:
		data.tracks.append({})

	set_project_path(a_path)
	set_resolution(a_res)
	set_framerate(a_framerate)
	@warning_ignore("return_value_discarded")
	Editor.loaded_clips.resize(get_track_count())
	file_data = {}

	project_ready.emit()
	_update_recent_projects(a_path)
	save()


func save() -> void:
	if data.save_data(data.project_path):
		printerr("Something went wrong whilst saving project!")


func open(a_project_path: String) -> void:
	data = ProjectData.new()
	file_data = {}

	if data.load_data(a_project_path):
		printerr("Something went wrong whilst loading project!")

	@warning_ignore_start("return_value_discarded")
	set_project_path(a_project_path)
	set_framerate(data.framerate)
	Editor.loaded_clips.resize(get_track_count())
	@warning_ignore_restore("return_value_discarded")

	for i: int in Project.get_file_ids():
		load_file_data(i)

	_update_recent_projects(a_project_path)
	project_ready.emit()


func load_file_data(a_id: int) -> void:
	var l_file_data: FileData = FileData.new()

	l_file_data.init_data(a_id)
	file_data[a_id] = l_file_data


# Setters and Getters  --------------------------------------------------------
func set_project_path(a_project_path: String) -> void:
	data.project_path = a_project_path


func get_project_path() -> String:
	return data.project_path


func get_files() -> Dictionary[int, File]:
	return data.files


func get_file_ids() -> PackedInt32Array:
	return data.files.keys()


func get_file(a_id: int) -> File:
	return data.files[a_id]
	

func get_file_data(a_id: int) -> FileData:
	return file_data[a_id]


func set_resolution(a_res: Vector2i) -> void:
	data.resolution = a_res


func get_resolution() -> Vector2i:
	return data.resolution


func set_framerate(a_framerate: float) -> void:
	data.framerate = a_framerate
	Editor.frame_time = 1.0 / data.framerate


func get_framerate() -> float:
	return data.framerate


func get_timeline_end() -> int:
	return data.timeline_end


func set_timeline_end(a_value: int) -> void:
	data.timeline_end = a_value


func get_track_count() -> int:
	return data.tracks.size()


func get_track_keys(a_track_id: int) -> PackedInt64Array:
	return data.tracks[a_track_id].keys()


func get_tracks() -> Array[Dictionary]:
	return data.tracks


func get_track_data(a_track_id: int) -> Dictionary[int, int]:
	var l_data: Dictionary[int, int] = {}

	for l_key: int in data.tracks[a_track_id]:
		l_data[l_key] = data.tracks[a_track_id][l_key]
		
	return l_data


func get_clips() -> Dictionary[int, ClipData]:
	return data.clips


func get_clip_ids() -> Array[ClipData]:
	return data.clips.values()


func get_clip(a_clip_id: int) -> ClipData:
	return data.clips[a_clip_id]


func get_clip_type(a_clip_id: int) -> File.TYPE:
	return data.files[data.clips[a_clip_id].file_id].type


func set_clip(a_id: int, a_clip: ClipData) -> void:
	a_clip.clip_id = a_id
	data.clips[a_id] = a_clip


func erase_clip(a_clip_id: int) -> void:
	@warning_ignore_start("return_value_discarded")
	data.tracks[data.clips[a_clip_id].track_id].erase(data.clips[a_clip_id].start_frame)
	data.clips.erase(a_clip_id)
	@warning_ignore_restore("return_value_discarded")

