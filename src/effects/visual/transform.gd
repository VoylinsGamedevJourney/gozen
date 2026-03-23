extends EffectUI




func get_ui(_update_signal: Signal) -> Control:
	# First we have the position on top.
	# Followed by the scale with a toggle to maintain the current aspect ratio.
	# Then we should have a line with buttons for aligning, a divider, a button to return to the original size and position.
	# Followed by the pivot settings.
	# Followed by rotation and alpha. For rotation I'd prefer to use a slider.
	return Control.new()
