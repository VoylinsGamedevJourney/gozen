extends Control

var height: int
var width: int


func _process(delta: float) -> void:
	# Making certain that the project view stays inside of the
	# container
	# TODO: Instead of using 1920x1080 we should use project settings
	if height != get_parent().size.y or width != get_parent().size.x:
		height = get_parent().size.y
		width = get_parent().size.x
		# Always take the smallest scale:
		# We need some padding on the side so -28
		# We need more padding on y for the buttons
		var x_scale: float= float(width - 28)/1920.0
		var y_scale: float= float(height - 56)/1080.0
		if x_scale < y_scale:
			$ProjectViewContainer.scale = Vector2(x_scale,x_scale)
		else:
			$ProjectViewContainer.scale = Vector2(y_scale,y_scale)
