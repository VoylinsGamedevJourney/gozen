class_name FileAudio extends FileActual


func _init(a_file_name: String = "") -> void:
	type = TYPE.AUDIO
	#TODO duration = audio file duration
	super._init(a_file_name)
