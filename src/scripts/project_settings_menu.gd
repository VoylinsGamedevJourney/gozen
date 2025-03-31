extends PanelContainer


var changes: Dictionary[String, Callable] = {}



func _on_save_button_pressed() -> void:
	for change: Callable in changes.values():
		change.call()

	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()
