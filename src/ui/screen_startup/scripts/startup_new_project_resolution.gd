extends VBoxContainer

var landscape := true


func switch_landscape(value: bool) -> void:
	landscape = value
	set_quality(Vector2i(
		%XSpinBox.value if %XSpinBox.value > %YSpinBox.value else %YSpinBox.value,
		%YSpinBox.value if %XSpinBox.value > %YSpinBox.value else %XSpinBox.value))


func set_quality(resolution: Vector2i):
	%XSpinBox.value = resolution.x if landscape else resolution.y
	%YSpinBox.value = resolution.y if landscape else resolution.x
