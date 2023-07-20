extends PanelContainer

func _ready() -> void:
	load_files_panel()


func load_files_panel() -> void:
	for folder in Globals.project.folders:
		var new_button := preload("res://modules/editor/default/folder_button.tscn").instantiate()
		new_button.text = folder
		new_button.connect("pressed", open_folder.bind(folder))
		%FoldersVBox.add_child(new_button)
	open_folder("Main")


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
	# TODO: Open File Explorer
	# TODO: Add file to the project document
	# TODO: Update %FolderFiles
	pass # Replace with function body.
