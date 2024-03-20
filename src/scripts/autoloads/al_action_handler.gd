extends Node
# MAYBE: Investigate build in UndoRedo class

var actions_max := 100
var action_current := -1
var actions: Array = []


func _input(event) -> void:
	if event.is_action_pressed("ui_undo"):
		undo()
	if event.is_action_pressed("ui_redo"):
		redo()


func do(function: Callable, undo_function: Callable, do_args: Array = [], undo_args: Array = []) -> void:
	var action := Action.new(function, undo_function, do_args, undo_args)
	function.call(do_args)
	if actions.size() == actions_max:
		actions.pop_front()
		actions.append(action)
		return
	elif actions.size() != action_current:
		actions.resize(action_current+1)
	action_current += 1
	actions.append(action)


func undo() -> void:
	if actions.size() == 0:
		return
	var action: Action = actions[action_current]
	action.undo_function.call(action.undo_args)
	if action_current > 0:
		action_current -= 1 


func redo() -> void:
	if actions.size() < action_current:
		return
	action_current += 1 
	var action: Action = actions[action_current]
	action.function.call(action.do_args)


class Action:
	var function: Callable
	var undo_function: Callable
	var do_args: Array
	var undo_args: Array
	
	func _init(
			_function: Callable, _undo_function: Callable, 
			_do_args: Array = [], _undo_args: Array = []) -> void:
		function = _function
		undo_function = _undo_function
		do_args = _do_args
		undo_args = _undo_args
