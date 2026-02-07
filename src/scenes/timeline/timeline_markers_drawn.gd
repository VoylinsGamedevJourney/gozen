extends Control

@onready var timeline: PanelContainer = get_parent()



func _ready() -> void:
	MarkerHandler.marker_added.connect(update_markers.unbind(1))
	MarkerHandler.marker_updated.connect(update_markers.unbind(1))
	MarkerHandler.marker_removed.connect(update_markers.unbind(1))
	MarkerHandler.marker_moving.connect(update_markers)


func _draw() -> void:
	# - Marker lines
	for frame_nr: int in MarkerHandler.markers.keys():
		var marker_data: MarkerData = MarkerHandler.markers[frame_nr]
		var pos_x: float = frame_nr * timeline.zoom

		if frame_nr == MarkerHandler.dragged_marker:
			pos_x = MarkerHandler.dragged_marker_offset

		draw_line(
				Vector2(pos_x, 0),
				Vector2(pos_x, size.y),
				Settings.get_marker_color(marker_data.type_id) * Color(1.0, 1.0, 1.0, 0.3),
				1.0)
		pos_x += 1
		draw_line(
				Vector2(pos_x, 0),
				Vector2(pos_x, size.y),
				Settings.get_marker_color(marker_data.type_id) * Color(1.0, 1.0, 1.0, 0.1),
				1.0)


func update_markers() -> void:
	queue_redraw()

