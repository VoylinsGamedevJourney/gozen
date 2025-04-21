extends Node


signal project_ready


const EXTENSION: String = ".gozen"
const RECENT_PROJECTS_FILE: String = "user://recent_projects"


var data: ProjectData
var file_data: Dictionary [int, FileData] = {}



func _update_recent_projects(new_path: String) -> void:
	var content: String = ""
	var file: FileAccess

	if FileAccess.file_exists(RECENT_PROJECTS_FILE):
		file = FileAccess.open(RECENT_PROJECTS_FILE, FileAccess.READ)
		content = file.get_as_text()
		file.close()
		
	file = FileAccess.open(RECENT_PROJECTS_FILE, FileAccess.WRITE)
	if !file.store_string(new_path + "\n" + content):
		printerr("Error storing String for recent_projects!")


func new_project(path: String, res: Vector2i, framerate: float) -> void:
	data = ProjectData.new()

	for i: int in Settings.get_tracks_amount():
		data.tracks.append({})

	set_project_path(path)
	set_resolution(res)
	set_framerate(framerate)
	if Editor.loaded_clips.resize(get_track_count()):
		Toolbox.print_resize_error()

	file_data = {}

	project_ready.emit()
	_update_recent_projects(path)
	save()
	get_window().title = "GoZen - %s" % path.get_file().get_basename()


func save() -> void:
	if data.save_data(data.project_path):
		printerr("Something went wrong whilst saving project! ", data.error)


func open(project_path: String) -> void:
	data = ProjectData.new()
	file_data = {}

	if data.load_data(project_path):
		printerr("Something went wrong whilst loading project!", data.error)

	set_project_path(project_path)
	set_framerate(data.framerate)
	if Editor.loaded_clips.resize(get_track_count()):
		Toolbox.print_resize_error()

	for i: int in get_file_ids():
		load_file_data(i)
		var type: File.TYPE = data.files[i].type

		if type == File.TYPE.VIDEO and file_data[i].video == null:
			await file_data[i].video_loaded
			print("loaded")

	_update_recent_projects(project_path)
	project_ready.emit()
	get_window().title = "GoZen - %s" % project_path.get_file().get_basename()


func load_file_data(id: int) -> void:
	var temp_file_data: FileData = FileData.new()

	temp_file_data.init_data(id)
	file_data[id] = temp_file_data


func reload_file_data(id: int) -> void:
	file_data[id].queue_free()
	await RenderingServer.frame_pre_draw
	load_file_data(id)


func delete_file(id: int) -> void:
	# TODO: We should also remove the actual clips from the timeline.
	for clip: ClipData in data.clips.values():
		if clip.file_id == id:
			if !data.clips.erase(clip.clip_id):
				Toolbox.print_erase_error()

	file_data[id].queue_free()
	data.files[id].queue_free()

	# WARNING: Right now we delete undo_redo, this is because it could cause
	# issues when undoing a part where the clips are needed. This is a TODO
	# for later!
	InputManager.undo_redo = UndoRedo.new()

	await RenderingServer.frame_pre_draw


# Setters and Getters  --------------------------------------------------------
func set_project_path(project_path: String) -> void:
	data.project_path = project_path


func get_project_path() -> String:
	return data.project_path

 
func set_file(file_id: int, file: File) -> void:
	data.files[file_id] = file


func get_files() -> Dictionary[int, File]:
	return data.files


func get_file_ids() -> PackedInt64Array:
	return data.files.keys()


func get_file(id: int) -> File:
	return data.files[id]
	

func get_file_data(id: int) -> FileData:
	return file_data[id]


func set_resolution(res: Vector2i) -> void:
	data.resolution = res


func get_resolution() -> Vector2i:
	return data.resolution


func set_framerate(framerate: float) -> void:
	data.framerate = framerate
	Editor.frame_time = 1.0 / data.framerate


func get_framerate() -> float:
	return data.framerate


func get_timeline_end() -> int:
	return data.timeline_end


func set_timeline_end(value: int) -> void:
	data.timeline_end = value


func set_track_data(track_id: int, key: int, value: int) -> void:
	data.tracks[track_id][key] = value


func erase_track_entry(track_id: int, key: int) -> void:
	if !data.tracks[track_id].erase(key):
		printerr("Could not erase ", key, " from track ", track_id, "!")
	

func get_track_count() -> int:
	return data.tracks.size()


func get_track_keys(track_id: int) -> PackedInt64Array:
	return data.tracks[track_id].keys()


func get_tracks() -> Array[Dictionary]:
	return data.tracks


func get_track_data(track_id: int) -> Dictionary[int, int]:
	var track_data: Dictionary[int, int] = {}

	for key: int in data.tracks[track_id]:
		track_data[key] = data.tracks[track_id][key]
		
	return track_data


func get_clips() -> Dictionary[int, ClipData]:
	return data.clips


func get_clip_datas() -> Array[ClipData]:
	return data.clips.values()


func get_clip_ids() -> PackedInt64Array:
	return data.clips.keys()


func get_clip(clip_id: int) -> ClipData:
	return data.clips[clip_id]


func get_clip_type(clip_id: int) -> File.TYPE:
	return data.files[data.clips[clip_id].file_id].type


func set_clip(id: int, clip: ClipData) -> void:
	clip.clip_id = id
	data.clips[id] = clip


func erase_clip(clip_id: int) -> void:
	if !data.tracks[data.clips[clip_id].track_id].erase(data.clips[clip_id].start_frame):
		Toolbox.print_erase_error()
	if !data.clips.erase(clip_id):
		Toolbox.print_erase_error()


func set_background_color(color: Color) -> void:
	data.background_color = color
	Editor.set_background_color(color)


func get_background_color() -> Color:
	return data.background_color

