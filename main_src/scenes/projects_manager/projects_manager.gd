extends Control

var project_panel_template := preload("res://scenes/projects_scene/elements/project_panel.tscn")

# Data
var projects := []


func _ready() -> void:
	load_projects()


func load_projects() -> void:
	for project_path in SettingsManager.projects:
		var new_project_panel := project_panel_template.duplicate()
		new_project_panel.load_details(project_path)


func _on_new_project_button_pressed() -> void:
	pass # Replace with function body.


func _on_import_project_button_pressed() -> void:
	pass # Replace with function body.


func _on_remove_button_pressed() -> void:
	pass # Replace with function body.


func _on_filter_projects_line_edit_text_changed(text: String) -> void:
	for child in %ProjectsList.get_children():
		child.visible = true if text.length() == 0 else text.to_lower() in child.name.to_lower()


func _on_option_button_item_selected(index: int) -> void:
	pass # Replace with function body.
