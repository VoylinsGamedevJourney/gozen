extends Node

signal effect_added(clip_id: int)
signal effect_removed(clip_id: int)
signal effects_updated()



#---- Adding effects ----
func add_effect(clip_id: int, effect: GoZenEffect, is_visual: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)

	var index: int = list.size()

	InputManager.undo_redo.create_action("Add effect: %s" % effect.effect_name)

	InputManager.undo_redo.add_do_method(_add_effect.bind(clip_id, index, effect, is_visual))
	InputManager.undo_redo.add_undo_method(_remove_effect.bind(clip_id, index, is_visual))

	InputManager.undo_redo.add_do_method(effect_added.emit.bind(clip_id))
	InputManager.undo_redo.add_do_method(effects_updated.emit)
	InputManager.undo_redo.add_undo_method(effect_removed.emit.bind(clip_id))
	InputManager.undo_redo.add_undo_method(effects_updated.emit)

	InputManager.undo_redo.commit_action()


func _add_effect(clip_id: int, index: int, effect: GoZenEffect, is_visual: bool) -> void:
	if is_visual:
		ClipHandler.clips[clip_id].effects_video.insert(index, effect)
	else:
		ClipHandler.clips[clip_id].effects_audio.insert(index, effect)


#---- Removing effects ----
func remove_effect(clip_id: int, index: int, is_visual: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)

	if index < 0 or index >= list.size():
		printerr("EffectsHandler: Trying to remove invalid effect! ", index)
		return

	var effect: GoZenEffect = list[index]

	InputManager.undo_redo.create_action("Remove effect: %s" % effect.effect_name)

	InputManager.undo_redo.add_do_method(_remove_effect.bind(clip_id, index, is_visual))
	InputManager.undo_redo.add_undo_method(_add_effect.bind(clip_id, index, effect, is_visual))

	InputManager.undo_redo.add_do_method(effect_removed.emit.bind(clip_id))
	InputManager.undo_redo.add_do_method(effects_updated.emit)
	InputManager.undo_redo.add_undo_method(effect_added.emit.bind(clip_id))
	InputManager.undo_redo.add_undo_method(effects_updated.emit)

	InputManager.undo_redo.commit_action()


func _remove_effect(clip_id: int, index: int, is_visual: bool) -> void:
	if is_visual:
		ClipHandler.clips[clip_id].effects_video.remove_at(index)
	else:
		ClipHandler.clips[clip_id].effects_audio.remove_at(index)


#---- Moving effects ----
func move_effect(clip_id: int, index: int, new_index: int, is_visual: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)

	if index < 0 or index >= list.size():
		printerr("EffectsHandler: Trying to remove invalid effect! ", index)
		return

	var effect: GoZenEffect = list[index]

	InputManager.undo_redo.create_action("Move effect: %s" % effect.effect_name)

	InputManager.undo_redo.add_do_method(_move_effect.bind(clip_id, index, new_index, is_visual))
	InputManager.undo_redo.add_undo_method(_move_effect.bind(clip_id, new_index, index, is_visual))

	InputManager.undo_redo.add_do_method(effects_updated.emit.bind(clip_id))
	InputManager.undo_redo.add_undo_method(effects_updated.emit.bind(clip_id))

	InputManager.undo_redo.commit_action()


func _move_effect(clip_id: int, index: int, new_index: int, is_visual: bool) -> void:
	if is_visual:
		var effect: GoZenEffect = ClipHandler.clips[clip_id].effects_video.pop_at(index)

		ClipHandler.clips[clip_id].effects_video.insert(new_index, effect)
	else:
		var effect: GoZenEffect = ClipHandler.clips[clip_id].effects_audio.pop_at(index)

		ClipHandler.clips[clip_id].effects_audio.insert(new_index, effect)


#---- Updating effect params ----
func update_param(clip_id: int, index: int, is_visual: bool, param_id: String, new_value: Variant) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)

	if index < 0 or index >= list.size():
		printerr("EffectsHandler: Trying to remove invalid effect! ", index)
		return

	var effect: GoZenEffect = list[index]
	var frame_nr: int = EditorCore.frame_nr - clip_data.start_frame

	var old_value: Variant = null
	var keyframe_exists: bool = false

	if effect.keyframes.has(param_id) and effect.keyframes[param_id].has(frame_nr):
		old_value = effect.keyframes[param_id][frame_nr]
		keyframe_exists = true
	else:
		# New keyframe, interpolate the value
		var effect_param: EffectParam = null

		for param: EffectParam in effect.params:
			if param.param_id == param_id:
				effect_param = param
				break

		if effect_param:
			old_value = effect.get_value(effect_param, frame_nr)

	InputManager.undo_redo.create_action("Update effect param: %s" % effect.effect_name)

	InputManager.undo_redo.add_do_method(_set_keyframe.bind(clip_id, index, is_visual, param_id, frame_nr, new_value))

	if keyframe_exists: # If keyframe already existed, we just adjust the keyframe
		InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
				clip_id, index, is_visual, param_id, frame_nr, old_value))
	else: # If the keyframe didn't exist yet, we remove the newly created one on undo
		InputManager.undo_redo.add_undo_method(_remove_keyframe.bind(
				clip_id, index, is_visual, param_id, frame_nr))

	InputManager.undo_redo.add_do_method(effects_updated.emit.bind(clip_id))
	InputManager.undo_redo.add_undo_method(effects_updated.emit.bind(clip_id))

	InputManager.undo_redo.commit_action()


func _set_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int, value: Variant) -> void:
	var list: Array = _get_effect_list(ClipHandler.get_clip(clip_id), is_visual)
	var effect: GoZenEffect = list[index]
	
	if not effect.keyframes.has(param_id):
		effect.keyframes[param_id] = {}
	
	effect.keyframes[param_id][frame_nr] = value
	effect._cache_dirty = true


func _remove_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int) -> void:
	var list: Array = _get_effect_list(ClipHandler.get_clip(clip_id), is_visual)
	var effect: GoZenEffect = list[index]
	
	if effect.keyframes.has(param_id):
		effect.keyframes[param_id].erase(frame_nr)

		if effect.keyframes[param_id].is_empty(): # Clean up dictionary if empty
			effect.keyframes.erase(param_id)
		
	effect._cache_dirty = true


#---- Helper functions ----
func _get_effect_list(clip_data: ClipData, is_visual: bool) -> Array:
	if is_visual:
		return clip_data.effects_video
	return clip_data.effects_audio
