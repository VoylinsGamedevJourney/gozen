class_name Print
## Static class for default print statements.



static func header(text: String, color: String = "white") -> void:
	print_rich("[color=%s][b]" % color, text)


static func info(title: String, context: Variant, color: String = "white") -> void:
	print_rich("[color=%s][b]" % color, title, "[/b]: [color=gray]", context)

	
static func resize_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't resize array!")
	printerr(get_stack())


static func append_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't append to array!")
	printerr(get_stack())


static func insert_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't insert to array!")
	printerr(get_stack())
	

static func erase_error() -> void:
	# This func is needed so we don't have the same error message everywhere.
	printerr("Couldn't erase entry!")
	printerr(get_stack())

