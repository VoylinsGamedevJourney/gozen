class_name TextFile extends DefaultFile

var text: String
var font_size: int
var font: String
var pos: Vector2i # position


func get_data() -> Dictionary:
	vars.append("text")
	vars.append("font_size")
	vars.append("font")
	vars.append("pos")
	return super.get_data()
