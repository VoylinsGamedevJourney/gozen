class_name TempFile
extends Resource

# A project specific file, this could be because a picture got copy/pasted,
# or duplicated. Same for text, could be a Text object which got created or
# duplicated

# PATH in File objects should start with "temp://"


var image_data: ImageTexture = null
var color: Color = Color.WHITE
var text_effect: EffectVisual = null


func load_image_from_color() -> void:
	var image: Image = Image.create(Project.data.resolution.x, Project.data.resolution.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image_data = ImageTexture.create_from_image(image)
