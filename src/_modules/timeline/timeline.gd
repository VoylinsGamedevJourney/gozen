extends HSplitContainer

enum DIRECTION { HORIZONTAL, VERTICAL }


func _on_track_container_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if !event.shift_pressed:
				_scroll(DIRECTION.VERTICAL, false)


func _on_timeline_top_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if event.shift_pressed:
				_scroll(DIRECTION.HORIZONTAL, false)


func _on_timeline_track_container_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			_scroll(DIRECTION.HORIZONTAL if event.shift_pressed else DIRECTION.VERTICAL, true)


func _scroll(direction: DIRECTION, main_timeline: bool) -> void:
	if direction == DIRECTION.VERTICAL:
		if main_timeline:
			%TrackContainer.scroll_vertical = %TimelineTrackContainer.scroll_vertical
		else:
			%TimelineTrackContainer.scroll_vertical = %TrackContainer.scroll_vertical
	if direction == DIRECTION.HORIZONTAL:
		if main_timeline:
			%TimelineTop.scroll_horizontal = %TimelineTrackContainer.scroll_horizontal
		else:
			%TimelineTrackContainer.scroll_horizontal = %TimelineTop.scroll_horizontal
