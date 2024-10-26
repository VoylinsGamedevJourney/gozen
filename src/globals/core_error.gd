extends Node
# The future goal of CoreError is to be able to print error messages which have
# to do with GoZen specifically and to handle them. If an error occurs but it's
# not anything breaking, that we can tell the rest of the code what should be
# done. This is a future to-do!

const DEFAULT_ERR_CONNECT: String = "Something went wrong connecting signal(s)!"
const DEFAULT_ERR_APPEND: String = "Something went wrong appending to array(s)!"
const DEFAULT_ERR_RESIZE: String = "Something went wrong resizing array(s)!"
const DEFAULT_ERR_ERASE: String = "Something went wrong erasing from array(s)!"



func err_connect(a_errors: PackedInt64Array, a_string: String = DEFAULT_ERR_CONNECT) -> void:
	if _add_errors(a_errors):
		printerr(a_string)


func err_append(a_errors: PackedInt64Array, a_string: String = DEFAULT_ERR_APPEND) -> void:
	if _add_errors(a_errors):
		printerr(a_string)

	
func err_resize(a_errors: PackedInt64Array, a_string: String = DEFAULT_ERR_RESIZE) -> void:
	if _add_errors(a_errors):
		printerr(a_string)
	

func err_erase(a_errors: PackedInt64Array, a_string: String = DEFAULT_ERR_ERASE) -> void:
	if _add_errors(a_errors):
		printerr(a_string)
	

func _add_errors(a_errors: PackedInt64Array) -> bool:
	for a_error: int in a_errors:
		if a_error != 0:
			return true

	return false

