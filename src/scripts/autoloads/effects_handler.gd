extends Node
# TODO: Load custom effects.

signal effect_added(clip_id: int)
signal effect_removed(clip_id: int)
signal effects_updated()
signal effect_values_updated()

const PATH_EFFECTS_VISUAL: String = "res://effects/visual/"
const PATH_EFFECTS_AUDIO: String = "res://effects/audio/"


var visual_effects: Dictionary[String, String] = {} # { effect_name: effect_id }
var visual_effect_instances: Dictionary[String, GoZenEffectVisual] = {} # { effect_id: effect_class }

var audio_effects: Dictionary[String, String] = {} # { effect_name: effect_id }
var audio_effect_instances: Dictionary[String, GoZenEffectAudio] = {} # { effect_id: effect_class }

var effect_param_exceptions: Dictionary[String, Dictionary] = {
	"transform": {
		"size": Project.get_resolution,
		"pivot": Project.get_resolution_center
	}
}



func _ready() -> void:
	_load_video_effects()
	_load_audio_effects()

	
func _load_video_effects() -> void:
	visual_effects.clear()
	visual_effect_instances.clear()

	for file_name: String in DirAccess.open(PATH_EFFECTS_VISUAL).get_files():
		if file_name.ends_with(".tres"):
			var effect: GoZenEffectVisual = load(PATH_EFFECTS_VISUAL + file_name)

			visual_effects[effect.effect_name] = effect.effect_id
			visual_effect_instances[effect.effect_id] = effect


func _load_audio_effects() -> void:
	audio_effects.clear()
	audio_effect_instances.clear()

	for file_name: String in DirAccess.open(PATH_EFFECTS_AUDIO).get_files():
		if file_name.ends_with(".tres"):
			var effect: GoZenEffectAudio = load(PATH_EFFECTS_AUDIO + file_name)

			audio_effects[effect.effect_name] = effect.effect_id
			audio_effect_instances[effect.effect_id] = effect


#---- Adding effects ----
func add_effect(clip_id: int, effect: GoZenEffect, is_visual: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)
	var index: int = list.size()

	if effect.effect_id in effect_param_exceptions:
		var id: String = effect.effect_id

		for exception: String in effect_param_exceptions[id]:
			var exception_value: Variant = effect_param_exceptions[id][exception]

			if exception_value is Callable:
				effect.change_default_param(exception, exception_value.call())
			else:
				effect.change_default_param(exception, exception_value)

	effect.set_default_keyframe()

	InputManager.undo_redo.create_action("Add effect: %s" % effect.effect_name)

	InputManager.undo_redo.add_do_method(_add_effect.bind(clip_id, index, effect, is_visual))
	InputManager.undo_redo.add_undo_method(_remove_effect.bind(clip_id, index, is_visual))

	InputManager.undo_redo.commit_action()


func _add_effect(clip_id: int, index: int, effect: GoZenEffect, is_visual: bool) -> void:
	if is_visual:
		ClipHandler.clips[clip_id].effects_video.insert(index, effect)
	else:
		ClipHandler.clips[clip_id].effects_audio.insert(index, effect)

	effect_added.emit(clip_id)
	effects_updated.emit()


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

	InputManager.undo_redo.commit_action()


func _remove_effect(clip_id: int, index: int, is_visual: bool) -> void:
	if is_visual:
		ClipHandler.clips[clip_id].effects_video.remove_at(index)
	else:
		ClipHandler.clips[clip_id].effects_audio.remove_at(index)

	effect_removed.emit(clip_id)
	effects_updated.emit()


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

	InputManager.undo_redo.commit_action()


func _move_effect(clip_id: int, index: int, new_index: int, is_visual: bool) -> void:
	if is_visual:
		var effect: GoZenEffect = ClipHandler.clips[clip_id].effects_video.pop_at(index)

		ClipHandler.clips[clip_id].effects_video.insert(new_index, effect)
	else:
		var effect: GoZenEffect = ClipHandler.clips[clip_id].effects_audio.pop_at(index)

		ClipHandler.clips[clip_id].effects_audio.insert(new_index, effect)

	effects_updated.emit()



#---- Updating effect params ----
func update_param(clip_id: int, index: int, is_visual: bool, param_id: String, new_value: Variant, new_keyframe: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)

	if index < 0 or index >= list.size():
		printerr("EffectsHandler: Trying to remove invalid effect! ", index)
		return


	var effect: GoZenEffect = list[index]

	InputManager.undo_redo.create_action("Update effect param: %s" % effect.effect_name)

	# No keyframes (except 0) made, so we change main value, unless new keyframe requested
	if !new_keyframe and effect.keyframes[param_id].size() == 1:
		var old_value: Variant = effect.keyframes[param_id][0]

		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip_id, index, is_visual, param_id, 0, new_value))
		InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
				clip_id, index, is_visual, param_id, 0, old_value))
	else:
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

		InputManager.undo_redo.add_do_method(_set_keyframe.bind(clip_id, index, is_visual, param_id, frame_nr, new_value))

		if keyframe_exists: # If keyframe already existed, we just adjust the keyframe
			InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
					clip_id, index, is_visual, param_id, frame_nr, old_value))
		else: # If the keyframe didn't exist yet, we remove the newly created one on undo
			InputManager.undo_redo.add_undo_method(_remove_keyframe.bind(
					clip_id, index, is_visual, param_id, frame_nr))

	InputManager.undo_redo.commit_action()


func _set_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int, value: Variant) -> void:
	var list: Array = _get_effect_list(ClipHandler.get_clip(clip_id), is_visual)
	var effect: GoZenEffect = list[index]
	
	if not effect.keyframes.has(param_id):
		effect.keyframes[param_id] = {}

	effect.keyframes[param_id][frame_nr] = value
	effect._cache_dirty = true
	effect_values_updated.emit()


func _remove_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int) -> void:
	var list: Array = _get_effect_list(ClipHandler.get_clip(clip_id), is_visual)
	var effect: GoZenEffect = list[index]
	
	if effect.keyframes.has(param_id):
		effect.keyframes[param_id].erase(frame_nr)

		if effect.keyframes[param_id].is_empty(): # Clean up dictionary if empty
			effect.keyframes.erase(param_id)
		
	effect._cache_dirty = true
	effect_values_updated.emit()


#---- Switch enabled ----
func switch_enabled(clip_id: int, index: int, is_visual: bool) -> void:
	if !ClipHandler.has_clip(clip_id):
		return

	var clip_data: ClipData = ClipHandler.get_clip(clip_id)
	var list: Array = _get_effect_list(clip_data, is_visual)

	if index < 0 or index >= list.size():
		printerr("EffectsHandler: Trying to remove invalid effect! ", index)
		return

	var effect: GoZenEffect = list[index]
	var enabled: bool = effect.is_enabled

	InputManager.undo_redo.create_action("Move effect: %s" % effect.effect_name)

	InputManager.undo_redo.add_do_method(_switch_enabled.bind(clip_id, index, is_visual, !enabled))
	InputManager.undo_redo.add_undo_method(_switch_enabled.bind(clip_id, index, is_visual, enabled))

	InputManager.undo_redo.commit_action()


func _switch_enabled(clip_id: int, index: int, is_visual: bool, value: bool) -> void:
	if is_visual:
		ClipHandler.clips[clip_id].effects_video[index].is_enabled = value
	else:
		ClipHandler.clips[clip_id].effects_audio[index].is_enabled = value
	
	effects_updated.emit()


#---- Helper functions ----
func _get_effect_list(clip_data: ClipData, is_visual: bool) -> Array:
	if is_visual:
		return clip_data.effects_video
	return clip_data.effects_audio
