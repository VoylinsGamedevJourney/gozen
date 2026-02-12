extends Control

@onready var timeline: PanelContainer = get_parent()




func update_track_lines() -> void:
	queue_redraw()
