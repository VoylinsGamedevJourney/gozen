class_name MarkerData
extends Resource

var frame_nr: int
var text: String
var type: int



#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = { "frame_nr": frame_nr, "text": text }
	if type != 0:
		data["type"] = type
	return data


func deserialize(dict: Dictionary) -> void:
	frame_nr = dict.get("frame_nr", 0)
	text = dict.get("text", "")
	type = dict.get("type", 0)
