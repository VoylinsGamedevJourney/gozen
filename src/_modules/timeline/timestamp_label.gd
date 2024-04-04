extends Label


func _ready():
	FrameBox._on_playhead_position_changed.connect(_update_timestamp)
	_update_timestamp()


func _update_timestamp(_value: int = 0) -> void:
	text = FrameBox.get_timestamp()
