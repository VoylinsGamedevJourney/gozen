extends Node
# TODO: Load custom effects.

signal effect_added(clip: ClipData, index: int, is_visual: bool)
signal effect_removed(clip: ClipData, index: int, is_visual: bool)
signal effect_moved(clip: ClipData, old_index: int, new_index: int, is_visual: bool)
signal effects_updated
signal effect_values_updated


const PATH_EFFECTS_VISUAL: String = "res://effects/visual/"
const PATH_EFFECTS_AUDIO: String = "res://effects/audio/"


var visual_effects: Dictionary[String, String] = {} ## { effect_name: effect_id }
var visual_effect_instances: Dictionary[String, EffectVisual] = {} ## { effect_id: effect_class }

var audio_effects: Dictionary[String, String] = {} ## { effect_name: effect_id }
var audio_effect_instances: Dictionary[String, EffectAudio] = {} ## { effect_id: effect_class }

## Exceptions can be a string or callable.
var param_exceptions: Dictionary[String, Dictionary] = {
	"transform": { "pivot": func() -> Vector2i: return Project.get_resolution_center() },
	"rounded_corners": {
		"width": func() -> float: return Project.get_resolution().x,
		"height":  func() -> float: return Project.get_resolution().y,
		"center_x": func() -> float: return Project.get_resolution_center().x,
		"center_y": func() -> float: return Project.get_resolution_center().y
	},
	"vignette": {
		"center_x": func() -> float: return Project.get_resolution_center().x,
		"center_y": func() -> float: return Project.get_resolution_center().y
	},
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
		if temp is not EffectVisual:
			continue
		var effect: EffectVisual = temp
		visual_effects[effect.nickname] = effect.id
		visual_effect_instances[effect.id] = effect


func _load_audio_effects() -> void:
	audio_effects.clear()
	audio_effect_instances.clear()

	for file_name: String in DirAccess.open(PATH_EFFECTS_AUDIO).get_files():
		if !file_name.ends_with(".tres"):
			continue
		var temp: Variant = load(PATH_EFFECTS_AUDIO + file_name)
		if temp is not EffectAudio:
			continue
		var effect: EffectAudio = temp
		audio_effects[effect.nickname] = effect.id
		audio_effect_instances[effect.id] = effect


#---- Adding effects ----

func add_effect(clip: ClipData, effect: Effect, is_visual: bool) -> void:
	var effect_id: String = effect.id
	var index: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()

	if effect_id in param_exceptions: # Handle exceptions
		for exception: String in param_exceptions[effect_id]:
			var value: Variant = param_exceptions[effect_id][exception]
			if value is Callable:
				effect.change_default_param(exception, (value as Callable).call())
			else:
				effect.change_default_param(exception, value)
	effect.set_default_keyframe()

	InputManager.undo_redo.create_action("Add effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_add_effect.bind(clip, index, effect, is_visual))
	InputManager.undo_redo.add_undo_method(_remove_effect.bind(clip, index, is_visual))
	InputManager.undo_redo.commit_action()


func _add_effect(clip: ClipData, index: int, effect: Effect, is_visual: bool) -> void:
	if is_visual:
		clip.effects.video.insert(index, effect)
	else:
		clip.effects.audio.insert(index, effect)

	effect_added.emit(clip, index, is_visual)
	effects_updated.emit()


#---- Removing effects ----

func remove_effect(clip: ClipData, index: int, is_visual: bool) -> void:
	if !ClipLogic.clips.has(clip.id) or index < 0:
		return
	var effect: Effect
	var size: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()
	if index >= size: return printerr("EffectsHandler:
		Trying to remove invalid effect! ", index)

	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]

	InputManager.undo_redo.create_action("Remove effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_remove_effect.bind(clip, index, is_visual))
	InputManager.undo_redo.add_undo_method(_add_effect.bind(clip, index, effect, is_visual))
	InputManager.undo_redo.commit_action()


func _remove_effect(clip: ClipData, effect_index: int, is_visual: bool) -> void:
	if is_visual:
		clip.effects.video.remove_at(effect_index)
	else:
		clip.effects.audio.remove_at(effect_index)

	effect_removed.emit(clip, effect_index, is_visual)
	effects_updated.emit()


#---- Moving effects ----

func move_effect(clip: ClipData, effect_index: int, new_index: int, is_visual: bool) -> void:
	if effect_index < 0 or new_index < 0:
		return
	var effect: Effect
	var size: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()
	if effect_index >= size:
		return printerr("EffectsHandler:Trying to move invalid effect! ", effect_index)

	if is_visual:
		effect = clip.effects.video[effect_index]
	else:
		effect = clip.effects.audio[effect_index]

	InputManager.undo_redo.create_action("Move effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_move_effect.bind(clip, effect_index, new_index, is_visual))
	InputManager.undo_redo.add_undo_method(_move_effect.bind(clip, new_index, effect_index, is_visual))
	InputManager.undo_redo.commit_action()


func _move_effect(clip: ClipData, effect_index: int, new_index: int, is_visual: bool) -> void:
	if is_visual:
		var effect: Effect = clip.effects.video.pop_at(effect_index)
		clip.effects.video.insert(new_index, effect)
	else:
		var effect: Effect = clip.effects.audio.pop_at(effect_index)
		clip.effects.audio.insert(new_index, effect)
	effect_moved.emit(clip, effect_index, new_index, is_visual)
	effects_updated.emit()


#---- Updating effect params ----

func update_param(clip: ClipData, effect_index: int, is_visual: bool, param_id: String, new_value: Variant, new_keyframe: bool) -> void:
	if effect_index < 0:
		return
	var effect: Effect
	var size: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()
	if effect_index >= size:
		return printerr("EffectsHandler: Trying to remove invalid effect! ", effect_index)
	if is_visual:
		effect = clip.effects.video[effect_index]
	else:
		effect = clip.effects.audio[effect_index]

	InputManager.undo_redo.create_action("Update effect param: %s" % effect.nickname)
	var effect_param: EffectParam = null
	for param: EffectParam in effect.params:
		if param.id == param_id:
			effect_param = param
			break
	effect.set_default_keyframe()

	# No keyframes (except 0) made, so we change main value, unless new keyframe requested.
	var param_keyframes: Dictionary = effect.keyframes[param_id]
	var is_keyframeable: bool = effect_param.keyframeable if effect_param else true
	if (!new_keyframe and param_keyframes.size() == 1) or !is_keyframeable:
		var old_value: Variant = effect.keyframes[param_id][0]
		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip, effect_index, is_visual, param_id, 0, new_value))
		InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
				clip, effect_index, is_visual, param_id, 0, old_value))
	else:
		var frame_nr: int = EditorCore.frame_nr - clip.start
		var old_value: Variant = null
		var keyframe_exists: bool = false

		if param_keyframes.has(frame_nr):
			old_value = effect.keyframes[param_id][frame_nr]
			keyframe_exists = true
		elif effect_param: # New keyframe.
			old_value = effect.get_value(effect_param, frame_nr)

		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip, effect_index, is_visual, param_id, frame_nr, new_value))

		if keyframe_exists: # If keyframe already existed, we just adjust the keyframe.
			InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
					clip, effect_index, is_visual, param_id, frame_nr, old_value))
		else: # If the keyframe didn't exist yet, we remove the newly created one on undo.
			InputManager.undo_redo.add_undo_method(_remove_keyframe.bind(
					clip, effect_index, is_visual, param_id, frame_nr))
	InputManager.undo_redo.commit_action()


#---- Removing keyframes ----

func remove_keyframe(clip: ClipData, index: int, is_visual: bool, param_id: String, frame_nr: int) -> void:
	if index < 0:
		return
	var effect: Effect
	var size: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()
	if index >= size: return printerr("EffectsHandler:
		Trying to remove keyframe from invalid effect! ", index)

	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]

	# Check if there is actually a keyframe to remove
	if not effect.keyframes.has(param_id):
		return
	var effect_keyframes: Dictionary = effect.keyframes[param_id]
	if not effect_keyframes.has(frame_nr):
		return
	var old_value: Variant = effect_keyframes[frame_nr]

	InputManager.undo_redo.create_action("Remove keyframe: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_remove_keyframe.bind(
			clip, index, is_visual, param_id, frame_nr))
	InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
			clip, index, is_visual, param_id, frame_nr, old_value))
	InputManager.undo_redo.commit_action()


func _set_keyframe(clip: ClipData, index: int, is_visual: bool, param_id: String, frame_nr: int, value: Variant) -> void:
	var effect: Effect
	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]
	if not effect.keyframes.has(param_id):
		var typed_dict: Dictionary[int, Variant] = {}
		effect.keyframes[param_id] = typed_dict

	effect.keyframes[param_id][frame_nr] = value
	effect._cache_dirty = true
	effect_values_updated.emit()


func _remove_keyframe(clip: ClipData, index: int, is_visual: bool, param_id: String, frame_nr: int) -> void:
	var effect: Effect
	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]

	if effect.keyframes.has(param_id):
		var effect_keyframes: Dictionary = effect.keyframes[param_id]
		effect_keyframes.erase(frame_nr)
		if effect_keyframes.is_empty():
			effect_keyframes.erase(param_id)

	effect._cache_dirty = true
	effect_values_updated.emit()


#---- Moving effect keyframes ----

## Moves all keyframes from all parameters at old_frame to new_frame.
## If preserve_existing is true (ctrl pressed), existing values at new_frame
## are kept. Otherwise, values from old_frame overwrite existing ones.
func move_effect_keyframe_at_frame(clip: ClipData, effect_index: int, is_visual: bool, old_frame: int, new_frame: int, preserve_existing: bool, is_copy: bool = false) -> void:
	if old_frame == new_frame:
		return
	var effect: Effect
	if is_visual:
		effect = clip.effects.video[effect_index]
	else:
		effect = clip.effects.audio[effect_index]

	InputManager.undo_redo.create_action("Move/Copy Effect Keyframe(s)")
	for param: EffectParam in effect.params:
		var param_id: String = param.id
		if not effect.keyframes.has(param_id):
			continue

		var keyframes: Dictionary = effect.keyframes[param_id]
		if not keyframes.has(old_frame):
			continue

		var value_to_move: Variant = effect.keyframes[param_id][old_frame]
		var value_at_target: Variant = null
		var has_target: bool = keyframes.has(new_frame)
		if has_target:
			value_at_target = effect.keyframes[param_id][new_frame]

		var final_value: Variant = value_to_move
		if has_target and preserve_existing:
			final_value = value_at_target

		if old_frame != 0 and not is_copy:
			InputManager.undo_redo.add_do_method(
					_remove_keyframe.bind(clip, effect_index, is_visual, param_id, old_frame))
			InputManager.undo_redo.add_undo_method(
					_set_keyframe.bind(clip, effect_index, is_visual, param_id, old_frame, value_to_move))

		if !(has_target and preserve_existing):
			InputManager.undo_redo.add_do_method(_set_keyframe.bind(
					clip, effect_index, is_visual, param_id, new_frame, final_value))

			if has_target:
				InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
						clip, effect_index, is_visual, param_id, new_frame, value_at_target))
			else:
				InputManager.undo_redo.add_undo_method(_remove_keyframe.bind(
						clip, effect_index, is_visual, param_id, new_frame))
	InputManager.undo_redo.commit_action()
	effects_updated.emit()


#---- Removing effect keyframes ----

## Deletes all parameter keyframes at a specific frame for this effect.
func remove_effect_keyframe_at_frame(clip: ClipData, effect_index: int, is_visual: bool, frame_nr: int) -> void:
	if frame_nr == 0:
		return
	var effect: Effect
	if is_visual:
		effect = clip.effects.video[effect_index]
	else:
		effect = clip.effects.audio[effect_index]

	InputManager.undo_redo.create_action("Remove Effect Keyframe(s)")
	for param: EffectParam in effect.params:
		var param_id: String = param.id
		if not effect.keyframes.has(param_id):
			continue

		var keyframes: Dictionary = effect.keyframes[param_id]
		if not keyframes.has(frame_nr):
			continue

		var old_val: Variant = effect.keyframes[param_id][frame_nr]
		InputManager.undo_redo.add_do_method(_remove_keyframe.bind(clip, effect_index, is_visual, param_id, frame_nr))
		InputManager.undo_redo.add_undo_method(_set_keyframe.bind(clip, effect_index, is_visual, param_id, frame_nr, old_val))
	InputManager.undo_redo.commit_action()
	effects_updated.emit()


#---- Switch enabled ----

func switch_enabled(clip: ClipData, index: int, is_visual: bool) -> void:
	if index < 0:
		return
	var effect: Effect

	if index >= (clip.effects.video.size() if is_visual else clip.effects.audio.size()):
		return printerr("EffectsHandler: Trying to remove invalid effect! ", index)
	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]

	InputManager.undo_redo.create_action("Move effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_switch_enabled.bind(clip, index, is_visual, !effect.is_enabled))
	InputManager.undo_redo.add_undo_method(_switch_enabled.bind(clip, index, is_visual, effect.is_enabled))
	InputManager.undo_redo.commit_action()


func _switch_enabled(clip: ClipData, index: int, is_visual: bool, value: bool) -> void:
	if is_visual:
		clip.effects.video[index].is_enabled = value
	else:
		clip.effects.audio[index].is_enabled = value
	effects_updated.emit()
