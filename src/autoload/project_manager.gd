extends Node

@export var edit_mode: bool = false

var title := "Untitled project": 
	set(new_title): 
		# TODO: Remove invalid chars
		# TODO: Change file path + file name
		title = new_title 
		Globals._on_project_title_change.emit()
var path: String = "" # user://project_folder

var resolution := Vector2i(1920, 1080):
	set(x):
		resolution = x
		Globals._on_project_resolution_change.emit()


func _ready() -> void:
	Globals._on_exit_startup.connect(func():edit_mode = true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save_project"): save_project()


func get_full_path() -> String:
	return "%s/%s.gozen" % [path, title]


## A quick check to see if a project file is actually valid
func check_project_file(project_path: String) -> bool:
	if !FileAccess.file_exists(project_path): return false
	var project_file := FileAccess.open_compressed(project_path, FileAccess.READ)
	if FileAccess.get_open_error() != OK: return false
	var file_data = project_file.get_var()
	if not file_data is Dictionary: return false
	if !(file_data as Dictionary).has("title"): return false
	if !(file_data as Dictionary).has("path"): return false
	return true


func load_project(project_path: String) -> void:
	# TODO: Make this work
	pass


func save_project() -> void:
	if !edit_mode: return
	if path == "": # New project
		# Open file explorer
		var file_explorer := ModuleManager.get_module("file_explorer")
		add_child(file_explorer)
		file_explorer.open_explorer(FileExplorerModule.MODE.OPEN_FILE, ["*.gozen"])
		file_explorer.collect_data.connect(_on_new_project_path_selected)
		return
#	bjj;doajk;dsj;ladj
	# TODO: Check if there is a path or not
	# If there 0was no path, we should add this to top of recent projects
	# TODO: Make this work
	pass


func _on_new_project_path_selected(new_path: String) -> void:
	title = new_path.split("/")[-1].replace(".gozen",'')
	path = new_path.replace("%s.gozen" % title, '')
	save_project()
