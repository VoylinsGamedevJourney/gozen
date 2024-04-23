extends Panel


var timeline_node: Control
var track_id: int



func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	print("test")
	return true


func _drop_data(_at_position: Vector2, a_data: Variant) -> void:
	print(a_data)
