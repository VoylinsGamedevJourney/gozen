extends Node

signal sig_saving_project
signal sig_saving_complete
signal sig_loading_project
signal sig_loading_complete
signal sig_opening_project
signal sig_opening_complete

var current_project: ProjectData


func save_project() -> void:
	sig_saving_project.emit()
	if get_project_path() == "":
		printerr("Not implemented yet: Path is empty")
		return
	var file: FileAccess = FileAccess.open(get_project_path(), FileAccess.WRITE)
	sig_saving_complete.emit()


func load_project() -> void:
	sig_loading_project.emit()
	sig_loading_complete.emit()


func open_project() -> void:
	sig_opening_project.emit()
	# Signals to call after opening project
	current_project = ProjectData.new()
	sig_opening_complete.emit()


func get_project_name() -> String: return current_project.project_name
func get_project_path() -> String: return current_project.project_path



