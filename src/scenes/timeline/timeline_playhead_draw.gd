extends Control

@onready var timeline: PanelContainer = get_parent()


func _ready() -> void:
	EditorCore.frame_changed.connect(queue_redraw)


func _draw() -> void:
	var playhead_pos: float = EditorCore.frame_nr * timeline.zoom
	draw_line(
			Vector2(playhead_pos, 0), Vector2(playhead_pos, size.y),
			timeline.PLAYHEAD_COLOR, timeline.PLAYHEAD_WIDTH)


func update_playhead() -> void:
	queue_redraw()
