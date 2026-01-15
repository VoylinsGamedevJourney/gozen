extends PanelContainer


var current_clip_id: int = -1



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_popup(PopupManager.POPUP.ADD_EFFECTS)


func load_effects(is_visual: bool, clip_id: int) -> void:
	current_clip_id = clip_id
	print(is_visual)


func _on_close_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.ADD_EFFECTS)

