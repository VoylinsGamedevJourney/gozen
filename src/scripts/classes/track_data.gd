class_name TrackData
extends Resource


var is_muted: bool = false
var is_visible: bool = true
var is_locked: bool = false



#--- Data handling ---

func serialize() -> Dictionary:
	return { "is_muted": is_muted, "is_visible": is_visible, "is_locked": is_locked }


func deserialize(dict: Dictionary) -> void:
	is_muted = dict.get("is_muted", false)
	is_visible = dict.get("is_visible", true)
	is_locked = dict.get("is_locked", false)
