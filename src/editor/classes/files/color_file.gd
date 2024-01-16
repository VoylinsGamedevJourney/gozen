class_name ColorFile extends DefaultFile

var color: Color
var size: int


func get_data() -> Dictionary:
	vars.append("color")
	vars.append("size")
	return super.get_data()
