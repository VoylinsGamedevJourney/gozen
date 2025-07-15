extends PanelContainer


enum TIME_STATE { SECOND, FIVE_SECOND, TEN_SECOND, HALF_MINUTE, MINUTE }
enum FRAME_STATE { SHOW_ALL, SHOW_HALF, SHOW_MINIMUM, HIDE}


@onready var default_font: Font = preload("uid://bnubhr3uus8gt")

var time_state: TIME_STATE = TIME_STATE.SECOND
var frame_state: FRAME_STATE = FRAME_STATE.SHOW_ALL

var total_frames: int = 0
var total_seconds: int = 0
var total_minutes: int = 0



func _on_gui_input(event: InputEvent) -> void:
	Timeline.instance._input(event)
	Timeline.instance._on_main_gui_input(event)


func _on_project_ready() -> void:
	_on_timeline_end_update(Project.get_timeline_end())


func _on_timeline_end_update(new_end: int) -> void:
	var framerate: float = Project.get_framerate() # The size between each frame marker.

	total_frames = new_end + Timeline.TIMELINE_PADDING
	total_seconds = ceili(total_frames / framerate)
	total_minutes = ceili(total_seconds / 60.0)

	queue_redraw()


func _on_timeline_zoom_changed() -> void:
	var zoom: float = Project.get_zoom()

	custom_minimum_size.x = Timeline.instance.main_control.size.x
	size.x = Timeline.instance.main_control.size.x

	if zoom > 4.0:
		frame_state = FRAME_STATE.SHOW_ALL
	elif zoom < 1.0:
		frame_state = FRAME_STATE.HIDE
	elif zoom < 1.8:
		frame_state = FRAME_STATE.SHOW_MINIMUM
	else:
		frame_state = FRAME_STATE.SHOW_HALF

	if zoom > 3.0:
		time_state = TIME_STATE.SECOND
	elif zoom > 1.0:
		time_state = TIME_STATE.FIVE_SECOND
	elif zoom > 0.5:
		time_state = TIME_STATE.TEN_SECOND
	elif zoom > 0.1:
		time_state = TIME_STATE.HALF_MINUTE
	else:
		time_state = TIME_STATE.MINUTE
		
	queue_redraw()


func _draw() -> void:
	if Project.data == null:
		return

	var framerate: float = Project.get_framerate()
	var zoom: float = Project.get_zoom()

	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color.DIM_GRAY, 2)

	if frame_state != FRAME_STATE.HIDE:
		var total: int = total_frames
		var mod: int = 1

		if frame_state == FRAME_STATE.SHOW_HALF:
			mod = 2
		elif frame_state == FRAME_STATE.SHOW_MINIMUM:
			mod = 4

		total /= mod

		for i: int in total:
			var x_pos: float = (i * zoom * mod) + 1

			draw_line(Vector2(x_pos, size.y / 1.3), Vector2(x_pos, size.y - 1), Color.DIM_GRAY)

	for i: int in total_seconds:
		var x_pos: float = i * framerate * zoom
		var draw_time: bool = true

		if time_state == TIME_STATE.FIVE_SECOND and i % 5:
			draw_time = false
		elif time_state == TIME_STATE.TEN_SECOND and i % 10:
			draw_time = false
		elif time_state == TIME_STATE.MINUTE and i % 60:
			draw_time = false
		elif time_state == TIME_STATE.HALF_MINUTE and i % 30:
			draw_time = false

		if frame_state == FRAME_STATE.HIDE:
			if draw_time:
				draw_line(Vector2(x_pos, size.y / 1.5), Vector2(x_pos, size.y - 1), Color.DIM_GRAY, 2)
			else:
				draw_line(Vector2(x_pos, size.y / 1.3), Vector2(x_pos, size.y - 1), Color.DIM_GRAY, 1)
		else:
			draw_line(Vector2(x_pos, size.y / 2.3), Vector2(x_pos, size.y - 1), Color.DIM_GRAY, 2)

		if draw_time:
			draw_string(default_font, Vector2(x_pos + 3, size.y / 2 + 2), Toolbox.format_time_str(i, true), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.DIM_GRAY)

	for i: int in total_minutes:
		var x_pos: float = i * framerate * 60 * zoom

		draw_line(Vector2(x_pos, size.y), Vector2(x_pos, size.y - 1), Color.DIM_GRAY, 2)

