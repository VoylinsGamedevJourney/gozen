extends MarginContainer

var effect: Effect



func setup(_effect: Effect, _clip: ClipData, _is_visual: bool) -> void:
	effect = _effect
	var button: Button = Button.new()
	button.text = "Clear Mask Points"
	button.pressed.connect(_on_clear_pressed)
	add_child(button)


func _on_clear_pressed() -> void:
	var old_keyframes: Dictionary = (effect.keyframes.get("points", {}) as Dictionary).duplicate(true)
	var new_keyframes: Dictionary = {}
	for keyframe: int in old_keyframes:
		new_keyframes[keyframe] = PackedVector2Array()

	if new_keyframes.is_empty():
		new_keyframes[0] = PackedVector2Array()

	UndoManager.create_action("Clear Mask Points")
	UndoManager.add_do(_apply_keyframes.bind("points", new_keyframes))
	UndoManager.add_undo(_apply_keyframes.bind("points", old_keyframes))
	UndoManager.commit_action()


func _apply_keyframes(param_id: String, keyframes: Dictionary) -> void:
	effect.keyframes[param_id] = keyframes.duplicate(true)
	effect._cache_dirty = true
	EffectsHandler.effects_updated.emit()
