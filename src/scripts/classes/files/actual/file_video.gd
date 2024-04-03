class_name FileVideo extends FileActual


func _init(a_file_name: String = "") -> void:
	type = TYPE.VIDEO
	# TODO: duration = video file duration
	# TODO: file_effects = Apply default effects such as transform and volume
	super._init(a_file_name)
