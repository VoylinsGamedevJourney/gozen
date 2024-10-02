extends Node
# TODO: Check if multiple files were selected to drag in the timeline


func _pressed() -> void:
	GoZenServer._open_file_effects.emit(name.to_int())


func _get_drag_data(_pos: Vector2i) -> Variant:
	return Draggable.new(Draggable.NEW_CLIP, [name.to_int()])

