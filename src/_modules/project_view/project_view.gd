extends Control

var playing: bool = false


func _on_play_pause_button_pressed():
	# TODO:
	# - Actually play from the timeline
	# - Update when play header reached end of timeline
	# - Shortcut control (k)
	# - Add speed up playing
	if playing:
		%PlayPauseButton.text = "Pause"
	else:
		%PlayPauseButton.text = "Play"
	playing = !playing
	print(playing)
	
