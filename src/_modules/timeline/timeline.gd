extends HSplitContainer

# Have 2 variables inside of ProjectManager, tracks_audio and tracks_video,
# These variables are arrays in which their index decides the position of the tracks.
# the values in this array are Dictionaries. Inside of the dictionary are the key's the actual
# start frame of that certain clip. The UI will help to make certain clips don't overlap
# 
# 

enum DIRECTION { HORIZONTAL, VERTICAL }


func _on_track_container_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if a_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if !a_event.shift_pressed:
				_scroll(DIRECTION.VERTICAL, false)


func _on_timeline_top_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if a_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if a_event.shift_pressed:
				_scroll(DIRECTION.HORIZONTAL, false)


func _on_timeline_track_container_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if a_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			_scroll(DIRECTION.HORIZONTAL if a_event.shift_pressed else DIRECTION.VERTICAL, true)


func _scroll(a_direction: DIRECTION, a_main_timeline: bool) -> void:
	if a_direction == DIRECTION.VERTICAL:
		if a_main_timeline:
			%TrackContainer.scroll_vertical = %TimelineTrackContainer.scroll_vertical
		else:
			%TimelineTrackContainer.scroll_vertical = %TrackContainer.scroll_vertical
	if a_direction == DIRECTION.HORIZONTAL:
		if a_main_timeline:
			%TimelineTop.scroll_horizontal = %TimelineTrackContainer.scroll_horizontal
		else:
			%TimelineTrackContainer.scroll_horizontal = %TimelineTop.scroll_horizontal
