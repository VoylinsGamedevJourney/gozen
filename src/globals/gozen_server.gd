extends Node


#------------------------------------------------ ERROR HANDLING
var err: int = 0


func connect_err(a_errors: PackedInt64Array, a_string: String) -> void:
	for a_error: int in a_errors:
		err += a_error

	if err:
		printerr(a_string)

	err = 0
	

#------------------------------------------------ LOADING STUFF
# After project manager, we load in stuff which we need (shaders, scenes, ...)
# Makes the overall application faster to startup, and only takes time between
# selecting the project and the actual opening instead. So don't use `_ready()`
# in any scripts if a lot of stuff needs to be done. Instead use _ready() to
# add a loadable.
#
# After loadables is for the editor UI itself.

var loadables: Array[Loadable] = []
var after_loadables: Array[Loadable] = []
var loaded: bool = false



func add_loadable(a_loadable: Loadable) -> void:
	loadables.append(a_loadable)


func add_loadables(a_loadables: Array[Loadable]) -> void:
	loadables.append_array(a_loadables)


func add_loadable_to_front(a_loadable: Loadable) -> void:
	loadables.push_front(a_loadable)


func add_loadables_to_front(a_loadables: Array[Loadable]) -> void:
	a_loadables.reverse()
	for l_loadable: Loadable in a_loadables:
		loadables.push_front(l_loadable)


func add_after_loadable(a_loadable: Loadable) -> void:
	if loaded:
		a_loadable.function.call()
	else:
		after_loadables.append(a_loadable)


func add_after_loadables(a_loadables: Array[Loadable]) -> void:
	if loaded:
		for l_loadable: Loadable in a_loadables:
			l_loadable.function.call()
	else:
		after_loadables.append_array(a_loadables)


#------------------------------------------------ STATUS INDICATOR
# TODO: DisplayServer.create_status_indicator()
# Give the status indicator quick shortcuts to start rendering and to see
# rendering progress. Other then that we could have a save button, but not yet
# an idea for any other things so this will require a bit more research. There
# has to be a function to disable the status indicator.


#------------------------------------------------ ICON CHANGER
# TODO: DisplayServer.set_icon() # Could be good to indicate if rendering or not
# This could be helpful for people with non tiling window managers, mainly to
# indicate if is charging or not. There should be a setting to disable this
# icon changer.


#------------------------------------------------ TRACK HANDLING
func add_track() -> void:
	err += audio_players.resize(Project.tracks.size())
	err += current_clips.resize(Project.tracks.size())
	if err:
		printerr("Couldn't resize array's in GoZen Server!")
		err = 0

	audio_players.append(AudioStreamPlayer.new())	
	add_child(audio_players[-1])

	Project._add_track()


func remove_track(a_id: int) -> void:
	err += audio_players.resize(Project.tracks.size())
	err += current_clips.resize(Project.tracks.size())
	if err:
		printerr("Couldn't resize array's in GoZen Server!")
		err = 0

	Project._remove_track(a_id)


func add_clip(a_file_id: int, a_pts: int, a_track_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._add_clip(a_file_id, a_pts, a_track_id)


#------------------------------------------------ CLIP HANDLING

var selected_clips: PackedInt64Array = []


func remove_clip(a_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._remove_clip(a_id)


func resize_clip(a_id: int, a_duration: int, a_left: bool) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._resize_clip(a_id, a_duration, a_left)


#------------------------------------------------ EFFECTS HANDLING

signal _open_file_effects(file_id: int)
signal _open_clip_effects(clip_id: int)


func open_file_effects(a_file_id: int) -> void:
	_open_file_effects.emit(a_file_id)


func open_clip_effects(a_clip_id: int) -> void:
	_open_clip_effects.emit(a_clip_id)


#------------------------------------------------ PLAYBACK HANDLING

signal _on_playhead_moving(value: bool)

signal _on_current_frame_changed(frame: int)
signal _update_frame_forced

signal _playback_paused
signal _playback_started


var is_playhead_moving: bool = false
var is_playing: bool = false
var was_playing: bool = false
var is_dragging: bool = false
var was_dragging: bool = false
var is_clip_moving: bool = false

var current_frame: int = 0
var _skipped_frames: int = 0

var time_elapsed: float = 0.

var frames: Array[Texture2D] = []

var current_clips: Array[ClipData] = []
var audio_players: Array[AudioStreamPlayer] = []



func set_playhead_moving(a_value: bool) -> void:
	is_playhead_moving = a_value
	_on_playhead_moving.emit(a_value)


func _process(a_delta: float) -> void:
	if is_playhead_moving:
		# For increasing performance whilst dragging
		if !is_dragging and was_dragging:
			is_dragging = was_dragging
			was_playing = GoZenServer.is_playing
			GoZenServer.is_playing = false
			for l_player: AudioStreamPlayer in audio_players:
				l_player.set_stream_paused(true)

		#set_frame_forced()

		if !was_dragging:
			is_dragging = false
			GoZenServer.is_playing = was_playing
			for l_player: AudioStreamPlayer in audio_players:
				l_player.set_stream_paused(!GoZenServer.is_playing)


	if !is_playing:
		return
	time_elapsed += a_delta
	print("playing")

	if time_elapsed < 1. / Project.framerate:
		return

	while time_elapsed >= 1. / Project.framerate:
		time_elapsed -= 1. / Project.framerate
		current_frame += 1
		_skipped_frames += 1
	
	if current_frame >= Project._end_pts:
		if is_dragging:
			return
	
		is_playing = false
		_playback_paused.emit()
	else:
		while _skipped_frames != 1:
			next_frame(true)
			_skipped_frames -= 1

		next_frame(false)
		

func _on_play_pressed() -> void:
	# Don't play past end frame
	if current_frame >= Project._end_pts:
		print("Reached end of timeline")
		return

	is_playing = !is_playing
	if is_playing:
		_playback_started.emit()
	else:
		_playback_paused.emit()


func next_frame(a_skip_signal: bool) -> void:
	if !a_skip_signal:
		_on_current_frame_changed.emit(current_frame)	


func _set_frame(a_frame_nr: int = current_frame, a_force: bool = false) -> void:
	if frames.size() != Project.tracks.size():
		err += frames.resize(Project.tracks.size())
		if err:
			printerr("Couldn't resize 'frames' in GoZenServer!")
			err = 0

	if current_frame == a_frame_nr and !a_force:
		return
	
	current_frame = a_frame_nr

	for i: int in Project.tracks.size():
		if current_frame in Project._tracks_data[i]:
			# Check if clip is loaded
			if current_clips[i] == null: # Find which clip is there
				current_clips[i] = _get_clip_from_raw(i)
				audio_players[i].stream = null
			if current_clips[i] == null:
				return

			match Project.files[current_clips[i].file_id].type:
				File.VIDEO: _set_video_clip_frame(i)
				File.AUDIO: _set_audio_clip_frame(i)
				File.IMAGE: _set_image_clip_frame(i)
				File.COLOR: _set_color_clip_frame(i)
		else:
			frames[i] = null
			audio_players[i].stream = null
			current_clips[i] = null

	
func _get_clip_from_raw(a_track_id: int) -> ClipData:
	if current_frame in Project.tracks[a_track_id]:
		return Project.tracks[a_track_id][current_frame]
	elif current_frame < Project.tracks[a_track_id].keys().min():
		return null

	for i: int in current_frame:
		if current_frame - i in Project.tracks[a_track_id]:
			var l_clip_data: ClipData = Project.clips[Project.tracks[a_track_id][current_frame - i]]

			if current_frame < l_clip_data.get_end_pts():
				return l_clip_data

	return null
	

func _set_video_clip_frame(a_track_id: int, a_frame_nr: int = current_frame) -> void:
	_set_audio_clip_frame(a_track_id, true)


func _set_audio_clip_frame(a_track_id: int, a_video: bool = false, a_frame_nr: int = current_frame) -> void:
	pass


func _set_image_clip_frame(a_track_id: int) -> void:
	pass


func _set_color_clip_frame(a_track_id: int) -> void:
	pass


func update_frame_forced() -> void:
	_update_frame_forced.emit()
