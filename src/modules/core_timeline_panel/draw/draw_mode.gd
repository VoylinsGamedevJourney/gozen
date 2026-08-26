extends Control

var mouse_pos_x: float = 0.0



func _draw() -> void:
	if Timeline.current_state == Timeline.State.SPLIT:
		var fade_pos: float = mouse_pos_x + 1
		draw_line(Vector2(mouse_pos_x, 0), Vector2(mouse_pos_x, size.y), get_theme_color("split", "Timeline"))
		draw_line(Vector2(fade_pos, 0), Vector2(fade_pos, size.y), get_theme_color("split_fade", "Timeline"))
