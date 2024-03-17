class_name File extends Node
## File
##
## Base class for all actual files (video, audio, image) and generated
## files (text, color, ...).

enum TYPE { 
	VIDEO, AUDIO, IMAGE, # Actual files
	TEXT, COLOR, COLOR_GRADIENT_1D, COLOR_GRADIENT_2D, SHADER # Generated
}

const icon := {
	TYPE.VIDEO: preload("res://assets/icons/video_file.png"),
	TYPE.AUDIO: preload("res://assets/icons/audio_file.png"),
	TYPE.IMAGE: preload("res://assets/icons/image_file.png"),
	TYPE.TEXT: preload("res://assets/icons/text_file.png"),
	TYPE.COLOR: preload("res://assets/icons/color_file.png"),
	TYPE.COLOR_GRADIENT_1D: preload("res://assets/icons/gradient_file.png"),
	TYPE.COLOR_GRADIENT_2D: preload("res://assets/icons/gradient_file.png"),
	TYPE.SHADER: preload("res://assets/icons/shader.png")}


var type: TYPE
var duration: int
var nickname: String
var file_effects: Array
var effects: Array
