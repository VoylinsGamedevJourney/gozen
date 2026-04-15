class_name MarkerData
extends Resource

var frame_nr: int
var text: String
var type: int



#--- Data handling ---

func serialize() -> Dictionary:
	return { "frame_nr": frame_nr, "text": text, "type": type }


func deserialize(dict: Dictionary) -> void:
	frame_nr = dict.get("frame_nr", 0)
	text = dict.get("text", "")
	type = dict.get("type", 0)
