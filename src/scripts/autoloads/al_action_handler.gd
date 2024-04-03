extends Node
# MAYBE: Investigate build in UndoRedo class

var actions_max := 100
var action_current := -1
var actions: Array = []


func _input(a_event: InputEvent) -> void:
	if a_event.is_action_pressed("ui_undo"):
		undo()
	if a_event.is_action_pressed("ui_redo"):
		redo()


func do(a_function: Callable, a_undo_function: Callable, a_do_args: Array = [], a_undo_args: Array = []) -> void:
	var l_action: Action = Action.new(a_function, a_undo_function, a_do_args, a_undo_args)
	a_function.call(a_do_args)
	if actions.size() == actions_max:
		actions.pop_front()
		actions.append(l_action)
		return
	elif actions.size() != action_current:
		actions.resize(action_current + 1)
	action_current += 1
	actions.append(l_action)


func undo() -> void:
	if actions.size() != 0:
		var l_action: Action = actions[action_current]
		l_action.undo_function.call(l_action.undo_args)
		if action_current > 0:
			action_current -= 1 


func redo() -> void:
	if actions.size() >= action_current:
		action_current += 1 
		var l_action: Action = actions[action_current]
		l_action.function.call(l_action.do_args)


class Action:
	var function: Callable
	var undo_function: Callable
	var do_args: Array
	var undo_args: Array
	
	func _init(
			a_function: Callable, a_undo_function: Callable, 
			a_do_args: Array = [], a_undo_args: Array = []) -> void:
		function = a_function
		undo_function = a_undo_function
		do_args = a_do_args
		undo_args = a_undo_args
