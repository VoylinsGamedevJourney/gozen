extends PopupPanel


func _on_save_button_pressed() -> void:
	Project.save_data()
	get_tree().quit()


func _on_no_save_button_pressed() -> void:
	get_tree().quit()


func _on_cancel_button_pressed() -> void:
	self.queue_free()

