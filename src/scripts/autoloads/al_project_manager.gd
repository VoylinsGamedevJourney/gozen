extends Node
## Project Manager

signal _on_project_loaded
signal _on_project_saved
signal _on_unsaved_changes_changed(value: bool)

signal _on_title_changed(new_title: String)
signal _on_resolution_changed(new_resolution: Vector2i)
signal _on_framerate_changed(new_framerate: int)

signal _on_video_tracks_changed(update_video_tracks: Array)
signal _on_audio_tracks_changed(update_audio_tracks: Array)


# Key's for variables which need saving
const KEYS: PackedStringArray = [
	"title",
	
	"folder_data",
	"files_data",
	"current_id", 
	
	"resolution",
	"framerate",
	"video_tracks",
	"audio_tracks" ]


var project_path: String:
	set = _set_project_path

var unsaved_changes := false:
	set = _set_unsaved_changes

var title: String:
	set = _set_title

var folder_data: Dictionary = {} # Full_path: Array of files
var files_data: Dictionary = {} # File_id: File class object
var current_id: int = 0  # File ID's for global start with 'G_' and for project with 'P_'

var resolution: Vector2i:
	set = _set_resolution
var framerate: float:
	set = _set_framerate

var video_tracks: Array = []
var audio_tracks: Array = []


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_released("save_project"):
		save_project()


func new_project(a_title: String, a_path: String, a_resolution: Vector2i, a_framerate: int) -> void:
	project_path = a_path
	
	title = a_title
	resolution = a_resolution
	framerate = a_framerate
	add_video_tracks(SettingsManager.get_default_video_tracks())
	add_audio_tracks(SettingsManager.get_default_audio_tracks())
	
	_on_project_loaded.emit()
	save_project()


func load_project(a_path: String) -> void:
	if Toolbox.check_extension(a_path, ["gozen"]):
		project_path = a_path
	else:
		project_path = "%s.gozen" % a_path
		if !Toolbox.file_exists(project_path, Globals.ERROR_PROJECT_PATH_EXTENSION):
			get_tree().quit(-2)
			return
	
	var l_file := FileAccess.open(project_path, FileAccess.READ)
	var l_data: Dictionary = str_to_var(l_file.get_as_text())
	
	for l_key: String in KEYS:
		set(l_key, l_data[l_key])
	
	_on_title_changed.emit(title)
	update_recent_projects()
	_on_project_loaded.emit()


func save_project() -> void:
	var l_file: FileAccess = FileAccess.open(project_path, FileAccess.WRITE)
	var l_data: Dictionary = {}
	
	for l_key: String in KEYS:
		l_data[l_key] = get(l_key)
	
	l_file.store_string(var_to_str(l_data))
	_on_project_saved.emit()
	unsaved_changes = false


func update_recent_projects() -> void:
	var l_recent_projects := RecentProjects.new()
	l_recent_projects.update_project(title, project_path)


#region #####################  Getters & Setters  ##############################

func _set_project_path(a_path: String) -> void:
	if Toolbox.check_extension(a_path, ["gozen"]):
		project_path = a_path
	else:
		project_path = "%s.gozen" % a_path


func _set_unsaved_changes(a_value: bool) -> void:
	unsaved_changes = a_value
	_on_unsaved_changes_changed.emit(unsaved_changes)


func _set_title(a_title: String) -> void:
	title = a_title
	_on_title_changed.emit(title)
	unsaved_changes = true
	
	update_recent_projects()


func _set_resolution(a_resolution: Vector2i) -> void:
	resolution = a_resolution
	_on_resolution_changed.emit(resolution)
	unsaved_changes = true


func _set_framerate(a_framerate: float) -> void:
	framerate = a_framerate
	_on_framerate_changed.emit(framerate)
	unsaved_changes = true

#endregion
#region #####################  Track handling  #################################

func add_video_tracks(a_amount: int = 1) -> void:
	for _i: int in a_amount:
		video_tracks.append(TimelineTrack.new())
	_on_video_tracks_changed.emit(video_tracks)
	unsaved_changes = true


func remove_video_track(a_position: int) -> void:
	video_tracks.remove_at(a_position)
	_on_video_tracks_changed.emit(video_tracks)
	unsaved_changes = true


func add_audio_tracks(a_amount: int = 1) -> void:
	for _i: int in a_amount:
		audio_tracks.append(TimelineTrack.new())
	_on_audio_tracks_changed.emit(audio_tracks)
	unsaved_changes = true


func remove_audio_track(a_position: int) -> void:
	audio_tracks.remove_at(a_position)
	_on_audio_tracks_changed.emit(audio_tracks)
	unsaved_changes = true

#endregion
