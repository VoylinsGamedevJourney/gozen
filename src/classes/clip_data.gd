class_name ClipData


var id: int = -1
var file_id: int = -1
var track_id: int = -1

var pts: int = 0
var duration: int = 0

var start: int = 0
var end: int = 0



func get_end_pts() -> int:
	return pts + duration - 1


func current_check(a_frame_nr: int) -> bool:
	if a_frame_nr < pts:
		return false
	elif a_frame_nr > get_end_pts():
		return false
	return true
