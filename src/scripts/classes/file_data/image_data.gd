class_name ImageData
extends FileData


var image: ImageTexture = null



func _update_duration() -> void:
	get_file().duration = Settings.get_image_duration()

