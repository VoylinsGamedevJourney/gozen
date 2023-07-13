extends ProjectManagerInterface

enum SORT { NAME, EDIT_DATE, CREATION_DATE }

var file_explorer
var selected_project_path: String


func _ready() -> void:
	# Populating the project list on startup
	update_projects_list()


func update_projects_list(_order_index: int = -1) -> void:
	# Cleaning the project list before adding all projects in order
	for child in %ProjectsList.get_children():
		child.queue_free()
	
	var button_group := ButtonGroup.new()
	
	var order := (%SortOptionButton as OptionButton).selected
	var projects_dic := {}
	var project_keys := []
	var order_name: String
	var order_id: int = 0
	
	for project in projects:
		match order:
			SORT.CREATION_DATE: order_name = str(project.p_creation)
			SORT.EDIT_DATE:     order_name = str(project.p_edit)
			SORT.NAME:          order_name = project.p_name
		
		while projects_dic.has("%s_%s" % [order_name, order_id]):
			order_id += 1
		projects_dic["%s_%s" % [order_name, order_id]] = project
		project_keys.append("%s_%s" % [order_name, order_id])

	project_keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	var sorted : Array = []
	for project in project_keys: sorted.append(projects_dic[project])
	
	for project in sorted:
		var new_entry: Node = preload("res://modules/project_manager/default/project_list_entry.tscn").instantiate()
		new_entry.set_data(project)
		new_entry.button_group = button_group
		new_entry.connect("project_clicked", _on_project_button_pressed)
		%ProjectsList.add_child(new_entry)


func _on_filter_text_change(filter_text: String) -> void:
	for child in %ProjectsList.get_children():
		child.visible = filter_text.length() == 0 or filter_text.to_lower() in child.name.to_lower()


func _on_add_new_project_pressed() -> void:
	$NewProjectPopup.show_popup()


func _on_import_project_pressed() -> void:
	file_explorer = ModuleManager.get_module("file_explorer")
	add_child(file_explorer)
	file_explorer.title = "Select project file"
	file_explorer.mode = FileExplorerInterface.FILE_MODE.SELECT_FILE
	file_explorer.filters = ["*.gozen"]
	file_explorer.connect_to_signal(
		file_explorer.on_file_selected, 
		_on_file_explorer_import_selected)
	file_explorer.open_file_explorer()


func _on_remove_project_pressed() -> void:
	if selected_project_path == null: return
	remove_project_from_list(selected_project_path)
	update_projects_list()


func _on_remove_missing_pressed() -> void:
	remove_missing_projects()
	update_projects_list()


func _on_file_explorer_import_selected(path: String) -> void:
	import_project(path)
	save_projects()
	update_projects_list()


func _on_project_button_pressed(project_path: String) -> void:
	if selected_project_path != project_path:
		selected_project_path = project_path
		return
	open_editor_layout(selected_project_path)
