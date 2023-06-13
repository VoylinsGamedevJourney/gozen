class_name ProjectManagerInterface
extends Control

## Project Manager Interface
## 
## The Project Manager is the startup view of the editor where 
## people can create, import, and remove projects. This module 
## gets loaded at startup.


## A list which contains all current projects. These are added as
## "ProjectListEntry" entries to this array.
var projects_list := []



## Saving all project paths into a file.
func save_projects_list() -> void:
	var projects_paths := []
	for project in projects_list:
		projects_paths.append(project.p_path)
	var file := FileAccess.open_compressed(
		Globals.PATH_PROJECT_LIST, 
		FileAccess.WRITE)
	file.store_var(projects_paths)


## Loading all needed info from each project file and add it
## to 'projects_list' as a 'ProjectListEntry'.
func load_projects_list() -> void:
	if !FileAccess.file_exists(Globals.PATH_PROJECT_LIST):
		save_projects_list()
		return
	projects_list = []
	
	var file := FileAccess.open_compressed(
		Globals.PATH_PROJECT_LIST, 
		FileAccess.READ)
	var projects_paths: Array = file.get_var()
	file.close()
	
	# Loop through all file paths to check if projects are still there
	for project_path in projects_paths:
		import_project(project_path)


## When importing a file, only the path is needed, from this path
## all other information is checked and fetched.
func import_project(project_path: String) -> void:
	var new_entry: ProjectListEntry = ProjectListEntry.new()
	
	if !FileAccess.file_exists(project_path):
		printerr("No project file at '%s'!" % project_path)
		new_entry.p_path = project_path
	else:
		var file = FileAccess.open_compressed(
			project_path, 
			FileAccess.READ)
		if !new_entry.import_dic(file.get_var()):
			printerr("Incorrect project file: '%s'!!" % project_path)
	projects_list.append(new_entry)


## Creating a project requires only a name and a location.
## !! Required info may change as the editor evolves !!
func create_project(p_name: String, p_location: String) -> void:
	if !DirAccess.dir_exists_absolute(p_location):
		printerr("'%s' is not a valid directory for a gozen project!")
		return
	
	# Check if project name is valid (no special characters)
	# This is important as Operating Systems don't always
	# accept these characters
	for character in ['<','>',':','"','/','\\','|','?','*']:
		if character in p_name:
			printerr("No special characters are allowed in project names!")
			return
	
	var full_path: String = "%s/%s.gozen" % [p_location, p_name]
	var new_project: ProjectListEntry = ProjectListEntry.new()
	new_project.p_name = p_name
	new_project.p_path = full_path
	new_project.p_creation = new_project.date_to_int()
	new_project.p_edit = new_project.date_to_int()
	
	var dir := DirAccess.open(p_location)
	if !dir:
		printerr("Could not create file at '%s'!" % full_path)
		printerr("\t# We possibly don't have write access in this folder!")
		return 
	
	if FileAccess.file_exists(full_path):
		printerr("Project file already exists at location '%s'!" % full_path)
		return
	
	var file := FileAccess.open_compressed(full_path, FileAccess.WRITE)
	file.store_var(new_project.export_dic())
	file.close()
	
	# Checking if project with this path has not been added yet
	file = FileAccess.open_compressed(Globals.PATH_PROJECT_LIST, FileAccess.READ)
	var projects_paths: Array = file.get_var()
	file.close()
	if new_project.p_path in projects_paths:
		printerr("Project with path '%s' is already in the list!" % new_project.p_path)
		return
	
	projects_list.append(new_project)
	save_projects_list()


func remove_project(project_entry: ProjectListEntry) -> void:
	projects_list.erase(project_entry)
	save_projects_list()


func remove_missing_projects() -> void:
	for project in projects_list.duplicate():
		if project.p_creation == 0: projects_list.erase(project)
	save_projects_list()


class ProjectListEntry:
	var p_name: String = "Missing project file"
	var p_path: String
	var p_creation: int = 0
	var p_edit: int = 0
	
	
	func import_dic(dic: Dictionary) -> bool:
		var valid: bool = false
		for x in dic:
			if get(x) != null:
				valid = true
				self.set(x, dic[x])
		
		return valid
	
	
	func export_dic() -> Dictionary:
		return {
			"p_name": p_name,
			"p_path": p_path,
			"p_creation": p_creation,
			"p_edit": p_edit
		}
	
	
	func date_to_int(date: Dictionary = Time.get_datetime_dict_from_system()) -> int:
		return int(
			str(date.year) +
			"%02d" % date.month +
			"%02d" % date.day +
			"%02d" % date.hour +
			"%02d" % date.minute)
	
	
	func int_to_date(date: int) -> String:
		var str_date: String = str(date)
		return "%s-%s-%s  %s:%s" % [
			str_date.substr(0, 4),
			str_date.substr(4, 2),
			str_date.substr(6, 2),
			str_date.substr(8, 2),
			str_date.substr(10, 2)]
