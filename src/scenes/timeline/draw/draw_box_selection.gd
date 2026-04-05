extends Control

const COLOR_BOX_SELECT_FILL: Color = Color(0.65, 0.1, 0.95, 0.2)
const COLOR_BOX_SELECT_BORDER: Color = Color(0.65, 0.1, 0.95, 0.6)



func _draw() -> void:
	if Timeline.state == Timeline.STATE.BOX_SELECTING:
		var rect: Rect2 = Rect2(Timeline.box_select_start, Timeline.box_select_end - Timeline.box_select_start).abs()
		draw_rect(rect, COLOR_BOX_SELECT_FILL)
		draw_rect(rect, COLOR_BOX_SELECT_BORDER, false, 1.0)
