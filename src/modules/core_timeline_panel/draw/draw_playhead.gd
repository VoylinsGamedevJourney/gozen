extends Control

const PLAYHEAD_WIDTH: int = 2



func _draw() -> void:
	var zoom: float = Timeline.zoom
	var playhead_pos: float = EditorCore.visual_frame_nr * zoom

	draw_line(
			Vector2(playhead_pos, 0), Vector2(playhead_pos, size.y),
			get_theme_color("playhead", "Timeline"), PLAYHEAD_WIDTH)
