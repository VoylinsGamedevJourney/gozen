extends Node


var undo_redo: UndoRedo = UndoRedo.new()



func _ready() -> void:
	undo_redo.max_steps = 200


func _input(a_event: InputEvent) -> void:
	if Project.data == null:
		return

	if a_event.is_action_pressed("save_project", false, true):
		Project.save()

	if a_event.is_action_pressed("ui_undo", false, true) and undo_redo.has_undo():
		if !undo_redo.undo():
			printerr("Couldn't undo!")
	if a_event.is_action_pressed("ui_redo", false, true) and undo_redo.has_redo():
		if !undo_redo.redo():
			printerr("Couldn't redo!")

