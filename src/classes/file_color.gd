class_name FileColor
extends DataManager



var id: int = -1



static func open(a_id: int) -> FileColor:
	var l_file_color: FileColor = FileColor.new()

	l_file_color._load_data_err(
			CoreMedia.files[a_id].path, "Couldn't load data for FileColor!")
		
	return l_file_color


func _ready() -> void:
	Project._on_project_saved.connect(save_data)


func save_data() -> void:
	if id != -1:
		_save_data_err(CoreMedia.files[id].path, "Couldn't save FileColor! ")

