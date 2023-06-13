class_name FileExplorerInterface
extends Control

## File Explorer Interface
##
## test

signal on_dir_selected(dir)
signal on_file_selected(path)
signal on_files_selected(paths)


enum FILE_MODE {
	SELECT_FILE = FileDialog.FileMode.FILE_MODE_OPEN_FILE,
	SELECT_FILES = FileDialog.FileMode.FILE_MODE_OPEN_FILES,
	SELECT_FOLDER = FileDialog.FileMode.FILE_MODE_OPEN_DIR
}


var file_explorer_title := "Open file"
var file_mode: FILE_MODE = FILE_MODE.SELECT_FILE
var file_filters: PackedStringArray = []


func _ready() -> void:
	close_file_explorer()


func open_file_explorer() -> void:
	self.visible = true


func close_file_explorer() -> void:
	self.visible = false
	file_filters = []


# Returns an array of the given path with all files and folders.
# The array content is [type, name]
func get_folder_content() -> Array:
	return []


func connect_to_signal(_signal: Signal, function: Callable) -> void:
	var signal_name: StringName = _signal.get_name()
	for x in get_signal_connection_list(signal_name):
		self.disconnect(signal_name, x.callable)
	self.connect(signal_name, function)
