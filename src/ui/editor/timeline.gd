extends PanelContainer


var zoom_level := 1.0
const ZOOM_MIN := 0.2
const ZOOM_MAX := 3.0


func _ready() -> void:
	%TimelineScroll.get_node("_h_scroll").theme_type_variation = "hide_h_scroll"
	%FrameLineScroll.get_node("_h_scroll").connect(
		"value_changed",_on_frame_line_scroll)
	%TimelineScroll.get_node("_h_scroll").connect(
		"value_changed",_on_timeline_scroll)
	set_frame_line()


func set_frame_line() -> void:
	var line_string: String = ""
	var total_time = Globals.project.timeline_max_minutes
	# TODO: Display time instead of random numbers
	for x in total_time:
		line_string += "%s ... " % x
	%FrameLine.text = line_string
	await RenderingServer.frame_post_draw
	%TimelineLength.custom_minimum_size.x = %FrameLine.size.x


func _on_frame_line_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
#		print(event)
		if event is InputEventMouseMotion:
			pass # move timeline


func _on_frame_line_scroll(value) -> void:
	%TimelineScroll.get_node("_h_scroll").set_value(value)


func _on_timeline_scroll(value) -> void:
	%FrameLineScroll.get_node("_h_scroll").set_value(value)
