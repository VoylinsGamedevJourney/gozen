extends HBoxContainer


func _update_marker(a_frame_size: float) -> void:
	$TimeMarkerLabel.text = FrameBox.get_timestamp(int(position.x * a_frame_size))
