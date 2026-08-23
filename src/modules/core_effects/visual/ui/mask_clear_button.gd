extends MarginContainer

var effect: Effect



func setup(_effect: Effect, _clip: ClipData, _is_visual: bool) -> void:
	effect = _effect
	var button: Button = Button.new()
	button.text = "Clear Mask Points"
	if button.pressed.connect(_on_clear_pressed): Print.stack_connect()
	add_child(button)


func _on_clear_pressed() -> void:
	var old_keyframes: Dictionary = (effect.keyframes.get("points", {}) as Dictionary).duplicate(true)
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
