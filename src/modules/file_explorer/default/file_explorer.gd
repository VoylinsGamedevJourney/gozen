extends FileExplorer
# TODO: Resizing of icon support

const PATH_LAST_DIR := "user://explorer_last_dir"

var dir: DirAccess


func create(_title: String, _mode: MODE, _filter: Array = []):
	title = title
	mode = _mode
	filter = _filter
	# TODO: Set dir location to last saved folder
	dir.open(str_to_var(FileManager.load_data(PATH_LAST_DIR)))
	self.visible = false


func open() -> void:
	self.visible = true

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
#func _on_cancel_pressed() -> void:
#	ModuleManager._on_file_explorer_cancel
#	queue_free()
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


func _on_close_button_pressed() -> void:
	FileManager.save_data(dir.get_current_dir(), PATH_LAST_DIR)
	cancel_pressed()
