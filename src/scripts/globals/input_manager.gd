extends Node

signal on_show_editor_screen
signal on_show_render_screen
signal on_show_subtitle_screen
signal on_switch_screen


var undo_redo: UndoRedo = UndoRedo.new()



func _ready() -> void:
	undo_redo.max_steps = 200


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		get_tree().root.add_child(preload(Library.SCENE_ABOUT_GOZEN).instantiate())

	# EVERYTHING which is only allowed to open after the start screen goes below!
	if Project.data == null:
		return

	if event.is_action_pressed("save_project", false, true):
		Project.save()
	if event.is_action_pressed("save_project_as", false, true):
		Project.save_as()
	if event.is_action_pressed("open_project", false, true):
		Project.open_project()

	if event.is_action_pressed("ui_undo", false, true) and undo_redo.has_undo():
		if !undo_redo.undo():
			printerr("Couldn't undo!")
	if event.is_action_pressed("ui_redo", false, true) and undo_redo.has_redo():
		if !undo_redo.redo():
			printerr("Couldn't redo!")

	if event.is_action_pressed("timeline_play_pause", false, true):
		EditorCore.on_play_pressed()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("breakpoint", true):
		breakpoint

	if get_window().gui_get_focus_owner() is not LineEdit and event.is_action_pressed("open_command_bar"):
		get_tree().root.add_child(preload(Library.SCENE_COMMAND_BAR).instantiate())
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("switch_screen"):
		if RenderManager.encoder == null or !RenderManager.encoder.is_open():
			switch_screen()

	if event.is_action_pressed("ui_paste"):
		clipboard_paste()


func _on_closing_editor() -> void:
	undo_redo.free()


func show_editor_screen() -> void:
	on_show_editor_screen.emit()


func show_render_screen() -> void:
	on_show_render_screen.emit()


func show_subtitle_screen() -> void:
	on_show_subtitle_screen.emit()


func switch_screen() -> void:
	on_switch_screen.emit()


func clipboard_paste() -> void:
	var image: Image = DisplayServer.clipboard_get_image()

	if Project.data == null:
		return

	# The pasted data is an image/screenshot.
	if image != null:
		var file: File = File.create("temp://image")

		file.nickname = "Image %s" % file.id
		file.temp_file = TempFile.new()
		file.temp_file.image_data = ImageTexture.create_from_image(image)

		Project.add_file_object(file)
		return

	# Checking if the pasted data is a path.
	var data: PackedStringArray = DisplayServer.clipboard_get().split('\n')

	for path: String in data:
		if !FileAccess.file_exists(path):
			return

	# All paths pasted are files so we use _on_files_dropped.
	Project._on_files_dropped(data)

