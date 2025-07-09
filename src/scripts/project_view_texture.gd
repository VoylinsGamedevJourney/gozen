extends TextureRect


func _ready() -> void:
	if EditorCore.viewport != null:
		texture = EditorCore.viewport.get_texture()
	else:
		printerr("Couldn't get viewport texture from EditorCore!")

