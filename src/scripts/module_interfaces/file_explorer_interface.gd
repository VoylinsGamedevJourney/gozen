class_name FileExplorerInterface
extends Control

## File Explorer Interface
##
## This is the interface which has to be used when
## creating your own file explorer interface. By using
## this interface we maintain compatibility with the
## core editor and other modules.


signal on_dir_selected(dir)
signal on_file_selected(path)
signal on_files_selected(paths)


enum FILE_MODE {
	SELECT_FILE = FileDialog.FileMode.FILE_MODE_OPEN_FILE,
	SELECT_FILES = FileDialog.FileMode.FILE_MODE_OPEN_FILES,
	SELECT_FOLDER = FileDialog.FileMode.FILE_MODE_OPEN_DIR
}


var title : String
var mode: FILE_MODE = FILE_MODE.SELECT_FILE
var filters: PackedStringArray = []


func open_file_explorer() -> void:
	self.visible = true


# Returns an array of the given path with all files and folders.
# The array content is [type, name]
func get_folder_content() -> Array:
	return []


func connect_to_signal(_signal: Signal, function: Callable) -> void:
	var signal_name: StringName = _signal.get_name()
	for x in get_signal_connection_list(signal_name):
		self.disconnect(signal_name, x.callable)
	self.connect(signal_name, function)
