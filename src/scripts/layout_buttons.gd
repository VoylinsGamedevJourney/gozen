class_name ShortcutButtons extends PanelContainer


var instance: ShortcutButtons
var layout_shortcuts: Array[ShortcutButtonArray]



func _ready() -> void:
	instance = self


func set_shortcut_buttons(a_layout_id: int, a_array: ShortcutButtonArray) -> void:
	if layout_shortcuts.size() < a_layout_id + 1:
		@warning_ignore("return_value_discarded")
		layout_shortcuts.resize(a_layout_id + 1)

	layout_shortcuts[a_layout_id] = a_array


func load_layout_shortcuts(a_layout_id: int) -> void:
	for l_button: TextureButton in get_child(0).get_children():
		l_button.queue_free()

	for l_shortcut_button: ShortcutButton in layout_shortcuts[a_layout_id]:
		var l_button: TextureButton = TextureButton.new()

		l_button.ignore_texture_size = true
		l_button.custom_minimum_size = Vector2(16, 16)
		l_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		@warning_ignore("return_value_discarded")
		l_button.pressed.connect(l_shortcut_button.function)
		l_button.texture_normal = l_shortcut_button.icon

		get_child(0).add_child(l_button)


class ShortcutButton:
	var icon: Texture2D
	var function: Callable


class ShortcutButtonArray:
	var arr: Array[ShortcutButton] = []

