@tool
extends EditorScript

const EXTENSIONS_TO_SCAN: PackedStringArray = ["gd", "tscn", "tres"]
const IGNORE_FOLDERS: PackedStringArray = ["addons", ".godot", "translations", "theming"]



func _run() -> void:
	print("Scanning project for translatable files...")
	var files: PackedStringArray = []
	scan_dir("res://", files)
	print("Found ", files.size(), " files.")

	ProjectSettings.set_setting("internationalization/locale/translations_pot_files", files)
	ProjectSettings.save()
	print("Project Settings saved! You can now generate your POT file.")


func scan_dir(path: String, result_array: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if !dir: return print("An error occurred when trying to access the path:
		" + path)

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if file_name not in IGNORE_FOLDERS and not file_name.begins_with("."):
				scan_dir(path.path_join(file_name), result_array)
		else:
			if file_name.get_extension() in EXTENSIONS_TO_SCAN:
				result_array.append(path.path_join(file_name))

		file_name = dir.get_next()
