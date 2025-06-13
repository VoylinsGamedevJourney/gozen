extends Node


var undo_redo: UndoRedo = UndoRedo.new()



func _ready() -> void:
	undo_redo.max_steps = 200


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		get_tree().root.add_child(preload("uid://d4e5ndtm65ok3").instantiate())

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


	if event.is_action_pressed("open_command_bar"):
		get_tree().root.add_child(preload("uid://rj2h8g761jr1").instantiate())
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("open_render_menu"):
		get_tree().root.add_child(preload("uid://chdpurqhtqieq").instantiate())

