extends Node


var _path: String = ""
var _unsaved_changes: bool = false

var files: Dictionary = {} # {Unique_id (int32): File_object}
var _files_data: Dictionary = {} # {Unique_id (int32): file_data (Varies)}



func save(a_path: String = _path) -> void:
	if a_path == "":
		var l_dialog: FileDialog = FileDialog.new()

		l_dialog.title = "Save project"
		l_dialog.access = FileDialog.ACCESS_FILESYSTEM
		l_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		l_dialog.filters = ["*.gozen"]
		l_dialog.use_native_dialog = true

		if l_dialog.file_selected.connect(save):
			printerr("Couldn't connect file_selected for save dialog!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	_path = a_path

	# TODO: Save the data to an actual file
	OS.set_use_file_access_save_and_swap(true)
	var l_file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	l_file.store_string(var_to_str({
		"files": files
	}))

	l_file.close()
	_unsaved_changes = false
	OS.set_use_file_access_save_and_swap(false)
	

func load(a_path: String) -> void:
	if _unsaved_changes:
		var l_dialog: ConfirmationDialog = ConfirmationDialog.new()

		l_dialog.title = "Save project"
		l_dialog.dialog_text = "Save your project before loading a new project?"
		l_dialog.ok_button_text = "Save"
		l_dialog.cancel_button_text = "Don't save"

		if l_dialog.get_cancel_button().pressed.connect(func() -> void:
				_unsaved_changes = false
				load(a_path)):
			printerr("Couldn't connect cancel button!")
		elif l_dialog.get_ok_button().pressed.connect(func() -> void:
				save()
				load(a_path)):
			printerr("Couldn't connect ok button!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	if a_path == "":
		var l_dialog: FileDialog = FileDialog.new()

		l_dialog.title = "Save project"
		l_dialog.access = FileDialog.ACCESS_FILESYSTEM
		l_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		l_dialog.filters = ["*.gozen"]
		l_dialog.use_native_dialog = true

		if l_dialog.file_selected.connect(load):
			printerr("Couldn't connect file_selected for save dialog!")

		add_child(l_dialog)
		l_dialog.popup_centered()
		return

	_path = a_path

	var l_file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	var l_data: Dictionary = str_to_var(l_file.get_as_text())

	# Reset the data to default variables first!
	_files_data = {}

	# Setting the data to the correct variables
	for l_key: String in l_data.keys():
		match l_key:
			"files": files = l_data[l_key]

	l_file.close()


func add_file(a_file_path: String) -> int:
	var l_id: int = Utils.get_unique_id(files.keys())
	var l_file: File = File.create(a_file_path)

	if l_file == null:
		return -1

	files[l_id] = l_file
	# TODO: Generate data for _files_data

	return l_id

