class_name RecentProjects extends Node

var data: Array


func _init():
	if !FileAccess.file_exists(Globals.PATH_RECENT_PROJECTS):
		return # No data so no need to continue
	load_data()
	
	# Check data
	var clean_data: Array = []
	var existing_paths: PackedStringArray = []
	for entry: RecentProject in data:
		if FileAccess.file_exists(entry.path) and not entry.path in existing_paths:
			clean_data.append(entry)
			existing_paths.append(entry.path)
	if data != clean_data:
		data = clean_data
		save_data()


func load_data() -> void:
	var file := FileAccess.open(Globals.PATH_RECENT_PROJECTS, FileAccess.READ)
	data = str_to_var(file.get_as_text())
	file.close()


func save_data() -> void:
	var file := FileAccess.open(Globals.PATH_RECENT_PROJECTS, FileAccess.WRITE)
	file.store_string(var_to_str(data))
	file.close()


func add_new_project(title: String, path: String) -> void:
	var project := RecentProject.new()
	project.create(title, path)
	data.insert(0, project)
	save_data()


func update_project(title: String, path: String) -> void:
	var clean_data : Array = []
	var found := false
	for entry: RecentProject in data:
		if entry.path == path:
			found = true
			entry.title = title
			clean_data.insert(0, entry)
		clean_data.append(entry)
	if !found:
		add_new_project(title, path)
	else:
		save_data()
