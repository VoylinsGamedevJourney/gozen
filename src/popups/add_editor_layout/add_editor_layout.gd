extends Window


func _ready() -> void:
	for l_layout: String in DirAccess.get_directories_at("res://_layouts/"):
		var l_layout_data: LayoutModule = load("res://_layouts/%s/info.tres" % l_layout)
		var l_layout_name: String = l_layout.trim_prefix("layout_")
		var l_button: Button = Button.new()
		l_button.text = l_layout_data.layout_name
		l_button.tooltip_text = l_layout_data.layout_description
		Printer.connect_error(l_button.pressed.connect(_on_layout_button_pressed.bind(l_layout_name)))
		if l_layout_data.single_only and EditorUI.instance.check_single_existing(l_layout_name):
			l_button.disabled = true
			l_button.tooltip_text = "This layout it single use only and already active."
		%AddLayoutVBox.add_child(l_button)


func _on_layout_button_pressed(a_layout_name: String) -> void:
	EditorUI.instance.add_layout(a_layout_name)
	_on_cancel_button_pressed()


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.ADD_EDITOR_LAYOUT)
