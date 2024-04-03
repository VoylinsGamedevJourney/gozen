class_name FileImage extends FileActual


func _init(a_file_name: String = "") -> void:
	type = TYPE.IMAGE
	duration = 120 # TODO: Have a default value for this which can be changed in settings
	# TODO: file_effects = Apply default effects such as transform
	super._init(a_file_name)
