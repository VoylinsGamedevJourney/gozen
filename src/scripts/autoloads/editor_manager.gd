extends Node

var editor_data : EditorData


func _ready() -> void: load_data()


func save_data() -> void:
	var file := FileAccess.open(Const.editor_data_path, FileAccess.WRITE)


func load_data() -> void:
	# Check if data file already exists
	if !FileAccess.file_exists(Const.editor_data_path):
		save_data()
	
	var file := FileAccess.open(Const.editor_data_path, FileAccess.READ)
	editor_data = DataHandler.set_class_data(EditorData.new(), file.get_var())
	file.close()
	
	# TODO: Load global files
	pass
