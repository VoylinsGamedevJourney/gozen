extends Node
# The future goal of CoreError is to be able to print error messages which have
# to do with GoZen specifically and to handle them. If an error occurs but it's
# not anything breaking, that we can tell the rest of the code what should be
# done. This is a future to-do!



func err_connect(a_errors: PackedInt64Array, a_string: String) -> void:
	if _add_errors(a_errors):
		printerr(a_string)


func err_resize(a_errors: PackedInt64Array, a_string: String) -> void:
	if _add_errors(a_errors):
		printerr(a_string)
	

func _add_errors(a_errors: PackedInt64Array) -> bool:
	for a_error: int in a_errors:
		if a_error != 0:
			return true

	return false

