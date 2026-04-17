class_name TrackData
extends Resource


var is_muted: bool = false
var is_visible: bool = true
var is_locked: bool = false



#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = {}
	if is_muted:
		data["is_muted"] = true
	if !is_visible:
		data["is_visible"] = false
	if is_locked:
		data["is_locked"] = true
	return data


func deserialize(dict: Dictionary) -> void:
	is_muted = dict.get("is_muted", false)
	is_visible = dict.get("is_visible", true)
	is_locked = dict.get("is_locked", false)
