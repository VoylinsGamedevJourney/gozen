class_name MarkerData
extends Resource


var text: String = ""
var type_id: int = 0


func _to_string() -> String:
	return "<MarkerData-%s: %s>" % [type_id, text]
