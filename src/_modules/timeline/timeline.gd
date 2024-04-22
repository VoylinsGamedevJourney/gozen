extends HBoxContainer

# Have 2 variables inside of ProjectManager, tracks_audio and tracks_video,
# These variables are arrays in which their index decides the position of the tracks.
# the values in this array are Dictionaries. Inside of the dictionary are the key's the actual
# start frame of that certain clip. The UI will help to make certain clips don't overlap
# 
# 

enum DIRECTION { HORIZONTAL, VERTICAL }


const MINIMUM_FRAME_SIZE: float = 0.5
const MAXIMUM_FRAME_SIZE: float = 0.5


var video_track_heads: Array = []
var audio_track_heads: Array = []
var video_track_panels: Array = []
var audio_track_panels: Array = []

var time_markers: Array = []

var frame_size: float = 1.0 # How many pixels should 1 frame take up


func _ready() -> void:
	Printer.connect_error(
		ProjectManager._on_video_tracks_changed.connect(_on_video_tracks_changed))
	Printer.connect_error(
		ProjectManager._on_audio_tracks_changed.connect(_on_audio_tracks_changed))
	Printer.connect_error(
		FrameBox._on_playhead_position_changed.connect(_on_playhead_position_changed))


func _on_playhead_position_changed(a_value: float) -> void:
	%TimelinePlayhead.position.x = a_value * frame_size

#region #####################  Track management  ###############################

func _on_video_tracks_changed(a_update_video_tracks: Array) -> void:
	# Check if track needs to be added or not (check if up-to-date)
	if a_update_video_tracks.size() != video_track_panels.size():
		for l_track: Node in video_track_panels:
			l_track.queue_free()
		for l_track: Node in video_track_heads:
			l_track.queue_free()
		video_track_panels = []
		video_track_heads = []
		for track: TimelineTrack in a_update_video_tracks:
			add_video_track()


func _on_audio_tracks_changed(a_update_audio_tracks: Array) -> void:
	# Check if track needs to be added or not (check if up-to-date)
	if a_update_audio_tracks.size() != audio_track_panels.size():
		for l_track: Node in audio_track_panels:
			l_track.queue_free()
		for l_track: Node in audio_track_heads:
			l_track.queue_free()
		audio_track_panels = []
		audio_track_heads = []
		for track: TimelineTrack in a_update_audio_tracks:
			add_audio_track()


func add_video_track() -> void:
	var l_track_head: Node = preload("res://_modules/timeline/video_track_head/video_track_head.tscn").instantiate()
	var l_track_panel: Panel = Panel.new()
	
	video_track_heads.append(l_track_head)
	video_track_panels.append(l_track_panel)
	l_track_head.set_tag_label("V%s" % video_track_heads.size())
	l_track_panel.custom_minimum_size = Vector2i(6000,26) # TODO: Set better minimum
	l_track_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	%TrackHeadVBox.add_child(l_track_head)
	%TrackHeadVBox.move_child(l_track_head, 0)
	%TimelineTrackVBox.add_child(l_track_panel)
	%TimelineTrackVBox.move_child(l_track_panel, 0)


func add_audio_track() -> void:
	var l_track_head: Node = preload("res://_modules/timeline/audio_track_head/audio_track_head.tscn").instantiate()
	var l_track_panel: Panel = Panel.new()
	
	audio_track_heads.append(l_track_head)
	audio_track_panels.append(l_track_panel)
	l_track_head.set_tag_label("A%s" % video_track_heads.size())
	l_track_panel.custom_minimum_size = Vector2i(600,26)
	l_track_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	%TrackHeadVBox.add_child(l_track_head)
	%TimelineTrackVBox.add_child(l_track_panel)


func remove_track(_a_video: bool) -> void:
	pass

#endregion
#region #####################  Scrolling  ######################################

func _on_track_container_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if a_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if !a_event.shift_pressed:
				_scroll(DIRECTION.VERTICAL, false)


func _on_timeline_top_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if a_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			if a_event.shift_pressed:
				_scroll(DIRECTION.HORIZONTAL, false)


func _on_timeline_track_container_gui_input(a_event: InputEvent) -> void:
	if a_event is InputEventMouseButton:
		if a_event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
			_scroll(DIRECTION.HORIZONTAL if a_event.shift_pressed else DIRECTION.VERTICAL, true)


func _scroll(a_direction: DIRECTION, a_main_timeline: bool) -> void:
	if a_direction == DIRECTION.VERTICAL:
		if a_main_timeline:
			%TrackContainer.scroll_vertical = %TimelineTrackContainer.scroll_vertical
		else:
			%TimelineTrackContainer.scroll_vertical = %TrackContainer.scroll_vertical
	if a_direction == DIRECTION.HORIZONTAL:
		if a_main_timeline:
			%TimelineTop.scroll_horizontal = %TimelineTrackContainer.scroll_horizontal
		else:
			%TimelineTrackContainer.scroll_horizontal = %TimelineTop.scroll_horizontal

#endregion


func _on_timeline_top_panel_resized() -> void:
	return # Causing lag at the moment
	#var l_separation: int = %TimelineTopPanel.size.x / frame_size
	#for l_child: Node in %TimelineTopPanel.get_children():
	#	l_child.queue_free()
	#for l_i: int in l_separation:
	#	var l_marker: Node = preload("res://_modules/timeline/time_marker/time_marker.tscn").instantiate()
	#	time_markers.append(l_marker)
	#	l_marker.custom_minimum_size = Vector2i(l_separation, 0)
	#	l_marker.position.x = l_i * l_separation
	#	l_marker._update_marker(frame_size)
	#	%TimelineTopPanel.add_child(l_marker)


func _on_timeline_panel_resized() -> void:
	%TimelineTopPanel.custom_minimum_size.x = %TimelineTrackVBox.size.x
	_on_timeline_top_panel_resized()
