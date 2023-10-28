extends PanelContainer


func _ready() -> void:
	# TODO: Build settings
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
