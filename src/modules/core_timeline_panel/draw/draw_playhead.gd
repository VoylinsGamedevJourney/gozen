extends Control

const PLAYHEAD_WIDTH: int = 2



func _draw() -> void:
	var zoom: float = Timeline.zoom
	var playhead_pos: float = EditorCore.visual_frame_nr * zoom
	var playhead_color: Color = get_theme_color("playhead", "Timeline")

	var frame_rect_color: Color = playhead_color
	frame_rect_color.a *= 0.1

	draw_rect(Rect2(playhead_pos, 0, zoom, size.y), frame_rect_color)
	draw_line(
			Vector2(playhead_pos, 0), Vector2(playhead_pos, size.y),
			playhead_color, PLAYHEAD_WIDTH)
