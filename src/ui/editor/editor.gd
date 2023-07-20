extends EditorLayoutInterface

# TODO: Change window title in global to project name - GoZen - VERSION

var current_folder : String = "Main"


func _ready() -> void:
	# TODO: Add Lines to timeline from Project
	print(Globals.project.lines["video"].size())


func _on_project_button_pressed() -> void:
#	TODO: Implement a project settings menu
	pass # Replace with function body.


func _on_settings_button_pressed() -> void:
#	TODO: Implement a settings menu
	pass # Replace with function body.


func _on_add_video_line_button_pressed() -> void:
	Globals.current_project.lines["video"].append([])
	# TODO: Update timeline


func _on_add_audio_line_button_pressed() -> void:
	Globals.current_project.lines["video"].append([])
	# TODO: Update timeline


func _on_add_collor_button_pressed() -> void:
	
	
	pass # Replace with function body.
