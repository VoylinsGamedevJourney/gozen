extends Control



func _ready() -> void:
	# Showing Startup Screen
	add_child(preload("uid://bqlcn30hs8qp5").instantiate())
	Editor.viewport = %ProjectViewSubViewport

