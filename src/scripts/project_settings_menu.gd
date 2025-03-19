extends PanelContainer


var changes: Dictionary[String, Callable] = {}



func _on_save_button_pressed() -> void:
	for l_change: Callable in changes.values():
		l_change.call()

	self.queue_free()


func _on_cancel_button_pressed() -> void:
	self.queue_free()
