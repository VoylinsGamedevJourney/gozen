class_name TrackData
extends Resource


var id: int = -1
var clips: Dictionary[int, int] = {} # { frame_nr: clip_id }



func _to_string() -> String:
	return "<track:%s>" % id

