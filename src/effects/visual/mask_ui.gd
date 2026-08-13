extends EffectUI

var effect: Effect
var clip: ClipData
var is_visual: bool
var effects_panel: EffectsPanel
var hboxes: Dictionary = {}



func load_ui(_effect: Effect, _clip: ClipData, _is_visual: bool, _effects_panel: EffectsPanel) -> void:
	effect = _effect
	clip = _clip
	is_visual = _is_visual
	effects_panel = _effects_panel

	for param: EffectParam in effect.params:
		var param_hbox: HBoxContainer = effects_panel.create_effect_param_hbox(param, effect, is_visual)

		@warning_ignore("unsafe_property_access")
		if param.id == "points": param_hbox.get_node("PARAM_points").visible = false

		hboxes[param.id] = param_hbox
		add_child(param_hbox)

	var clear_button: Button = Button.new()
	clear_button.text = "Clear Mask Points"
	var _err: int = clear_button.pressed.connect(_on_clear_pressed)
	add_child(clear_button)

	_err = effects_panel.update_values.connect(_on_update_values)
	_err = tree_exited.connect(_on_tree_exit)


func _on_clear_pressed() -> void:
	@warning_ignore("unsafe_method_access")
	var old_keyframes: Dictionary = effect.keyframes.get("points", {}).duplicate(true)
	var new_keyframes: Dictionary = {}
	for keyframe: int in old_keyframes:
		new_keyframes[keyframe] = PackedVector2Array()

	if new_keyframes.is_empty():
		new_keyframes[0] = PackedVector2Array()

	InputManager.undo_redo.create_action("Clear Mask Points")
	InputManager.undo_redo.add_do_method(_apply_keyframes.bind("points", new_keyframes))
	InputManager.undo_redo.add_undo_method(_apply_keyframes.bind("points", old_keyframes))
	InputManager.undo_redo.commit_action()


func _apply_keyframes(param_id: String, keyframes: Dictionary) -> void:
	effect.keyframes[param_id] = keyframes.duplicate(true)
	effect._cache_dirty = true
	EffectsHandler.effect_values_updated.emit()


func _on_update_values(frame_nr: int) -> void:
	for param_id: String in hboxes:
		var param_hbox: HBoxContainer = hboxes[param_id]
		var param: EffectParam = _get_param(param_id)
		var reset_button: TextureButton = param_hbox.get_child(0).get_child(1)
		var param_settings: Control = param_hbox.get_child(1)
		var value: Variant = effect.get_value(param, frame_nr)

		if param_id != "points":
			effects_panel._set_param_settings_value(param_settings, value)

		reset_button.visible = not effects_panel._is_same_value(value, param.default_value)

		if param.keyframeable:
			var keyframe_button: TextureButton = param_hbox.get_node("KEYFRAME_" + param.id)
			var effect_keyframes: Dictionary = effect.keyframes[param.id]
			if effect_keyframes.has(frame_nr):
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
			else:
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)


func _get_param(id: String) -> EffectParam:
	for effect_param: EffectParam in effect.params:
		if effect_param.id == id: return effect_param
	return null


func _on_tree_exit() -> void:
	if effects_panel.update_values.is_connected(_on_update_values):
		effects_panel.update_values.disconnect(_on_update_values)
