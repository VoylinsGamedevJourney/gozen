extends Control

@onready var timeline: PanelContainer = get_parent()



func _ready() -> void:
	EditorCore.frame_changed.connect(queue_redraw)


func _draw() -> void:
	for i: int in TrackHandler.tracks.size() - 1:
		var y: int = timeline.TRACK_TOTAL_SIZE * (i + 1)

		draw_dashed_line(
				Vector2(0, y), Vector2(size.x, y),
				timeline.TRACK_LINE_COLOR, timeline.TRACK_LINE_WIDTH)


func update_track_lines() -> void:
	queue_redraw()

