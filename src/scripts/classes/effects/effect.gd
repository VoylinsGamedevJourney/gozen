class_name Effect extends Resource
## The effect class is what the effect types extend from, Audio and Visual.


func get_effect_name() -> String:
	## Only displayed when adding effects to clips/files.
	return ""


func get_ui(_update_callable: Callable) -> Control:
	## The actual UI to interact with clips/files, use the argument to connect the
	## needed signals for updating the data.
	return null


func get_one_shot() -> bool:
	## This should only be overriden if the effect can only be aplied once.
	return false

