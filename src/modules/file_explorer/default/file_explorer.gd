extends FileExplorer
## File Explorer
##
## The settings config section is 'file_explorer',
## it has a key called 'last_dir'


var dir: DirAccess
var button_template := preload("res://modules/file_explorer/default/TemplateButton.tscn")


func create(_title: String, _mode: MODE, _filter: Array = []):
	title = title
	mode = _mode
	filter = _filter
	
	change_path(SettingsManager.data.get_value("file_explorer", "last_dir", ""))
	self.visible = false


func open() -> void:
	self.visible = true


func change_path(new_path: String) -> void:
	if new_path == "":
		new_path = ProjectSettings.globalize_path("res://")
	elif !dir.dir_exists(new_path):
		%PathLineEdit.text = dir.get_current_dir()
		return
	%PathLineEdit.text = new_path
	dir = DirAccess.open(new_path)
	update_explorer_view()


func update_explorer_view() -> void:
	# TODO: Take in mind "filter"
	# TODO: Display folders first, than files.
	# TODO: Add temporary folder, image, video, audio, unknown icon to files.
	# TODO: Make icon for GoZen File types
	for node in %FilesHFlow.get_children():
		node.queue_free()
	for directory in dir.get_directories():
		var new_button: Button = button_template.duplicate().instantiate()
		new_button.set_data(directory, dir.get_current_dir())
		%FilesHFlow.add_child(new_button)
	for file in dir.get_files():
		var new_button: Button = button_template.duplicate().instantiate()
		new_button.set_data(file, dir.get_current_dir())
		%FilesHFlow.add_child(new_button)



#var mode: ModuleManager.FE_MODES
#var filters : Array # extensions
#
#
#func open(_mode: ModuleManager.FE_MODES, title: String, extensions: Array) -> void:
#	mode = _mode
#	filters = extensions
#	find_child("TitleLabel").text = title
#
#
#
##	$FileDialog.filters = extensions
##	$FileDialog.popup_centered(Vector2i(500,500))
##
##	$FileDialog.file_selected.connect(send_data)
##	$FileDialog.files_selected.connect(send_data)
##	$FileDialog.dir_selected.connect(send_data)
#
#
#
#
#func _on_entry_pressed(folder: bool) -> void:
#	# if folder and double pressed, open folder
#	pass
#
#
#func _on_ok_pressed() -> void:
#	# TODO: Send data as array, even when file
#	pass


## NAV BAR BUTTONS  ###########################################

func _on_home_button_pressed() -> void:
	pass # Replace with function body.


func _on_documents_button_pressed() -> void:
	pass # Replace with function body.


func _on_pictures_button_pressed() -> void:
	pass # Replace with function body.


func _on_music_button_pressed() -> void:
	pass # Replace with function body.


func _on_videos_button_pressed() -> void:
	pass # Replace with function body.


## NAVIGATION BUTTONS  ########################################

func _on_previous_folder_button_pressed() -> void:
	pass # Replace with function body.


func _on_next_folder_button_pressed() -> void:
	pass # Replace with function body.


func _on_folder_on_top_button_pressed() -> void:
	pass # Replace with function body.


func _on_create_folder_button_pressed() -> void:
	# TODO: Localization support
	var dir_name := "New folder"
	var num := 1
	if !dir.dir_exists(dir_name):
		dir.make_dir(dir_name)
		return
	while dir.dir_exists(dir_name + str(num)):
		num += 1
	dir.make_dir(dir_name + str(num))


func _on_ok_button_pressed() -> void:
	# TODO: Send data to signal
	SettingsManager.data.set_value("file_explorer", "last_dir", dir.get_current_dir())
	SettingsManager.data.save(SettingsManager.PATH)
	cancel_pressed()


func _on_cancel_button_pressed() -> void:
	cancel_pressed()


func _on_path_line_edit_text_submitted(new_path: String) -> void:
	change_path(new_path)
