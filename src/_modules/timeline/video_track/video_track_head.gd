extends HBoxContainer

var locked: bool = false
var showing: bool = true


func set_tag_label(a_tag: String) -> void:
	$TrackNameLabel.text = a_tag


func _on_lock_button_pressed() -> void:
	if locked:
		$LockButton.icon = preload("res://assets/icons/lock_open.png")
	else:
		$LockButton.icon = preload("res://assets/icons/lock.png")
	locked = !locked


func _on_hide_button_pressed() -> void:
	if showing:
		$HideButton.icon = preload("res://assets/icons/visibility_off.png")
	else:
		$HideButton.icon = preload("res://assets/icons/visibility.png")
	showing = !showing
