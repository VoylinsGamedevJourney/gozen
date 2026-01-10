extends Node

signal effect_added(clip_id: int)
signal effect_removed(clip_id: int)
signal effects_updated(clip_id: int)
signal param_changed(clip_id: int, effect_index: int)



func add_visual_effect(clip_id: int, effect: VisualEffect) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	InputManager.undo_redo.create_action("Add effect")
	InputManager.undo_redo.add_do_method(_add_visual_effect.bind(clip_id, effect))
	InputManager.undo_redo.add_undo_method(_remove_visual_effect.bind(clip_id, effect_index))

	InputManager.undo_redo.add_do_method(ClipHandler.clips_updated.emit())
	InputManager.undo_redo.add_undo_method(ClipHandler.clips_updated.emit())
	InputManager.undo_redo.commit_action()


func _add_visual_effect(clip_id: int, effect: VisualEffect) -> void:
	effect_added.emit(clip_id)
	effects_updated.emit()


func remove_visual_effect(clip_id: int, effect_index: int) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	InputManager.undo_redo.create_action("Remove effect")
	InputManager.undo_redo.add_do_method(_remove_visual_effect.bind(clip_id, effect_index))
	InputManager.undo_redo.add_undo_method(_add_visual_effect.bind(clip_id, effect))

	InputManager.undo_redo.add_do_method(ClipHandler.clips_updated.emit())
	InputManager.undo_redo.add_undo_method(ClipHandler.clips_updated.emit())
	InputManager.undo_redo.commit_action()


func _remove_visual_effect(clip_id: int, effect_index: int) -> void:
	effect_removed.emit(clip_id)
	effects_updated.emit()


func move_effect(clip_id: int, effect_index: int, move_up: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	InputManager.undo_redo.create_action("Move effect")
	InputManager.undo_redo.commit_action()


func _move_effect(clip_id: int, effect_index: int, move_up: bool) -> void:
	effects_updated.emit()


func update_param(clip_id: int, effect_index: int, is_visual: bool, param_id: String, new_value: Variant) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	InputManager.undo_redo.create_action("Update effect param")
	InputManager.undo_redo.commit_action()


func _update_param(clip_id: int, effect_index: int, is_visual: bool, param_id: String, new_value: Variant) -> void:
	param_changed.emit(clip_id, effect_index)
	effects_updated.emit()
