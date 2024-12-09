class_name FileText
extends DataManager



var id: int = -1



static func open(a_id: int) -> FileText:
	var l_file_text: FileText = FileText.new()

	l_file_text._load_data_err(
			CoreMedia.files[a_id].path, "Couldn't load data for FileText!")
		
	return l_file_text


func _ready() -> void:
	Project._on_project_saved.connect(save_data)


func save_data() -> void:
	if id != -1:
		_save_data_err(CoreMedia.files[id].path, "Couldn't save FileText!")
	
