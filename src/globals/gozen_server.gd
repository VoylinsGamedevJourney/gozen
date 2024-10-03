extends Node




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
	# TODO: Add to action manager so we can undo this change
	Project._add_track()


func remove_track(a_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._remove_track(a_id)


func add_clip(a_file_id: int, a_pts: int, a_track_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._add_clip(a_file_id, a_pts, a_track_id)


#------------------------------------------------ CLIP HANDLING

signal _on_clip_moving(value: bool)


var selected_clips: PackedInt64Array = []
var clip_moving: bool = false: set = set_clip_moving


func set_clip_moving(a_value: bool) -> void:
	clip_moving = a_value
	_on_clip_moving.emit(a_value)


func move_clip(a_clip_id: int, a_new_pts: int, a_new_track_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._move_clip(a_clip_id, a_new_pts, a_new_track_id)


func remove_clip(a_id: int) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._remove_clip(a_id)


func resize_clip(a_id: int, a_duration: int, a_left: bool) -> void:
	# TODO: Add to action manager so we can undo this change
	Project._resize_clip(a_id, a_duration, a_left)


#------------------------------------------------ PLAYHEAD HANDLING
# All the playhead handling happens here for all nodes, as this info is needed
# for the view of the project.

signal _on_playhead_moving(value: bool)


var playhead_moving: bool = false: set = set_playhead_moving


func set_playhead_moving(a_value: bool) -> void:
	playhead_moving = a_value
	_on_playhead_moving.emit(a_value)


#------------------------------------------------ EFFECTS HANDLING

signal _open_file_effects(file_id: int)
signal _open_clip_effects(clip_id: int)


func open_file_effects(a_file_id: int) -> void:
	_open_file_effects.emit(a_file_id)
 

func open_clip_effects(a_clip_id: int) -> void:
	_open_clip_effects.emit(a_clip_id)
 
