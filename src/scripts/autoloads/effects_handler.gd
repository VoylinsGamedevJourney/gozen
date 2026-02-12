extends Node
# TODO: Load custom effects.

signal effect_added(clip_id: int)
signal effect_removed(clip_id: int)
signal effects_updated
signal effect_values_updated


const PATH_EFFECTS_VISUAL: String = "res://effects/visual/"
const PATH_EFFECTS_AUDIO: String = "res://effects/audio/"


var visual_effects: Dictionary[String, String] = {} ## { effect_name: effect_id }
var visual_effect_instances: Dictionary[String, GoZenEffectVisual] = {} ## { effect_id: effect_class }

var audio_effects: Dictionary[String, String] = {} ## { effect_name: effect_id }
var audio_effect_instances: Dictionary[String, GoZenEffectAudio] = {} ## { effect_id: effect_class }

var param_exceptions: Dictionary[String, Dictionary] = { ## Exceptions can be a string or callable.
	"transform": {
		"size": Project.get_resolution,
		"pivot": Project.get_resolution_center
	}
}


func _ready() -> void:
	_load_video_effects()
	_load_audio_effects()

# --- Loaders ---


func _load_video_effects() -> void:
	visual_effects.clear()
	visual_effect_instances.clear()

	for file_name: String in DirAccess.open(PATH_EFFECTS_VISUAL).get_files():
		if !file_name.ends_with(".tres"):
			continue
		var temp: Variant = load(PATH_EFFECTS_VISUAL + file_name)
		if temp is not GoZenEffectVisual:
			continue
		var effect: GoZenEffectVisual = temp
		visual_effects[effect.nickname] = effect.id
		visual_effect_instances[effect.id] = effect


func _load_audio_effects() -> void:
	audio_effects.clear()
	audio_effect_instances.clear()

	for file_name: String in DirAccess.open(PATH_EFFECTS_AUDIO).get_files():
		if !file_name.ends_with(".tres"):
			continue
		var temp: Variant = load(PATH_EFFECTS_AUDIO + file_name)
		if temp is not GoZenEffectAudio:
			continue
		var effect: GoZenEffectAudio = temp
		audio_effects[effect.nickname] = effect.id
		audio_effect_instances[effect.id] = effect


#---- Adding effects ----

func add_effect(clip_id: int, effect: GoZenEffect, is_visual: bool) -> void:
	if !Project.clips._id_map.has(clip_id):
		return
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect_id: String = effect.id
	var index: int

	if is_visual:
		index = clip_effects.video.size()
	else:
		index = clip_effects.audio.size()

	if effect_id in param_exceptions: # Handle exceptions
		for exception: String in param_exceptions[effect_id]:
			var value: Variant = param_exceptions[effect_id][exception]
			if value is Callable:
				effect.change_default_param(exception, (value as Callable).call())
			else:
				effect.change_default_param(exception, value)
	effect.set_default_keyframe()

	InputManager.undo_redo.create_action("Add effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_add_effect.bind(clip_id, index, effect, is_visual))
	InputManager.undo_redo.add_undo_method(_remove_effect.bind(clip_id, index, is_visual))
	InputManager.undo_redo.commit_action()


func _add_effect(clip_id: int, index: int, effect: GoZenEffect, is_visual: bool) -> void:
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	if is_visual:
		clip_effects.video.insert(index, effect)
	else:
		clip_effects.audio.insert(index, effect)

	effect_added.emit(clip_id)
	effects_updated.emit()


#---- Removing effects ----

func remove_effect(clip_id: int, index: int, is_visual: bool) -> void:
	if !Project.clips._id_map.has(clip_id) or index < 0:
		return
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect: GoZenEffect
	var size: int = clip_effects.video.size() if is_visual else clip_effects.audio.size()
	if index >= size: return printerr("EffectsHandler:
		Trying to remove invalid effect! ", index)

	if is_visual:
		effect = clip_effects.video[index]
	else:
		effect = clip_effects.audio[index]

	InputManager.undo_redo.create_action("Remove effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_remove_effect.bind(clip_id, index, is_visual))
	InputManager.undo_redo.add_undo_method(_add_effect.bind(clip_id, index, effect, is_visual))
	InputManager.undo_redo.commit_action()


func _remove_effect(clip_id: int, effect_index: int, is_visual: bool) -> void:
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	if is_visual:
		clip_effects.video.remove_at(effect_index)
	else:
		clip_effects.audio.remove_at(effect_index)

	effect_removed.emit(clip_id)
	effects_updated.emit()


#---- Moving effects ----

func move_effect(clip_id: int, effect_index: int, new_index: int, is_visual: bool) -> void:
	if !Project.clips._id_map.has(clip_id) or effect_index < 0 or new_index < 0:
		return
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect: GoZenEffect
	var size: int = clip_effects.video.size() if is_visual else clip_effects.audio.size()
	if effect_index >= size:
		return printerr("EffectsHandler:Trying to move invalid effect! ", effect_index)

	if is_visual:
		effect = clip_effects.video[effect_index]
	else:
		effect = clip_effects.audio[effect_index]

	InputManager.undo_redo.create_action("Move effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_move_effect.bind(clip_id, effect_index, new_index, is_visual))
	InputManager.undo_redo.add_undo_method(_move_effect.bind(clip_id, new_index, effect_index, is_visual))
	InputManager.undo_redo.commit_action()


func _move_effect(clip_id: int, effect_index: int, new_index: int, is_visual: bool) -> void:
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	if is_visual:
		var effect: GoZenEffect = clip_effects.video.pop_at(effect_index)
		clip_effects.video.insert(new_index, effect)
	else:
		var effect: GoZenEffect = clip_effects.audio.pop_at(effect_index)
		clip_effects.audio.insert(new_index, effect)
	effects_updated.emit()


#---- Updating effect params ----

func update_param(clip_id: int, effect_index: int, is_visual: bool, param_id: String, new_value: Variant, new_keyframe: bool) -> void:
	if !Project.clips._id_map.has(clip_id) or effect_index < 0:
		return
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var clip_start: int = Project.data.clips_start[clip_index]
	var effect: GoZenEffect
	var size: int = clip_effects.video.size() if is_visual else clip_effects.audio.size()
	if effect_index >= size:
		return printerr("EffectsHandler: Trying to remove invalid effect! ", effect_index)

	if is_visual:
		effect = clip_effects.video[effect_index]
	else:
		effect = clip_effects.audio[effect_index]

	InputManager.undo_redo.create_action("Update effect param: %s" % effect.nickname)

	# No keyframes (except 0) made, so we change main value, unless new keyframe requested
	var param_keyframes: Dictionary = effect.keyframes[param_id]
	if !new_keyframe and param_keyframes.size() == 1:
		var old_value: Variant = effect.keyframes[param_id][0]
		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip_id, effect_index, is_visual, param_id, 0, new_value))
		InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
				clip_id, effect_index, is_visual, param_id, 0, old_value))
	else:
		var frame_nr: int = EditorCore.frame_nr - clip_start
		var old_value: Variant = null
		var keyframe_exists: bool = false

		if param_keyframes.has(frame_nr):
			old_value = effect.keyframes[param_id][frame_nr]
			keyframe_exists = true
		else:
			# New keyframe, interpolate the value
			var effect_param: EffectParam = null
			for param: EffectParam in effect.params:
				if param.id != param_id:
					continue
				effect_param = param
				break
			if effect_param:
				old_value = effect.get_value(effect_param, frame_nr)
		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip_id, effect_index, is_visual, param_id, frame_nr, new_value))

		if keyframe_exists: # If keyframe already existed, we just adjust the keyframe
			InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
					clip_id, effect_index, is_visual, param_id, frame_nr, old_value))
		else: # If the keyframe didn't exist yet, we remove the newly created one on undo
			InputManager.undo_redo.add_undo_method(_remove_keyframe.bind(
					clip_id, effect_index, is_visual, param_id, frame_nr))
	InputManager.undo_redo.commit_action()


func remove_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int) -> void:
	if !Project.clips._id_map.has(clip_id) or index < 0:
		return
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect: GoZenEffect
	var size: int = clip_effects.video.size() if is_visual else clip_effects.audio.size()
	if index >= size: return printerr("EffectsHandler:
		Trying to remove keyframe from invalid effect! ", index)

	if is_visual:
		effect = clip_effects.video[index]
	else:
		effect = clip_effects.audio[index]

	# Check if there is actually a keyframe to remove
	if not effect.keyframes.has(param_id):
		return
	var effect_keyframes: Dictionary = effect.keyframes[param_id]
	if not effect_keyframes.has(frame_nr):
		return
	var old_value: Variant = effect_keyframes[frame_nr]

	InputManager.undo_redo.create_action("Remove keyframe: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_remove_keyframe.bind(
			clip_id, index, is_visual, param_id, frame_nr))
	InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
			clip_id, index, is_visual, param_id, frame_nr, old_value))
	InputManager.undo_redo.commit_action()


func _set_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int, value: Variant) -> void:
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect: GoZenEffect

	if is_visual:
		effect = clip_effects.video[index]
	else:
		effect = clip_effects.audio[index]
	if not effect.keyframes.has(param_id):
		effect.keyframes[param_id] = {}

	effect.keyframes[param_id][frame_nr] = value
	effect._cache_dirty = true
	effect_values_updated.emit()


func _remove_keyframe(clip_id: int, index: int, is_visual: bool, param_id: String, frame_nr: int) -> void:
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect: GoZenEffect

	if is_visual:
		effect = clip_effects.video[index]
	else:
		effect = clip_effects.audio[index]

	if effect.keyframes.has(param_id):
		var effect_keyframes: Dictionary = effect.keyframes[param_id]
		effect_keyframes.erase(frame_nr)
		if effect_keyframes.is_empty():
			effect_keyframes.erase(param_id)

	effect._cache_dirty = true
	effect_values_updated.emit()

#---- Switch enabled ----


func switch_enabled(clip_id: int, index: int, is_visual: bool) -> void:
	if !Project.clips._id_map.has(clip_id) or index < 0:
		return
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	var effect: GoZenEffect

	if index >= (clip_effects.video.size() if is_visual else clip_effects.audio.size()):
		return printerr("EffectsHandler: Trying to remove invalid effect! ", index)
	if is_visual:
		effect = clip_effects.video[index]
	else:
		effect = clip_effects.audio[index]

	InputManager.undo_redo.create_action("Move effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_switch_enabled.bind(clip_id, index, is_visual, !effect.is_enabled))
	InputManager.undo_redo.add_undo_method(_switch_enabled.bind(clip_id, index, is_visual, effect.is_enabled))
	InputManager.undo_redo.commit_action()


func _switch_enabled(clip_id: int, index: int, is_visual: bool, value: bool) -> void:
	var clip_index: int = Project.clips._id_map[clip_id]
	var clip_effects: ClipEffects = Project.data.clips_effects[clip_index]
	if is_visual:
		clip_effects.video[index].is_enabled = value
	else:
		clip_effects.audio[index].is_enabled = value
	effects_updated.emit()
