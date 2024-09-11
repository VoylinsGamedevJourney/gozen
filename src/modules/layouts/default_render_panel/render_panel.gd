extends Control



@export var simple_settings_vbox: VBoxContainer
@export var advanced_settings_vbox: VBoxContainer



func _ready() -> void:
	_on_advanced_settings_check_button_toggled(false)


func _on_advanced_settings_check_button_toggled(a_toggle: bool) -> void:
	advanced_settings_vbox.visible = a_toggle
	simple_settings_vbox.visible = !a_toggle


func _on_render_button_pressed() -> void:
	# TODO: Take in mind the advanced settings toggle for getting the render settings
	# TODO: Open a popup to make it impossible to click on anything in the main UI whilst rendering
	# give a cancel render button and display a timeline of how far the rendering process is.
	pass # Replace with function body.

