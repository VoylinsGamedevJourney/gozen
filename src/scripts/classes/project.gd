class_name Project extends Node


var project_name: String = "Missing"
var project_path: String = "/home/"
var project_creation: int = 0
var project_edit: int = 0
var project_fps: int

var files := {} # video id's start with v_, pictures = p_, audio = a_, color = c_
var folders := {"Main": []}

var lines := [[],[]] # First array is for video, second array for audio
# TODO: Timeline stuff
#var blocks := {} # group_id: [start_frame, end_frame]
#var groups := {} # group_id: [block_id's,...]
#var effects := {}
# Every line is a dictionary.
# The key is the frame, this frame has an array
# [file_id, video_frame, block_id, group_id]
# Effects get added by looking at block id
# videos should be saved with an id number, this id number gets put inside
# of the folders. The id should contain an array which contains the properties
# like fps, max frames, path, ...


func save_project() -> void:
	var data := {}
	for prop in get_property_list():
		if prop.usage == 4096: data[prop.name] = get(prop.name)
	
	var file := FileAccess.open_compressed(project_path, FileAccess.WRITE)
	file.store_var(data)


func load_project(path: String) -> void:
	project_path = path # Incase original path changed
	
	if !FileAccess.file_exists(project_path): return
	
	var file := FileAccess.open_compressed(project_path, FileAccess.READ)
	var data: Dictionary = file.get_var()
	for prop in data: set(prop, data[prop])


func new_project(p_name: String, p_folder: String, p_fps: int = 30) -> void:
	if !DirAccess.dir_exists_absolute(p_folder):
		return printerr("Folder does not exist at path: %s" % p_folder)
	
	project_name = p_name
	project_path = "%s/%s.gozen" % [p_folder, p_name]	
	project_creation = TimeManager.date_to_int()
	project_edit = project_creation
	project_fps = p_fps
	
	# Fix path to not include invalid characters
	for x in ['<','>',':','"','/','\\','|','?','*',' ']:
		project_path = project_path.replace(x,"_")
	
	save_project()
