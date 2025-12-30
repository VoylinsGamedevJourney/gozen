class_name ResizeClipRequest
extends RefCounted


var clip_id: int = 0
var resize_amount: int = 0
var from_end: bool = false



func _init(id: int, amount: int, end: bool) -> void:
	clip_id = id
	resize_amount = amount
	from_end = end

