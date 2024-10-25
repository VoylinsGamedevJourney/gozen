extends Node
# After project manager, we load in stuff which we need (shaders, scenes, ...)
# Makes the overall application faster to startup, and only takes time between
# selecting the project and the actual opening instead. So don't use `_ready()`
# in any scripts if a lot of stuff needs to be done. Instead use _ready() to
# add a loadable.
#
# After loadables is for the editor UI itself which needs the core editor parts to be loaded before it could load.


var loaded: bool = false

var loadables: Array[Loadable] = []
var after_loadables: Array[Loadable] = []



func append(a_info: String, a_func: Callable) -> void:
	loadables.append(Loadable.new(a_info, a_func))


func append_to_front(a_info: String, a_func: Callable) -> void:
	loadables.push_front(Loadable.new(a_info, a_func))


func append_after(a_info: String, a_func: Callable) -> void:
	after_loadables.append(Loadable.new(a_info, a_func))


func append_after_to_front(a_info: String, a_func: Callable) -> void:
	after_loadables.push_front(Loadable.new(a_info, a_func))



class Loadable:
	var info_text: String
	var function: Callable


	func _init(a_info_text: String, a_func: Callable) -> void:
		info_text = a_info_text
		function = a_func
