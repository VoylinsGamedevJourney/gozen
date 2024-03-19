extends Window


func _ready() -> void:
	var button := Button.new()
	for layout: String in DirAccess.get_directories_at("res://_layout_modules/"):
		var layout_name: String = layout.trim_prefix("layout_")
		var entry: Button = button.duplicate()
		entry.text = Toolbox.beautify_name(layout)
		entry.pressed.connect(_on_layout_button_pressed.bind(layout_name))
		var layout_data: LayoutModule = load("res://_layout_modules/layout_%s/info.tres" % layout_name)
		if layout_data.single_only:
			if EditorUI.instance.check_single_existing(layout_name):
				entry.disabled = true
				entry.tooltip_text = "This layout it single use only and already active."
		%AddLayoutVBox.add_child(entry)


func _on_layout_button_pressed(layout_name: String) -> void:
	EditorUI.instance.add_layout(layout_name)
	_on_cancel_button_pressed()


func _on_cancel_button_pressed():
	self.queue_free()
