extends Node

const settings_path := "user://settings.dat"
const folder_structure: PackedStringArray = [
	"modules",
	"modules/project_scene",
]

var projects := [] # List of all saved project paths


func _ready() -> void:
	if FileAccess.file_exists(settings_path): 
		load_settings()
		return
	save_settings()


func save_settings() -> void:
	print("Save settings ...")
	var data := {
		"projects": projects
	}
	var file := FileAccess.open_compressed(settings_path, FileAccess.WRITE)
	file.store_var(data)
	file.close()


func load_settings() -> void:
	print("Loading settings ...")
	var file := FileAccess.open_compressed(settings_path, FileAccess.READ)
	var temp_data: Dictionary = file.get_var()
	file.close()
	for x in temp_data:
		if get(x) != null: set(x, temp_data[x])
