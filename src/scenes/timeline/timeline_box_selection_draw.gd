extends Control

const COLOR_BOX_SELECT_FILL: Color = Color(0.65, 0.1, 0.95, 0.2)
const COLOR_BOX_SELECT_BORDER: Color = Color(0.65, 0.1, 0.95, 0.6)


@onready var timeline: PanelContainer = get_parent()



func _draw() -> void:
	if timeline.state == timeline.STATE.BOX_SELECTING:
		var rect: Rect2 = Rect2(
				timeline.box_select_start,
				timeline.box_select_end - timeline.box_select_start).abs()
		draw_rect(rect, COLOR_BOX_SELECT_FILL)
		draw_rect(rect, COLOR_BOX_SELECT_BORDER, false, 1.0)


func update_box() -> void:
	queue_redraw()
