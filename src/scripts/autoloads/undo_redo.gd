extends Node


var _data: UndoRedo = UndoRedo.new()



func _ready() -> void: _data.max_steps = 200
func _on_closing_editor() -> void: _data.free()


#--- Handling ---

func has_undo() -> bool: return _data.has_undo()
func undo() -> bool:	 return _data.undo()

func has_redo() -> bool: return _data.has_redo()
func redo() -> bool:	 return _data.redo()

func create_action(title: String, merge_mode: int = 0) -> void: _data.create_action(title, merge_mode)

func add_do(method: Callable) -> void:	 _data.add_do_method(method)
func add_undo(method: Callable) -> void: _data.add_undo_method(method)

func commit_action(execute: bool = true) -> void: _data.commit_action(execute)

func clear_history() -> void: _data.clear_history()


#--- History stuff ---

func open_history() -> void:
	# TODO: Create a popup to show and select the history. (Should have a button to clear the history as well)
	pass
