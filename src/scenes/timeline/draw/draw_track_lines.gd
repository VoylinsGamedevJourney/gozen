extends Control

const TRACK_LINE_COLOR: Color = Color.DIM_GRAY



func _draw() -> void:
	var scroll_container: ScrollContainer = get_parent().get_parent()
	var scroll_start: float = Timeline.scroll_x
	var scroll_end: float = scroll_start + scroll_container.size.x
	for i: int in TrackLogic.tracks.size() - 1:
		var y_pos: float = Timeline.track_total_size * (i + 1)
		draw_dashed_line(
				Vector2(scroll_start, y_pos), Vector2(scroll_end, y_pos),
				TRACK_LINE_COLOR, Timeline.TRACK_LINE_WIDTH)
