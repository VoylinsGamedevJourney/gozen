extends Button


var file_path


func set_data(title: String, path: String) -> void:
	file_path = path
	$VBox/Label.text = title
	var image := Image.new()
	if !title.contains('.'): # Folder
		image = Image.load_from_file("res://assets/icons_file_explorer/IconFolder.png")
	else: # Not a folder but a file
		var extension := title.split('.')[-1].to_lower()
		if extension in File.EXT_AUDIO: # Audio
			image = Image.load_from_file("res://assets/icons_file_explorer/IconFileAudio.png")
		elif extension in File.EXT_VIDEO: # Video
			image = Image.load_from_file("res://assets/icons_file_explorer/IconFileVideo.png")
		elif extension in File.EXT_IMAGES: # Image
			image = Image.load_from_file("res://assets/icons_file_explorer/IconFileImage.png")
		else: # Unknown
			image = Image.load_from_file("res://assets/icons_file_explorer/IconFileUnknown.png")
	$VBox/Texture.texture = ImageTexture.create_from_image(image)

