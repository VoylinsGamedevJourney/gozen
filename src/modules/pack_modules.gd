@tool
extends EditorScript
## Run from the file manager inside of the GoZen project by right clicking the
## script and selecting 'run'. The packed modules should appear in the main
## repo folder in a subfolder called `modules`.

const PATH_EXPORT: String = "res://../modules"


@export var export_folders: Array[String] = [ "godot_themes", "transform_advanced" ]



func _run() -> void:
	DirAccess.make_dir_recursive_absolute(PATH_EXPORT)
	for folder_path: String in export_folders:
		var full_path: String = "res://modules/%s" % folder_path
		if not DirAccess.dir_exists_absolute(full_path):
			printerr("PackModules: Folder does not exist: %s" % full_path)
		else:
			_pack_module(full_path, full_path.get_file())
	print("Finished packing all specified modules!")


func _pack_module(module_path: String, module_name: String) -> void:
	var files: Array[String] = []
	_collect_files(module_path, files)

	if files.is_empty():
		return

	var extension: String = ".gzmodule"
	var module_tres_path: String = module_path.path_join("module.tres")
	if ResourceLoader.exists(module_tres_path):
		var module_res: Resource = load(module_tres_path)
		if module_res is GoZenModule:
			var gozen_module: GoZenModule = module_res as GoZenModule
			var has_scenes: bool = not gozen_module.custom_scenes.is_empty()
			var has_editor_extensions: bool = (
					!gozen_module.custom_panels.is_empty() or
					!gozen_module.custom_effects.is_empty() or
					!gozen_module.custom_transitions.is_empty() or
					!gozen_module.custom_themes.is_empty() or
					!gozen_module.settings.is_empty())
			if has_scenes and not has_editor_extensions:
				extension = ".gzscene"

	var package_path: String = PATH_EXPORT.path_join(module_name + extension)
	var packer: PCKPacker = PCKPacker.new()
	var err: Error = packer.pck_start(package_path)
	if err != OK:
		printerr("Couldn't start package for module '%s'!\n\tError code: %s" % [module_name, err])
		return

	var files_to_pack: Array[String] = []
	var seen_files: Dictionary[String, bool] = {}
	for file_path: String in files:
		if FileAccess.file_exists(file_path) and not seen_files.has(file_path):
			seen_files[file_path] = true
			files_to_pack.append(file_path)

		if file_path.ends_with(".import"):
			for imported_path: String in _get_imported_files(file_path):
				if FileAccess.file_exists(imported_path) and not seen_files.has(imported_path):
					seen_files[imported_path] = true
					files_to_pack.append(imported_path)

	for file_path: String in files_to_pack:
		err = packer.add_file(file_path, file_path)
		if err != OK:
			printerr("Could not add '%s' to PCK for module '%s'!\n\tError code: %s" % [
					file_path, module_name, err])

	err = packer.flush(true)
	if err != OK:
		printerr("Could not flush PCK for module '%s'!\n\tError code: %s" % [module_name, err])
	else:
		print("Packed module '%s' with %s files!" % [module_name, files.size()])


func _collect_files(current_path: String, files: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(current_path)
	if dir == null:
		printerr("Couldn't open '%s'!\n\tError code: %s" % [current_path, DirAccess.get_open_error()])
		return
	dir.list_dir_begin()

	var entry: String = dir.get_next()
	while entry != "":
		if entry not in [".", ".."]:
			var full_path: String = current_path.path_join(entry)
			if dir.current_is_dir():
				_collect_files(full_path, files)
			else:
				files.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _get_imported_files(import_file_path: String) -> Array[String]:
	var imported_files: Array[String] = []
	var config: ConfigFile = ConfigFile.new()
	if config.load(import_file_path) != OK:
		printerr("PackModules: Couldn't load import file '%s'!" % import_file_path)
		return imported_files

	if config.has_section_key("deps", "dest_files"):
		var raw_dest_files: Variant = config.get_value("deps", "dest_files", [])
		if raw_dest_files is PackedStringArray:
			for dest_path: String in (raw_dest_files as PackedStringArray):
				if not dest_path.is_empty() and dest_path not in imported_files:
					imported_files.append(dest_path)
		elif raw_dest_files is Array:
			for dest_path: Variant in (raw_dest_files as Array):
				var path_str: String = str(dest_path)
				if not path_str.is_empty() and path_str not in imported_files:
					imported_files.append(path_str)

	if config.has_section("remap"):
		for key: String in config.get_section_keys("remap"):
			if key == "path" or key.begins_with("path."):
				var remap_path: String = str(config.get_value("remap", key, ""))
				if not remap_path.is_empty() and remap_path not in imported_files:
					imported_files.append(remap_path)
	return imported_files
