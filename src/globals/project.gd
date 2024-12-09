extends Node


signal _on_project_saved
signal _on_project_loaded
signal _on_changes_occurred

signal _on_title_changed
signal _on_framerate_changed(value: int, old_value: int)
signal _on_resolution_changed(value: Vector2i)



var _unsaved_changes: bool = false
var _project_path: String = ""

var title: String = "": set = set_title, get = get_title
var framerate: int = 30: set = set_framerate, get = get_framerate
var resolution: Vector2i = Vector2i.ZERO: set = set_resolution, get = get_resolution



## This function should be called when data has changed and requires saving.
func changes_made() -> void:
	_unsaved_changes = true
	_on_changes_occurred.emit()


## Taking all necessary variables from Project and Core classes to save.
func save_data() -> void:
	OS.set_use_file_access_save_and_swap(true)
	var l_file: FileAccess = FileAccess.open(_project_path, FileAccess.WRITE)

	if FileAccess.get_open_error():
		printerr("Couldn't open file at '", _project_path, "' for saving!")
	else:
		l_file.store_string(var_to_str({
			"title": title,
			"framerate": framerate,
			"resolution": resolution,

			"files": CoreMedia.files,
			"folders": CoreMedia.folders,

			"clips": CoreTimeline.clips,
			"tracks": CoreTimeline.tracks,
			"playhead_pos": CoreTimeline.playhead_pos,
		}))

	if l_file.get_error() != 0:
		OS.set_use_file_access_save_and_swap(false)
		return printerr("Error storing data to file at '%s', error: %s!" % [
				_project_path, l_file.get_error()])

	l_file.close()
	OS.set_use_file_access_save_and_swap(false)

	_on_project_saved.emit()
	_unsaved_changes = false


## Takes all necessary variables from save file and updates variables in the
## Core classes and Project class.
func load_data(a_path: String) -> void:
	if !FileAccess.file_exists(_project_path):
		OS.set_use_file_access_save_and_swap(false)
		return printerr("No project found at path '", _project_path, "'!")

	var l_file: FileAccess = FileAccess.open(a_path, FileAccess.READ)
	if FileAccess.get_open_error():
		OS.set_use_file_access_save_and_swap(false)
		return printerr("Couldn't open file at '", _project_path, "'!")

	var l_data: Dictionary = str_to_var(l_file.get_as_text())
	if l_file.get_error() != 0:
		OS.set_use_file_access_save_and_swap(false)
		return printerr("Error loading data from '%s' with error %s!" %
				[_project_path, l_file.get_error()])

	for l_key: String in l_data.keys():
		match l_key:
			"title": title = l_data[l_key]
			"framerate": framerate = l_data[l_key]
			"resolution": resolution = l_data[l_key]

			"files": CoreMedia.files = l_data[l_key]
			"folders": CoreMedia.folders = l_data[l_key]

			"clips": CoreTimeline.clips = l_data[l_key]
			"tracks": CoreTimeline.tracks = l_data[l_key]
			"playhead_pos": CoreTimeline.playhead_pos = l_data[l_key]

	l_file.close()
	OS.set_use_file_access_save_and_swap(false)

	_project_path = a_path
	_on_project_loaded.emit()
	

#------------------------------------------------ META-DATA HANDLING
func set_title(a_title: String) -> void:
	title = a_title
	_on_title_changed.emit()
	changes_made()


func get_title() -> String:
	return title


func set_framerate(a_value: int) -> void:
	var l_old: int = framerate
	if framerate <= 0:
		return printerr("Framerate should be an absolute value!")

	framerate = a_value
	_on_framerate_changed.emit(a_value, l_old)
	changes_made()


func get_framerate() -> int:
	return framerate


func set_resolution(a_resolution: Vector2i) -> void:
	if a_resolution.x % 2 != 0 or a_resolution.y % 2 != 0:
		return printerr("Resolution needs to be in steps of 2 to avoid render issues!")

	resolution = a_resolution
	_on_resolution_changed.emit()
	changes_made()


func get_resolution() -> Vector2i:
	return resolution

