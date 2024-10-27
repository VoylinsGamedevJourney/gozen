extends Node

var _enabled: bool = false

var current_action: int = -1
var actions: Array[Action] = []



func _ready() -> void:
	CoreLoader.append("Enabling ActionManager", func() -> void: _enabled = true)


func _input(a_event: InputEvent) -> void:
	if !_enabled:
		return

	elif a_event.is_action_pressed("undo"):
		undo_action()
	elif a_event.is_action_pressed("redo"):
		redo_action()

	elif a_event.is_action_pressed("save_project"):
		Project.save_data()
	elif a_event.is_action_pressed("fullscreen"):
		SettingsManager.change_window_mode(Window.MODE_FULLSCREEN)

	elif a_event.is_action_pressed("clip_delete") and CoreTimeline.selected_clips.size() != 0:
		# TODO: Add this to actions which can be reverted, maybe have in GoZenServer remove_clips and add_clips
		for l_id: int in CoreTimeline.selected_clips:
			CoreTimeline.remove_clip(l_id)
		CoreTimeline.selected_clips = []

	elif a_event.is_action_pressed("open_help"):
		print("Not implemented yet!")

	elif a_event.is_action_pressed("play"):
		CoreView._on_play_pressed()


func undo_action() -> void:
	if actions.size() != 0:
		actions[current_action].undo()
		current_action -= 1

	
func redo_action() -> void:
	if actions.size() >= current_action:
		current_action += 1
		actions[current_action].do()

	
func do(a_action: Action) -> void:
	a_action.do()

	if actions.size() == SettingsManager.max_actions:
		actions.pop_front()
		actions.append(a_action)
		return
	elif actions.size() != current_action:
		if actions.resize(current_action + 1):
			printerr("Error resizing actions in Action Manager!")
	
	current_action += 1
	actions.append(a_action)

