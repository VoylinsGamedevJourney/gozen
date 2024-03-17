extends Node
## Project Manager
##
## Config structure:
## [general]
##   title: String
##   files: {unique_file_id: {file_class_data}}
##   folders: {folder_name: {files = [file_id's], sub_folders = [...]}}
## [quality]
##   resolution: Vector2i
##   framerate: float

signal _on_project_loaded
signal _on_project_saved

signal _on_unsaved_changes
signal _on_changes_saved

signal _on_title_changed(new_title: String)
signal _on_resolution_changed(new_resolution: Vector2i)
signal _on_framerate_changed(new_framerate: int)

# Key's for variables which need saving
const keys: PackedStringArray = [
	"title",
	
	"folder_data",
	"file_data",
	"current_id", 
	
	"resolution",
	"framerate",
	"video_tracks",
	"audio_tracks" ]


var config: ConfigFile = ConfigFile.new()
var project_path: String

var unsaved_changes := false


# Project data (for saving)
var title: String

var folder_data := {} # Full_path: Array of files
var file_data   := {} # File_id: File class object
var current_id  := 0  # File ID's for global start with 'G_' and for project with 'P_'

var resolution: Vector2i
var framerate: float

var video_tracks: Array = []
var audio_tracks: Array = []


func new_project(title: String, path: String, resolution: Vector2i, framerate: int) -> void:
	config = ConfigFile.new()
	project_path = path
	
	set_title(title, false)
	set_resolution(resolution)
	set_framerate(framerate)
	
	update_recent_projects()
	_on_project_loaded.emit()
	save_project()


func load_project(path: String) -> void:
	if !path.to_lower().contains(".gozen"):
		var new_path: String = "%s.gozen" % path
		if !FileAccess.file_exists(new_path):
			Printer.error("Can't load project as path does not have '*.gozen' extension!\n\t%s" % path)
			get_tree().quit(-2)
			return
		path = new_path
	project_path = path
	var file := FileAccess.open(project_path, FileAccess.READ)
	var data: Dictionary = str_to_var(file.get_as_text())
	for key: String in keys:
		set(key, data[key])
	
	_on_title_changed.emit(get_title())
	update_recent_projects()
	_on_project_loaded.emit()


func save_project() -> void:
	var file := FileAccess.open(project_path, FileAccess.WRITE)
	var data := {}
	for key: String in keys:
		data[key] = get(key)
	file.store_string(var_to_str(data))
	_on_project_saved.emit()
	unsaved_changes = false


func update_recent_projects() -> void:
	var recent_projects := RecentProjects.new()
	recent_projects.update_project(get_title(), project_path)


#################################################################
##
##    DATA GETTERS AND SETTERS
##
#################################################################

###############################################################
#region  Title  ###############################################
###############################################################

func get_title() -> String:
	return title


func set_title(new_title: String, update: bool = true) -> void:
	title = new_title
	_on_title_changed.emit(new_title)
	unsaved_changes = true
	if update:
		update_recent_projects()

#endregion
###############################################################
#region  Resolution  ##########################################
###############################################################

func get_resolution() -> Vector2i:
	return resolution


func set_resolution(new_resolution: Vector2i) -> void:
	resolution = new_resolution
	_on_resolution_changed.emit(new_resolution)
	unsaved_changes = true

#endregion
###############################################################
#region  Framerate  ###########################################
###############################################################

func get_framerate() -> float:
	return framerate


func set_framerate(new_framerate: float) -> void:
	framerate = new_framerate
	_on_framerate_changed.emit(new_framerate)
	unsaved_changes = true

#endregion
###############################################################
