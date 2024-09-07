extends Node




#------------------------------------------------ LOADING STUFF
# After project manager, we load in stuff which we need (shaders, scenes, ...)
# Makes the overall application faster to startup, and only takes time between
# selecting the project and the actual opening instead. So don't use `_ready()`
# in any scripts if a lot of stuff needs to be done. Instead use _ready() to
# add a loadable.

var loadables: Array[Loadable] = [
]


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


