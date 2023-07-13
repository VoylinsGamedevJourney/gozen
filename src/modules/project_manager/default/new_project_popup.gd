extends Panel

var file_explorer


func show_popup() -> void:
	$AddNewProjectDialog.popup_centered()


func _on_path_select_pressed() -> void:
	file_explorer = ModuleManager.get_module("file_explorer")
	file_explorer.visible = false
	add_child(file_explorer)
	
	file_explorer.title = "FILE_EXPLORER_SELECT_FOLDER"
	file_explorer.mode = FileExplorerInterface.FILE_MODE.SELECT_FOLDER
	file_explorer.connect_to_signal(
		file_explorer.on_dir_selected, 
		_on_location_search_selected)
	file_explorer.open_file_explorer()


## The signal connect for _on_search_new_project_path_pressed
func _on_location_search_selected(dir: String) -> void:
	find_child("LocationLineEdit").text = dir



func _on_popup_cancel() -> void:
	$AddNewProjectDialog.hide()
	find_child("ProjectNameLineEdit").text = ""
	find_child("LocationLineEdit").text = ""
	self.queue_free()


func _on_popup_confirmed() -> void:
	get_parent().create_project(
		find_child("ProjectNameLineEdit").text,
		find_child("LocationLineEdit").text)
	_on_popup_cancel()
	get_parent().update_projects_list()
