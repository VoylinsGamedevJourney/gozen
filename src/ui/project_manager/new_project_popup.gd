extends Panel


func _ready() -> void: 
	self.visible = false


func _on_path_select_pressed() -> void:
	var explorer = preload("res://ui/file_explorer/file_explorer.tscn").instantiate()
	get_parent().add_child(explorer)
	explorer.set_info("FILE_EXPLORER_SELECT_FOLDER")
	explorer.connect(
		"on_dir_selected", 
		_on_location_search_selected)
	explorer.show_file_explorer()


## The signal connect for _on_search_new_project_path_pressed
func _on_location_search_selected(dir: String) -> void:
	find_child("LocationLineEdit").text = dir


func _on_cancel() -> void:
	self.visible = false
	find_child("ProjectNameLineEdit").text = ""
	find_child("LocationLineEdit").text = ""


func _on_create() -> void:
	if find_child("LocationLineEdit").text.length() == 0:
		return printerr("Location is empty")
	if find_child("ProjectNameLineEdit").text.length() == 0:
		return printerr("Project name is empty")
	get_parent().create_project(
		find_child("ProjectNameLineEdit").text,
		find_child("LocationLineEdit").text)
	_on_cancel()
	get_parent().update_projects_list()
