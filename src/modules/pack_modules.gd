@tool
extends EditorScript
## Run from the file manager inside of the GoZen project by right clicking the
## script and selecting 'run'. The packed modules should appear in the main
## repo folder in a subfolder called `modules`.

const PATH_EXPORT: String = "res://../modules"


@export var export_folders: Array[String] = [ "godot_themes" ]



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

	var pck_path: String = PATH_EXPORT.path_join(module_name + ".pck")
	var packer: PCKPacker = PCKPacker.new()
	var err: Error = packer.pck_start(pck_path)
	if err != OK:
		printerr("Couldn't start PCK for module '%s'!\n\tError code: %s" % [module_name, err])
		return

	for file_path: String in files:
		if FileAccess.file_exists(file_path):
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
			files.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
