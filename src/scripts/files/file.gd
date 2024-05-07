class_name File


enum {
	FILE_EMPTY = 0,
	# Actual files
	FILE_VIDEO = 1, 
	FILE_AUDIO = 2, 
	FILE_IMAGE = 3,
	# Generated files
	FILE_TEXT = 11, 
	FILE_COLOR = 12, 
	FILE_COLOR_GRADIENT = 13}


var type: int = FILE_EMPTY
var duration: float
var nickname: String
var file_effects: Array


# Move this out of here
#func get_icon() -> Resource:
	#match type:
		#FILE_VIDEO: return preload("res://assets/icons/video_file.png")
		#FILE_AUDIO: return preload("res://assets/icons/audio_file.png")
		#FILE_IMAGE: return preload("res://assets/icons/image_file.png")
		#FILE_TEXT:  return preload("res://assets/icons/text_file.png")
		#FILE_COLOR: return preload("res://assets/icons/color_file.png")
		#FILE_COLOR_GRADIENT: return preload("res://assets/icons/gradient_file.png")
		#_: return null
