extends Node
# TODO: Load custom effects.

signal effect_added(clip: ClipData, index: int, is_visual: bool)
signal effect_removed(clip: ClipData, index: int, is_visual: bool)
signal effect_moved(clip: ClipData, old_index: int, new_index: int, is_visual: bool)
signal effects_updated
signal effect_values_updated

@warning_ignore("unused_signal") # Signal is used in other scripts.
signal effect_selected(effect: Effect)


const PATH_EFFECTS_VISUAL: String = "res://effects/visual/"
const PATH_EFFECTS_AUDIO: String = "res://effects/audio/"


var visual_effects: Dictionary[String, String] = {} ## { effect_name: effect_id }
var visual_effect_instances: Dictionary[String, EffectVisual] = {} ## { effect_id: effect_class }
var shader_cache: Dictionary[String, RDShaderFile] = {}

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
		file_name = file_name.trim_suffix(".remap")
		if !file_name.ends_with(".tres"):
			continue
		var temp: Variant = load(PATH_EFFECTS_VISUAL + file_name)
		if temp is not EffectVisual:
			continue
		var effect: EffectVisual = temp
		if visual_effect_instances.has(effect.id):
			continue
		visual_effects[effect.nickname] = effect.id
		visual_effect_instances[effect.id] = effect
		shader_cache[effect.shader_path] = load(effect.shader_path)


func _load_audio_effects() -> void:
	audio_effects.clear()
	audio_effect_instances.clear()

	for file_name: String in DirAccess.open(PATH_EFFECTS_AUDIO).get_files():
		file_name = file_name.trim_suffix(".remap")
		if !file_name.ends_with(".tres"):
			continue
		var temp: Variant = load(PATH_EFFECTS_AUDIO + file_name)
		if temp is not EffectAudio:
			continue
		var effect: EffectAudio = temp
		if audio_effect_instances.has(effect.id):
			continue
		audio_effects[effect.nickname] = effect.id
		audio_effect_instances[effect.id] = effect


#---- Syncing ----

## Update the existing effects of a project on loading so it has up-to-date
## extra stuff of the effect such as a change of has_slider, ui, overlay, ...
func sync_project_effects(clips: Dictionary, files: Dictionary) -> void:
	for clip: ClipData in clips.values():
		for i: int in clip.effects.video.size():
			var old_effect: EffectVisual = clip.effects.video[i]
			if visual_effect_instances.has(old_effect.id):
				var new_effect: EffectVisual = visual_effect_instances[old_effect.id].deep_copy()
				_apply_param_exceptions(new_effect)
				new_effect.keyframes = old_effect.keyframes.duplicate(true)
				new_effect.is_enabled = old_effect.is_enabled
				new_effect.set_default_keyframe() # Fills in missing frame 0 values for any newly introduced params.
				clip.effects.video[i] = new_effect

		for i: int in clip.effects.audio.size():
			var old_effect: EffectAudio = clip.effects.audio[i]
			if audio_effect_instances.has(old_effect.id):
				var new_effect: EffectAudio = audio_effect_instances[old_effect.id].deep_copy()
				_apply_param_exceptions(new_effect)
				new_effect.keyframes = old_effect.keyframes.duplicate(true)
				new_effect.is_enabled = old_effect.is_enabled
				new_effect.set_default_keyframe() # Fills in missing frame 0 values for any newly introduced params.
				clip.effects.audio[i] = new_effect

	var base_text_effect: EffectVisual = load(Library.EFFECT_TEXT)
	for file: FileData in files.values():
		if file.type == EditorCore.TYPE.TEXT and file.temp_file and file.temp_file.text_effect:
			var old_effect: EffectVisual = file.temp_file.text_effect
			var new_effect: EffectVisual = base_text_effect.deep_copy()
			_apply_param_exceptions(new_effect)
			new_effect.keyframes = old_effect.keyframes.duplicate(true)
			new_effect.is_enabled = old_effect.is_enabled
			new_effect.set_default_keyframe()
			file.temp_file.text_effect = new_effect


func _apply_param_exceptions(effect: Effect) -> void:
	if effect.id in param_exceptions:
		for exception: String in param_exceptions[effect.id]:
			var value: Variant = param_exceptions[effect.id][exception]
			if value is Callable:
				effect.change_default_param(exception, (value as Callable).call())
			else:
				effect.change_default_param(exception, value)


#---- Adding effects ----

func add_effect(clips: Array[ClipData], effect: Effect, is_visual: bool) -> void:
	InputManager.undo_redo.create_action("Add effect: %s" % effect.nickname)
	for clip: ClipData in clips:
		if is_visual and clip.type not in EditorCore.VISUAL_TYPES:
			continue
		if !is_visual and clip.type not in EditorCore.AUDIO_TYPES:
			continue

		var effect_copy: Effect = effect.deep_copy()
		effect_copy.keyframes = effect.keyframes.duplicate(true)
		var index: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()

		_apply_param_exceptions(effect_copy)
		effect_copy.set_default_keyframe()

		InputManager.undo_redo.add_do_method(_add_effect.bind(clip, index, effect_copy, is_visual))
		InputManager.undo_redo.add_undo_method(_remove_effect.bind(clip, index, is_visual))
	InputManager.undo_redo.commit_action()


func _add_effect(clip: ClipData, index: int, effect: Effect, is_visual: bool) -> void:
	if is_visual:
		if clip.effects.video.insert(index, effect):
			printerr("EffectsHandler: Error when inserting video effect!")
	elif clip.effects.audio.insert(index, effect):
		printerr("EffectsHandler: Error when inserting audio effect!")

	effect_added.emit(clip, index, is_visual)
	effects_updated.emit()


#---- Resetting effects ----

func reset_effect(clip: ClipData, index: int, is_visual: bool) -> void:
	if index < 0:
		return
	var effect: Effect
	var size: int = clip.effects.video.size() if is_visual else clip.effects.audio.size()
	if index >= size: return
	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]

	var old_keyframes: Dictionary = effect.keyframes.duplicate(true)

	InputManager.undo_redo.create_action("Reset effect: %s" % effect.nickname)
	InputManager.undo_redo.add_do_method(_reset_effect.bind(clip, index, is_visual))
	InputManager.undo_redo.add_undo_method(_restore_effect_keyframes.bind(clip, index, is_visual, old_keyframes))
	InputManager.undo_redo.commit_action()


func _reset_effect(clip: ClipData, index: int, is_visual: bool) -> void:
	var effect: Effect
	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]
	effect.keyframes.clear()

	_apply_param_exceptions(effect)

	effect.set_default_keyframe()
	effects_updated.emit()
	effect_values_updated.emit()


func _restore_effect_keyframes(clip: ClipData, index: int, is_visual: bool, old_keyframes: Dictionary) -> void:
	var effect: Effect
	if is_visual:
		effect = clip.effects.video[index]
	else:
		effect = clip.effects.audio[index]
	effect.keyframes = old_keyframes.duplicate(true)
	effect._cache_dirty = true
	effects_updated.emit()
	effect_values_updated.emit()


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
		if clip.effects.video.insert(new_index, clip.effects.video.pop_at(effect_index)):
			printerr("EffectsHandler: Error when inserting video effect!")
	elif clip.effects.audio.insert(new_index, clip.effects.audio.pop_at(effect_index)):
		printerr("EffectsHandler: Error when inserting audio effect!")

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

	var effect_param: EffectParam = null
	for param: EffectParam in effect.params:
		if param.id == param_id:
			effect_param = param
			break
	effect.set_default_keyframe()

	var param_keyframes: Dictionary = effect.keyframes[param_id]
	var is_keyframeable: bool = effect_param.keyframeable if effect_param else true
	var target_frame: int = 0

	# No keyframes (except 0) made, so we change main value, unless new keyframe requested.
	if (!new_keyframe and param_keyframes.size() == 1) or !is_keyframeable:
		target_frame = 0
	else:
		target_frame = EditorCore.frame_nr - clip.start

	var action_name: String = "Update %s_%s_c%d" % [effect.nickname, param_id, clip.id]
	InputManager.undo_redo.create_action(action_name, UndoRedo.MERGE_ENDS)

	if target_frame == 0 and ((!new_keyframe and param_keyframes.size() == 1) or !is_keyframeable):
		var old_value: Variant = effect.keyframes[param_id][0]
		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip, effect_index, is_visual, param_id, 0, new_value))
		InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
				clip, effect_index, is_visual, param_id, 0, old_value))
	else:
		var old_value: Variant = null
		var keyframe_exists: bool = false

		if param_keyframes.has(target_frame):
			old_value = effect.keyframes[param_id][target_frame]
			keyframe_exists = true
		elif effect_param: # New keyframe.
			old_value = effect.get_value(effect_param, target_frame)

		InputManager.undo_redo.add_do_method(_set_keyframe.bind(
				clip, effect_index, is_visual, param_id, target_frame, new_value))

		if keyframe_exists: # If keyframe already existed, we just adjust the keyframe.
			InputManager.undo_redo.add_undo_method(_set_keyframe.bind(
					clip, effect_index, is_visual, param_id, target_frame, old_value))
		else: # If the keyframe didn't exist yet, we remove the newly created one on undo.
			InputManager.undo_redo.add_undo_method(_remove_keyframe.bind(
					clip, effect_index, is_visual, param_id, target_frame))
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
		if !effect_keyframes.erase(frame_nr):
			printerr("Frame nr '%s' wasn't present in effect_keyframes!" % frame_nr)
		if effect_keyframes.is_empty() and !effect.keyframes.erase(param_id):
			printerr("Param id '%s' wasn't present in effect.keyframes!" % param_id)

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
