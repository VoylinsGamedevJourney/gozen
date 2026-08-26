extends Control


func _draw() -> void:
	if Timeline.current_state == Timeline.State.BOX_SELECTING:
		var rect: Rect2 = Rect2(Timeline.box_select_start, Timeline.box_select_end - Timeline.box_select_start).abs()
		draw_rect(rect, get_theme_color("box_select_fill", "Timeline"))
		draw_rect(rect, get_theme_color("box_select_border", "Timeline"), false, 1.0)
