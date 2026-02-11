extends Control

@onready var timeline: PanelContainer = get_parent()


func _ready() -> void:
	Project.markers.added.connect(update_markers.unbind(1))
	Project.markers.updated.connect(update_markers.unbind(1))
	Project.markers.removed.connect(update_markers.unbind(1))
	Project.markers.moving.connect(update_markers)


func _draw() -> void:
	for index: int in Project.markers.get_indexes():
		var color: Color = Settings.get_marker_color(Project.markers.get_type(index))
		var frame_nr: int = Project.markers.get_frame(index)
		var pos_x: float = frame_nr * timeline.zoom
		if frame_nr == Project.markers.dragged_marker:
			pos_x = Project.markers.dragged_marker_offset

		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.3), 1.0)
		pos_x += 1 # We want a double line with the second one slightly lighter.
		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), color * Color(1.0, 1.0, 1.0, 0.1), 1.0)


func update_markers() -> void: queue_redraw()
