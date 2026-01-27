extends Node

signal on_show_editor_screen
signal on_show_render_screen
signal on_switch_screen

signal switch_timeline_mode_select
signal switch_timeline_mode_cut


var undo_redo: UndoRedo = UndoRedo.new()



func _ready() -> void:
	undo_redo.max_steps = 200


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		PopupManager.open_popup(PopupManager.POPUP.CREDITS)

	if !Project.loaded: return # EVERYTHING which is only allowed to open after the start screen goes below!

	# Check if in line edit or not:
	if _strict_input_check(event):
		return get_viewport().set_input_as_handled()

	if event.is_action_pressed("save_project", false, true):
		Project.save()
	elif event.is_action_pressed("save_project_as", false, true):
		Project.save_as()
	elif event.is_action_pressed("open_project", false, true):
		Project.open_project()

	if event.is_action_pressed("breakpoint", true): breakpoint
	elif event.is_action_pressed("ui_paste"):
		clipboard_paste()
	elif event.is_action_pressed("ui_undo", false, true) and undo_redo.has_undo():
		if !undo_redo.undo(): printerr("InputManager: Couldn't undo!")
	elif event.is_action_pressed("ui_redo", false, true) and undo_redo.has_redo():
		if !undo_redo.redo(): printerr("InputManager: Couldn't redo!")
	elif event.is_action_pressed("switch_screen"):
		if RenderManager.encoder == null and !RenderManager.encoder.is_open():
			switch_screen()


func _strict_input_check(event: InputEvent) -> bool:
	if get_viewport().gui_get_focus_owner() is LineEdit: return false
	elif event.is_action_pressed("open_marker_popup"):
		open_marker_popup()
	elif event.is_action_pressed("timeline_play_pause", false, true):
		EditorCore.on_play_pressed()
		return true
	elif event.is_action_pressed("timeline_mode_select", false, true):
		switch_timeline_mode_select.emit()
	elif event.is_action_pressed("timeline_mode_cut", false, true):
		switch_timeline_mode_cut.emit()
	elif event.is_action_pressed("open_command_bar"):
		PopupManager.open_popup(PopupManager.POPUP.COMMAND_BAR)
		return true
	return false


func _on_closing_editor() -> void:
	undo_redo.free()


func show_editor_screen() -> void:
	on_show_editor_screen.emit()


func show_render_screen() -> void:
	on_show_render_screen.emit()


func switch_screen() -> void:
	on_switch_screen.emit()


func open_marker_popup() -> void:
	PopupManager.open_popup(PopupManager.POPUP.MARKER)


func clipboard_paste() -> void:
	if Project.is_loaded() == null: return

	var image: Image = DisplayServer.clipboard_get_image()
	var data: PackedStringArray

	# The pasted data is an image/screenshot.
	if image != null:
		var file: File = FileHandler.create("temp://image")

		file.nickname = "Image %s" % file.id
		file.temp_file = TempFile.new()
		file.temp_file.image_data = ImageTexture.create_from_image(image)

		FileHandler.add_file_object(file)
		return

	# Checking if the pasted data is a path.
	data = DisplayServer.clipboard_get().split('\n')

	for path: String in data:
		if !FileAccess.file_exists(path): return

	# All paths pasted are files so we use _on_files_dropped.
	FileHandler.files_dropped(data)
