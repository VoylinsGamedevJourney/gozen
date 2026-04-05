extends Control



func _draw() -> void:
	var scroll_container: ScrollContainer = get_parent().get_parent()
	var zoom: float = Timeline.zoom
	var scroll_start: float = Timeline.scroll_x
	var scroll_end: float = scroll_start + scroll_container.size.x

	var dragged_marker: MarkerData = MarkerLogic.dragged_marker
	for marker: MarkerData in Project.data.markers:
		var frame_nr: int = marker.frame_nr
		var color: Color = Settings.get_marker_color(marker.type)
		var pos_x: float = frame_nr * zoom
		if dragged_marker and frame_nr == dragged_marker.frame_nr:
			pos_x = MarkerLogic.dragged_marker_offset
		if pos_x < scroll_start - 10 or pos_x > scroll_end + 10:
			continue

		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.3), 1.0)
		pos_x += 1 # We want a double line with the second one slightly lighter.
		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.1), 1.0)
