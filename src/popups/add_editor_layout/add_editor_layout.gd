extends Window


func _ready() -> void:
	var button := Button.new()
	for layout: String in DirAccess.get_directories_at("res://_layouts/"):
		var layout_data: LayoutModule = load("res://_layouts/%s/info.tres" % layout)
		var layout_name: String = layout.trim_prefix("layout_")
		var entry: Button = button.duplicate()
		entry.text = layout_data.layout_name
		entry.tooltip_text = layout_data.layout_description
		entry.pressed.connect(_on_layout_button_pressed.bind(layout_name))
		if layout_data.single_only and EditorUI.instance.check_single_existing(layout_name):
			entry.disabled = true
			entry.tooltip_text = "This layout it single use only and already active."
		%AddLayoutVBox.add_child(entry)


func _on_layout_button_pressed(layout_name: String) -> void:
	EditorUI.instance.add_layout(layout_name)
	_on_cancel_button_pressed()


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.ADD_EDITOR_LAYOUT)
