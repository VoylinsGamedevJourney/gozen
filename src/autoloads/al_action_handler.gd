extends Node

var actions_max := 100
var action_current := -1
var actions: Array = []


func _input(event):
	if event.is_action_pressed("ui_undo"):
		undo()
	if event.is_action_pressed("ui_redo"):
		redo()


func do(function: Callable, undo_function: Callable, args: Array = []) -> void:
	var action := Action.new(function, undo_function, args)
	if actions.size() != action_current:
		actions.resize(action_current+1)
	action_current += 1
	actions.append(action)
	function.call(args)


func undo() -> void:
	if actions.size() == 0:
		print("Nothing to undo!")
		return
	var action: Action = actions[action_current]
	action.undo_function.call(action.args)
	if action_current > 0:
		action_current -= 1 


func redo() -> void:
	if actions.size() < action_current:
		print("Nothing to redo!")
		return
	action_current += 1 
	var action: Action = actions[action_current]
	action.function.call(action.args)


class Action:
	var function: Callable
	var undo_function: Callable
	var args: Array
	
	func _init(_function: Callable, _undo_function: Callable, _args: Array = []):
		function = _function
		undo_function = _undo_function
		args = _args
