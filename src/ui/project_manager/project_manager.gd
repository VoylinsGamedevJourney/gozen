class_name ProjectManager extends PanelContainer

enum SORT { NAME, EDIT_DATE, CREATION_DATE }

var selected_project_path: String
var projects_list := []


func _ready() -> void:
	projects_list = ProjectManager.load_projects_list()
	update_projects_list()
	
	%SearchProjectsLineEdit.connect(
		"text_changed", func(filter_text):
			for child in %ProjectsList.get_children():
				child.visible = filter_text.length() == 0 or filter_text.to_lower() in child.name.to_lower())
	%AddNewProjectButton.connect(
		"pressed", func(): $NewProjectPanel.visible = true)
	%ImportProjectButton.connect(
		"pressed", func():
			var explorer = preload("res://ui/file_explorer/file_explorer.tscn").instantiate()
			add_child(explorer)
			explorer.set_info("FILE_EXPLORER_TITLE_SELECT_GOZEN", ["*.gozen"])
			explorer.connect(
				"on_file_selected", 
				func(path):
					import_project(path)
					update_projects_list())
			explorer.show_file_explorer())
	%RemoveProjectButton.connect(
		"pressed", func():
			if selected_project_path == null: return
			for project in projects_list:
				if project.project_path == selected_project_path:
					projects_list.erase(project)
			ProjectManager.save_projects_list(projects_list)
			update_projects_list())
	%RemoveMissingProjectsButton.connect(
		"pressed", func():
			for project in projects_list.duplicate():
				if project.project_creation == 0:
					projects_list.erase(project)
			ProjectManager.save_projects_list(projects_list)
			update_projects_list())
	


static func save_projects_list(list: Array) -> void:
	var project_paths: PackedStringArray = []
	for project in list: 
		project_paths.append(project)
	
	var file := FileAccess.open_compressed(Globals.PATH_PROJECTS_LIST, FileAccess.WRITE)
	if FileAccess.get_open_error():
		printerr("Could not open project list at path: %s\n\tError: %s" % [
			Globals.PATH_PROJECT_LIST, FileAccess.get_open_error()])
		return
	file.store_var(project_paths)


static func load_projects_list() -> Array:
	var file := FileAccess.open_compressed(
		Globals.PATH_PROJECTS_LIST, FileAccess.READ)
	if file == null:
		var error := FileAccess.get_open_error()
		printerr("Could not open projects list file!\n\tError: %s" % error)
		return []
	
	var project_paths: PackedStringArray = file.get_var()
	var list := []
	for project_path in project_paths:
		var project := Project.new()
		project.load_project(project_path)
		list.append(project)
	return list


func import_project(project_path: String,) -> void:
	var project := Project.new()
	project.load_project(project_path)
	projects_list.append(project)
	ProjectManager.save_projects_list(projects_list)


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
	
	for project in projects_list:
		match order:
			SORT.CREATION_DATE: order_name = str(project.project_creation)
			SORT.EDIT_DATE:     order_name = str(project.project_edit)
			SORT.NAME:          order_name = project.project_name
		
		while projects_dic.has("%s_%s" % [order_name, order_id]):
			order_id += 1
		projects_dic["%s_%s" % [order_name, order_id]] = project
		project_keys.append("%s_%s" % [order_name, order_id])

	project_keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	var sorted : Array = []
	for project in project_keys: sorted.append(projects_dic[project])
	
	for project in sorted:
		var new_entry: Node = preload("res://ui/project_manager/project_list_entry.tscn").instantiate()
		new_entry.set_data(project)
		new_entry.button_group = button_group
		new_entry.connect(
			"project_clicked", 
			func(project_path: String):
				if selected_project_path != project_path:
					selected_project_path = project_path; return
				open_editor(selected_project_path))
		%ProjectsList.add_child(new_entry)


func add_project(project_name: String, project_folder: String) -> void:
	var project: Project = Project.new()
	project.new_project(project_name, project_folder)


func create_project(p_name: String, p_folder: String) -> void:
	var project := Project.new()
	project.new_project(p_name, p_folder)
	open_editor(project.project_path)


func open_editor(project_path: String) -> void:
	if !FileAccess.file_exists(project_path):
		printerr("Can't open missing project!")
		return
	Globals.project = Project.new()
	Globals.project.load_project(project_path)
	get_tree().change_scene_to_file("res://ui/editor/editor.tscn")
