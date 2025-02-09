class_name Effect extends Resource
## The effect class is what the effect types extend from, Audio and Visual.

var file_id: int = -1
var clip_id: int = -1



func _init(a_id: int, a_clip: bool) -> void:
	if a_clip:
		clip_id = a_id
	else:
		file_id = a_id


func get_effect_name() -> String:
	## Only displayed when adding effects to clips/files.
	return ""


func get_ui() -> Control:
	## Get the actual UI to interact with clips/files effects.
	return null


func get_one_shot() -> bool:
	## This should only be overriden if the effect can only be aplied once.
	return false

