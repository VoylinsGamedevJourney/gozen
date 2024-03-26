extends VSplitContainer
# TODO: Have option to select SRT or WebVTT. Have WebVTT disabled but as an option,
# as I'll probably work on SRT subtitles first.


@onready var project_preview_buttons := $HSplitContainer/ProjectViewPanel/VBox/ProjectPreviewButtonsHBox


func _ready() -> void:
	pass 


#region #####################  Playback buttons  ###############################

func _on_to_begin_button_pressed() -> void:
	pass # Replace with function body.


func _on_rewind_button_pressed() -> void:
	pass # Replace with function body.


func _on_play_button_pressed() -> void:
	project_preview_buttons.get_node("PlayButton").visible = false
	project_preview_buttons.get_node("PauseButton").visible = true


func _on_pause_button_pressed() -> void:
	project_preview_buttons.get_node("PlayButton").visible = true
	project_preview_buttons.get_node("PauseButton").visible = false


func _on_forward_button_pressed() -> void:
	pass # Replace with function body.


func _on_to_end_button_pressed() -> void:
	pass # Replace with function body.

#endregion
