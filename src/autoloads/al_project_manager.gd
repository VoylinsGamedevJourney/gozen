extends Node

signal _on_project_loaded
signal _on_project_saved

signal _on_unsaved_changes
signal _on_changes_saved

signal _on_title_changed(new_title: String)
signal _on_resolution_changed(new_resolution: Vector2i)
signal _on_framerate_changed(new_framerate: int)


var config: ConfigFile
var project_path: String


func new_project(title: String, path: String, resolution: Vector2i, framerate: int) -> void:
	config = ConfigFile.new()
	project_path = path
	
	set_title(title, false)
	set_resolution(resolution)
	set_framerate(framerate)
	
	save_project()
	update_recent_projects()


func load_project(path: String) -> void:
	if !path.to_lower().contains(".gozen"):
		Printer.error("Can't load project as path does not have '*.gozen' extension!")
		return
	if config == null:
		config = ConfigFile.new()
	if config.load(path):
		Printer.error("Could not open project file!")
		return
	project_path = path
	update_recent_projects()


func save_project() -> void:
	config.save(project_path)
	_on_project_saved.emit()


func update_recent_projects() -> void:
	# Each entry is made up like this: 'title||path||datetime'
	var file := FileAccess.open(
		ProjectSettings.get_setting("globals/path/recent_projects"), 
		FileAccess.READ)
	var data: String
	if FileAccess.file_exists(ProjectSettings.get_setting("globals/path/recent_projects")):
		data = file.get_as_text()
	data = "%s||%s||%s\n%s" % [
			get_title(), 
			project_path, 
			Time.get_datetime_string_from_system(),
			data]
	if data.ends_with("\n"):
		print(8888) # TODO remove last line
	file = FileAccess.open(
		ProjectSettings.get_setting("globals/path/recent_projects"),
		FileAccess.WRITE)
	file.store_string(data)

###############################################################
#region Project Title  ########################################
###############################################################

func get_title() -> String:
	return config.get_value("general", "title", tr("TEXT_UNTITLED_PROJECT_TITLE"))


func set_title(new_title: String, update: bool = true) -> void:
	config.set_value("general", "title", new_title)
	_on_title_changed.emit(new_title)
	save_project()
	if update:
		update_recent_projects()

#endregion
###############################################################
#region Project Resolution  ###################################
###############################################################

func get_resolution() -> Vector2i:
	return config.get_value("general", "resolution", Vector2i(1920,1080))


func set_resolution(new_resolution: Vector2i) -> void:
	config.set_value("general", "resolution", new_resolution)
	_on_resolution_changed.emit(new_resolution)
	save_project()

#endregion
###############################################################
#region Project Framerate  ####################################
###############################################################

func get_framerate() -> int:
	return config.get_value("general", "framerate", 30)


func set_framerate(new_framerate: int) -> void:
	config.set_value("general", "framerate", new_framerate)
	_on_framerate_changed.emit(new_framerate)
	save_project()

#endregion
###############################################################
