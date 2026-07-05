class_name TempFile
extends Resource

# A project specific file, this could be because a picture got copy/pasted,
# or duplicated. Same for text, could be a Text object which got created or
# duplicated

# PATH in File objects should start with "temp://"


@export var image_data: ImageTexture = null
@export var color: Color = Color.WHITE
@export var text_effect: EffectVisual = null



func load_image_from_color() -> void:
	var image: Image = Image.create(Project.data.resolution.x, Project.data.resolution.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image_data = ImageTexture.create_from_image(image)



#--- Data handling ---

func serialize() -> Dictionary:
	var data: Dictionary = { "color": color.to_html() }
	if text_effect:
		data["text_effect"] = text_effect.serialize()
	if image_data:
		data["image_png"] = image_data.get_image().save_png_to_buffer()
	return data


func deserialize(data: Dictionary) -> void:
	var color_value: Variant = data.get("color", Color.WHITE)
	if typeof(color_value) == TYPE_STRING:
		color = Color(color_value as String)
	else:
		color = color_value

	if data.has("text_effect"):
		var text_effect_value: Variant = data["text_effect"]
		if text_effect_value is EffectVisual:
			text_effect = text_effect_value
		else:
			text_effect = (load(Library.EFFECT_TEXT) as EffectVisual).deep_copy()
			text_effect.deserialize(text_effect_value as Dictionary)

	if data.has("image_png"):
		var image: Image = Image.new()
		@warning_ignore("RETURN_VALUE_DISCARDED")
		image.load_png_from_buffer(data["image_png"] as PackedByteArray)
		image_data = ImageTexture.create_from_image(image)
