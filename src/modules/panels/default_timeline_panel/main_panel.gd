extends Control


@export var timeline_module: Control


func _can_drop_data(a_pos: Vector2, a_data: Variant) -> bool:
	if a_data is Draggable:
		return timeline_module.call("_can_drop_clip_data", a_pos, a_data)
	else:
		return false

