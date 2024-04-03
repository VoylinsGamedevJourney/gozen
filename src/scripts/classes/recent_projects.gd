class_name RecentProjects extends Node

var data: Array


func _init() -> void:
	if !FileAccess.file_exists(Globals.PATH_RECENT_PROJECTS):
		return # No data so no need to continue
	load_data()
	
	# Check data
	var l_clean_data: Array = []
	var l_existing_paths: PackedStringArray = []
	
	for l_entry: RecentProject in data:
		if FileAccess.file_exists(l_entry.path) and not l_entry.path in l_existing_paths:
			l_clean_data.append(l_entry)
			l_existing_paths.append(l_entry.path)
	if data != l_clean_data:
		data = l_clean_data
		save_data()


func load_data() -> void:
	var l_file := FileAccess.open(Globals.PATH_RECENT_PROJECTS, FileAccess.READ)
	data = str_to_var(l_file.get_as_text())


func save_data() -> void:
	var l_file := FileAccess.open(Globals.PATH_RECENT_PROJECTS, FileAccess.WRITE)
	l_file.store_string(var_to_str(data))


func add_new_project(a_title: String, a_path: String) -> void:
	var l_project: RecentProject = RecentProject.new()
	
	l_project.create(a_title, a_path)
	data.insert(0, l_project)
	save_data()


func update_project(a_title: String, a_path: String) -> void:
	var l_clean_data : Array = []
	var l_found: bool = false
	
	for l_entry: RecentProject in data:
		if l_entry.path == a_path:
			l_found = true
			l_entry.title = a_title
			l_clean_data.insert(0, l_entry)
		l_clean_data.append(l_entry)
	
	if !l_found:
		add_new_project(a_title, a_path)
	else:
		save_data()
