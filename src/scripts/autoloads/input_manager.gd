extends Node
# TODO: Maybe add a duplicate shortcut which adds a duplicate of the clip right
# behind it (if space is available)

signal on_show_editor_screen
signal on_show_render_screen
signal on_switch_screen


var undo_redo: UndoRedo = UndoRedo.new()



func _ready() -> void:
	undo_redo.max_steps = 200


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		PopupManager.open_popup(PopupManager.POPUP.CREDITS)
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_popups()

	# EVERYTHING which is only allowed to open after the start screen goes below!
	if !Project.loaded:
		return

	if event.is_action_pressed("save_project", false, true):
		Project.save()
	if event.is_action_pressed("save_project_as", false, true):
		Project.save_as()
	if event.is_action_pressed("open_project", false, true):
		Project.open_project()

	if event.is_action_pressed("ui_undo", false, true) and undo_redo.has_undo():
		if !undo_redo.undo():
			printerr("InputManager: Couldn't undo!")
	if event.is_action_pressed("ui_redo", false, true) and undo_redo.has_redo():
		if !undo_redo.redo():
			printerr("InputManager: Couldn't redo!")

	if event.is_action_pressed("timeline_play_pause", false, true):
		if get_viewport().gui_get_focus_owner() is not LineEdit:
			EditorCore.on_play_pressed()
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("breakpoint", true):
		breakpoint

	if get_window().gui_get_focus_owner() is not LineEdit and event.is_action_pressed("open_command_bar"):
		PopupManager.open_popup(PopupManager.POPUP.COMMAND_BAR)
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("switch_screen"):
		if RenderManager.encoder == null or !RenderManager.encoder.is_open():
			switch_screen()

	if event.is_action_pressed("ui_paste"):
		clipboard_paste()

	if event.is_action_pressed("open_marker_popup"):
		open_marker_popup()


func _on_closing_editor() -> void:
	undo_redo.free()


func show_editor_screen() -> void:
	on_show_editor_screen.emit()


func show_render_screen() -> void:
	on_show_render_screen.emit()


func switch_screen() -> void:
	on_switch_screen.emit()


func clipboard_paste() -> void:
	var image: Image = DisplayServer.clipboard_get_image()

	if Project.is_loaded() == null:
		return

	# The pasted data is an image/screenshot.
	if image != null:
		var file: File = FileHandler.create("temp://image")

		file.nickname = "Image %s" % file.id
		file.temp_file = TempFile.new()
		file.temp_file.image_data = ImageTexture.create_from_image(image)

		FileHandler.add_file_object(file)
		return

	# Checking if the pasted data is a path.
	var data: PackedStringArray = DisplayServer.clipboard_get().split('\n')

	for path: String in data:
		if !FileAccess.file_exists(path):
			return

	# All paths pasted are files so we use _on_files_dropped.
	FileHandler.files_dropped(data)


func open_marker_popup() -> void:
	PopupManager.open_popup(PopupManager.POPUP.MARKER)
