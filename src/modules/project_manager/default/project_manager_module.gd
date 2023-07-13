extends Node


#
#enum SORT { NAME, EDIT_DATE, CREATION_DATE }
#
#var file_explorer
#var selected_project: Project
#
#
#func _ready() -> void:
#	# Loading in all projects
#	load_projects_list()
#
#	# Just using the canceled dialog button function to hide the window
#	close_new_project_dialog()
#	load_projects_list_box()
#	file_explorer = ModuleManager.get_module("file_explorer")
#	add_child(file_explorer)
#
#
#func get_projects_list(order: SORT) -> Array:
#	var projects_dic := {}
#	var project_keys := []
#	var order_name: String
#	var order_id: int = 0
#
#	for project in projects_list:
#		if order == SORT.CREATION_DATE: order_name = str(project.p_creation)
#		elif order == SORT.EDIT_DATE:   order_name = str(project.p_edit)
#		elif order == SORT.NAME:        order_name = project.p_name
#
#		while projects_dic.has("%s_%s" % [order_name, order_id]): order_id += 1
#		projects_dic["%s_%s" % [order_name, order_id]] = project
#		project_keys.append("%s_%s" % [order_name, order_id])
#
#	project_keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
#	var final_list := []
#	for project in project_keys: final_list.append(projects_dic[project])
#	return final_list
#
#
#func load_projects_list_box() -> void:
#	for child in %ProjectsList.get_children():
#		child.queue_free()
#
#	# Add all project cards to the scroll/vbox
#	var button_group := ButtonGroup.new()
#	var sorted_list := get_projects_list(%SortOptionButton.selected)
#	for project in sorted_list:
#		var new_entry: Node = preload("res://modules/project_manager/default/project_list_entry.tscn").instantiate()
#		new_entry.set_data(project)
#		new_entry.button_group = button_group
#		new_entry.connect("project_clicked", _on_project_button_pressed)
#		%ProjectsList.add_child(new_entry)
#
#
#func _on_import_project_button_pressed() -> void:
#	file_explorer.file_explorer_title = "Select project file"
#	file_explorer.file_mode = FileExplorerInterface.FILE_MODE.SELECT_FILE
#	file_explorer.file_filters = ["*.gozen"]
#	file_explorer.connect_to_signal(
#		file_explorer.on_file_selected, 
#		_on_file_explorer_import_selected)
#	file_explorer.open_file_explorer()
#
#
#func _on_file_explorer_import_selected(path: String) -> void:
#	import_project(path)
#	save_projects_list()
#	load_projects_list_box()
#
#
#func _on_add_new_project_button_pressed() -> void:
#	$AddNewProjectPanel.visible = true
#	$AddNewProjectPanel/AddNewProjectDialog.popup_centered()
#
#
## Cancel/Close function for the AddNewProjectDialog window
#func close_new_project_dialog() -> void:
#	$AddNewProjectPanel.visible = false
#	$AddNewProjectPanel/AddNewProjectDialog.hide()
#	$AddNewProjectPanel.find_child("ProjectNameLineEdit").text = ""
#	$AddNewProjectPanel.find_child("LocationLineEdit").text = ""
#
#
## Confirm for the AddNewProjectDialog window
#func create_new_project() -> void:
#	create_project(
#		$AddNewProjectPanel.find_child("ProjectNameLineEdit").text,
#		$AddNewProjectPanel.find_child("LocationLineEdit").text)
#	close_new_project_dialog()
#	load_projects_list_box()
#
#
## The path search button for the AddNewProjectDialog window
## This opens the file manager.
#func _on_search_new_project_path_pressed() -> void:
#	file_explorer.file_explorer_title = "Select project folder"
#	file_explorer.file_mode = FileExplorerInterface.FILE_MODE.SELECT_FOLDER
#	file_explorer.connect_to_signal(
#		file_explorer.on_dir_selected, 
#		_on_location_search_selected)
#	file_explorer.open_file_explorer()
#
#
## The signal connect for _on_search_new_project_path_pressed
#func _on_location_search_selected(dir: String) -> void:
#	$AddNewProjectPanel.find_child("LocationLineEdit").text = dir
#
#
#func _on_filter_text_change(filter_text: String) -> void:
#	for child in %ProjectsList.get_children():
#		child.visible = filter_text.length() == 0 or filter_text.to_lower() in child.name.to_lower()
#
#
#func _on_remove_project_button_pressed() -> void:
#	if selected_project == null: return
#	remove_project(selected_project)
#	load_projects_list_box()
#
#
#func _on_remove_missing_projects_button_pressed() -> void:
#	remove_missing_projects()
#	load_projects_list_box()
#
#
#func _on_project_button_pressed(project_entry: Project) -> void:
#	if selected_project != project_entry:
#		selected_project = project_entry
#		return
#	open_editor_layout(selected_project)
#
#
#func _on_sort_option_item_selected(_index: int) -> void:
#	load_projects_list_box()
