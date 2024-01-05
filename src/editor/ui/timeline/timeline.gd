extends PanelContainer

enum TRACK {VIDEO, AUDIO}

var video_track_count = 0
var audio_track_count = 0


func _ready() -> void:
	# Load in video tracks
	for i in SettingsManager.get_default_video_tracks():
		add_track(TRACK.VIDEO)
	
	# Load in audio tracks
	for i in SettingsManager.get_default_audio_tracks():
		add_track(TRACK.AUDIO)


func add_track(track: TRACK):
	#region Line Bar Block 
	var line_bar_block := PanelContainer.new()
	var block_label := Label.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_child(block_label)
	line_bar_block.add_child(margin)
	line_bar_block.custom_minimum_size.y = 30
	%LineBarVBox.add_child(line_bar_block)
	#endregion
	#region Timeline Track
	
	#endregion
	
	if track == TRACK.VIDEO:
		video_track_count += 1
		block_label.text = "V%s" % video_track_count
		%LineBarVBox.move_child(line_bar_block, 0)
	elif track == TRACK.AUDIO:
		audio_track_count += 1
		block_label.text = "A%s" % audio_track_count
