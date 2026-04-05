extends Control

const PLAYHEAD_WIDTH: int = 2
const PLAYHEAD_COLOR: Color = Color(0.4, 0.4, 0.4)



func _draw() -> void:
	var zoom: float = Timeline.zoom
	var playhead_pos: float
	if Timeline.state == Timeline.STATE.SCRUBBING:
		playhead_pos = get_local_mouse_position().x
	else:
		playhead_pos = EditorCore.visual_frame_nr * zoom

	draw_line(
			Vector2(playhead_pos, 0), Vector2(playhead_pos, size.y),
			PLAYHEAD_COLOR, PLAYHEAD_WIDTH)
