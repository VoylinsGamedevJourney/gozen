extends Control

const COLOR_SPLIT: Color = Color(1,0,0,0.6)
const COLOR_SPLIT_FADE: Color = Color(1,0,0,0.3)



func _draw() -> void:
	var pos_x: float = get_local_mouse_position().x
	if Timeline.state == Timeline.STATE.SPLIT:
		var fade_pos: float = pos_x + 1
		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), COLOR_SPLIT)
		draw_line(Vector2(fade_pos, 0), Vector2(fade_pos, size.y), COLOR_SPLIT_FADE)
