class_name File
## File
##
## Base class for all actual files (video, audio, image) and generated
## files (text, color, ...).

enum TYPE { 
	ERROR = 0,
	# Actual files
	VIDEO = 1, 
	AUDIO = 2, 
	IMAGE = 3,
	# Generated files
	TEXT = 11, 
	COLOR = 12, 
	COLOR_GRADIENT_1D = 13, 
	COLOR_GRADIENT_2D = 14 }


const ICONS: Dictionary = {
	TYPE.VIDEO: preload("res://assets/icons/video_file.png"),
	TYPE.AUDIO: preload("res://assets/icons/audio_file.png"),
	TYPE.IMAGE: preload("res://assets/icons/image_file.png"),
	TYPE.TEXT: preload("res://assets/icons/text_file.png"),
	TYPE.COLOR: preload("res://assets/icons/color_file.png"),
	TYPE.COLOR_GRADIENT_1D: preload("res://assets/icons/gradient_file.png"),
	TYPE.COLOR_GRADIENT_2D: preload("res://assets/icons/gradient_file.png")}

const SUPPORTED_FORMATS: Dictionary = {
	TYPE.VIDEO: ["mp4", "mov", "avi", "mkv", "webm", "flv", "mpeg", "mpg", "wmv", "asf", "vob", "ts", "m2ts", "mts", "3gp", "3g2"],
	TYPE.IMAGE: ["png", "jpg", "svg", "webp", "bmp", "tga", "dds", "hdr", "exr"],
	TYPE.AUDIO: ["ogg", "wav", "mp3"]}


var type: TYPE
var duration: int
var nickname: String
var file_effects: Array


func get_icon() -> Resource:
	return ICONS[type]
