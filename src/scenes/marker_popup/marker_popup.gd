extends Control
# TODO: Make the button open a popupmenu through toolbox get_popup()
# When pressing one of the options, color of button should save.


var marker_text: LineEdit
var marker_color: Button



func _ready() -> void:
	# TODO: Save the previously selected marker color and use that one.
	marker_color.modulate = Settings.get_marker_color(0)

	# Fill marker colors
	for color: Color in Settings.get_marker_colors():
		pass


func _on_create_marker_pressed() -> void:
	# If marker text is empty, check if we need to delete marker.

	pass # Replace with function body.


func _on_cancel_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.POPUP.MARKER)

