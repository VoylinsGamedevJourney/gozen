@tool
extends EditorScript


const POT: String = "localization_template.pot"
const PATH: String = "res://translations/"



func _run() -> void:
	var base_dir: String = ProjectSettings.globalize_path(PATH)
	var pot_path: String = base_dir.path_join(POT)
	var dir: DirAccess = DirAccess.open(base_dir)
	dir.list_dir_begin()

	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "po":
			var po_path: String = base_dir.path_join(file_name)
			_merge_po_file(po_path, pot_path)
		file_name = dir.get_next()

	EditorInterface.get_resource_filesystem().scan()
	print("Updating PO files complete!")


func _merge_po_file(po_path: String, pot_path: String) -> void:
	var arguments: PackedStringArray = ["--update", "--backup=none", po_path, pot_path]
	var output: PackedStringArray = []

	print("Updating: ", po_path.get_file(), " ...")
	if OS.execute("msgmerge", arguments, output, true) != 0:
		printerr("Failed to update ", po_path.get_file())
		printerr("Is 'msgmerge' in your system PATH?")
		printerr("Output: ", output)
	else:
		print("Success\n---")
