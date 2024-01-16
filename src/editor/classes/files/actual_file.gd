class_name ActualFile extends DefaultFile


var file_path: String


func get_data() -> Dictionary:
	vars.append("file_path")
	return super.get_data()
