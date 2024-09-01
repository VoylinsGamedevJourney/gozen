extends Node

# TODO: DisplayServer.create_status_indicator()
# TODO: DisplayServer.set_icon() # Could be good to indicate if rendering or not



#------------------------------------------------ LOADING STUFF
# After project manager, we load in stuff which we need (shaders, scenes, ...)
# Makes the overall application faster to startup, and only takes time between
# selecting the project and the actual opening instead. So don't use `_ready()`
# in any scripts if a lot of stuff needs to be done. Instead use _ready() to
# add a loadable.

var loadables: Array[Loadable] = []


func add_loadable(a_loadable: Loadable) -> void:
	loadables.append(a_loadable)

