class_name FileGradient
extends DataManager


var _id: int = -1


func _ready() -> void:
	if Project._on_project_saved.connect(save_data):
		printerr("Couldn't connect to _on_project_saved!")


func save_data() -> void:
	if _id == -1:
		return

	var l_path: String = Project.files[_id].path
	if _save_data(l_path):
		printerr("Couldn't save FileGradient! ", l_path)


static func open(a_id: int) -> FileGradient:
	var l_file_gradient: FileGradient = FileGradient.new()
	var l_path: String = Project.files[a_id].path

	if l_file_gradient._load_data(l_path):
		printerr("Couldn't load data for FileGradient! ", l_path)
		
	return l_file_gradient
