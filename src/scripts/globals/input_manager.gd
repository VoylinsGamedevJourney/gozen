extends Node


var undo_redo: UndoRedo = UndoRedo.new()



func _ready() -> void:
	undo_redo.max_steps = 200


func _input(event: InputEvent) -> void:
	if Project.data == null:
		return

	if event.is_action_pressed("save_project", false, true):
		Project.save()

	if event.is_action_pressed("ui_undo", false, true) and undo_redo.has_undo():
		if !undo_redo.undo():
			printerr("Couldn't undo!")
	if event.is_action_pressed("ui_redo", false, true) and undo_redo.has_redo():
		if !undo_redo.redo():
			printerr("Couldn't redo!")

	if event.is_action_pressed("timeline_play_pause", false, true):
		Editor.on_play_pressed()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("breakpoint", true):
		breakpoint

