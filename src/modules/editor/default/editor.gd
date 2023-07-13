extends EditorLayoutInterface

var current_folder : String = "Main"


func _ready() -> void:
	# TODO: Add folder to FolderVBox from Project
	for folder in Globals.current_project.folders:
		var new_button := preload("res://modules/editor/default/folder_button.tscn").instantiate()
		new_button.text = folder
		new_button.connect("pressed", open_folder.bind(folder))
		%FoldersVBox.add_child(new_button)
	open_folder("Main")


func _on_project_button_pressed() -> void:
#	TODO: Implement a project settings menu
	pass # Replace with function body.


func _on_settings_button_pressed() -> void:
#	TODO: Implement a settings menu
	pass # Replace with function body.


func _on_new_folder_button_pressed() -> void:
	var folder_name := "Folder%s" % %FoldersVBox.get_child_count()
	var new_button := preload("res://modules/editor/default/folder_button.tscn").instantiate()
	new_button.text = folder_name
	new_button.connect("pressed", open_folder.bind(folder_name))
	%FoldersVBox.add_child(new_button)


func open_folder(folder_name) -> void:
	current_folder = folder_name
	# TODO: Load files from that folder in %FolderFiles


func _on_add_file_button_pressed() -> void:
	# TODO: Add file to thje project document
	# TODO: Update %FolderFiles
	pass # Replace with function body.


func _on_add_video_line_button_pressed() -> void:
	pass # Replace with function body.


func _on_add_audio_line_button_pressed() -> void:
	pass # Replace with function body.
