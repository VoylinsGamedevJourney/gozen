extends ColorRect

var file_id: int = -1: set = set_file_id
var wave_offset: float = 0.0: set = set_wave_offset


func set_file_id(new_file_id: int) -> void:
	file_id = new_file_id
	queue_redraw()


func set_wave_offset(new_wave_offset: float) -> void:
	wave_offset = new_wave_offset
	queue_redraw()


func _draw() -> void:
	# TODO: Draw wave and take in mind the offset
	pass
