extends Node
# TODO: Make the max steps adjustable.


const MAX_STEPS: int = 200


var _data: UndoRedo = UndoRedo.new()



func _ready() -> void:
	_data.max_steps = 200


func _on_closing_editor() -> void:
	_data.free()


#--- UNDO ---

func has_undo() -> bool:
	return _data.has_undo()


func undo() -> bool:
	return _data.undo()


#--- REDO ---

func has_redo() -> bool:
	return _data.has_undo()


func redo() -> bool:
	return _data.undo()


#--- Handling ---

func create_action(title: String, merge_mode: int = 0) -> void:
	_data.create_action(title, merge_mode)


func add_do(method: Callable) -> void:
	_data.add_do_method(method)


func add_undo(method: Callable) -> void:
	_data.add_undo_method(method)


func commit_action(execute: bool = true) -> void:
	_data.commit_action(execute)


func clear_history() -> void:
	_data.clear_history()
