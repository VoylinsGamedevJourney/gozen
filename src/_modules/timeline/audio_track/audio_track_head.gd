extends HBoxContainer

var locked: bool = false
var muted: bool = false


func set_tag_label(a_tag: String) -> void:
	$TrackNameLabel.text = a_tag


func _on_lock_button_pressed() -> void:
	if locked:
		$LockButton.icon = preload("res://assets/icons/lock_open.png")
	else:
		$LockButton.icon = preload("res://assets/icons/lock.png")
	locked = !locked


func _on_mute_button_pressed() -> void:
	if muted:
		$MuteButton.icon = preload("res://assets/icons/music_note.png")
	else:
		$MuteButton.icon = preload("res://assets/icons/music_off.png")
	muted = !muted
