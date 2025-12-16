class_name TempFile
extends RefCounted

# A project specific file, this could be because a picture got copy/pasted,
# or duplicated. Same for text, could be a Text object which got created or
# duplicated

# PATH in File objects should start with "temp://"

var image_data: ImageTexture = null

var color: Color = Color.WHITE

var text_data: String = ""
var font_size: float = 12.0
var font: String = ""



func load_image_from_color() -> void:
	var image: Image = Image.create(854, 480, false, Image.FORMAT_RGB8)

	image.fill(color)
	image_data = ImageTexture.create_from_image(image)

