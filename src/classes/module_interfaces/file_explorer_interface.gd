class_name FileExplorerModule extends Node
## The File Explorer Interface
##
## Still WIP

signal collect_data(data)

signal _on_open(title) # to give the open command to the actual module

enum MODE { 
	OPEN_FILE, OPEN_FILES, OPEN_DIRECTORY, OPEN_ANY, 
	SELECT_SAVE }

var mode
var extensions: PackedStringArray

func open_explorer(file_mode: MODE, exts: PackedStringArray = []) -> void:
	extensions = exts
	mode = file_mode
	var title: String
	# TODO: Make these localization proof
	match mode:
		MODE.OPEN_FILE: title = "Open file"
		MODE.OPEN_FILES: title = "Open file(s)"
		MODE.OPEN_DIRECTORY: title = "Open directory"
		MODE.OPEN_ANY: title = "Open any"
		MODE.SELECT_SAVE: title = "Select save"
	_on_open.emit(title)


func send_data(data) -> void: collect_data.emit(data)
