extends Node
# After project manager, we load in stuff which we need (shaders, scenes, ...)
# Makes the overall application faster to startup, and only takes time between
# selecting the project and the actual opening instead. So don't use `_ready()`
# in any scripts if a lot of stuff needs to be done. Instead use _ready() to
# add a loadable.
#
# After loadables is for the editor UI itself which needs the core editor parts to be loaded before it could load.

const MINIMUM_DELAY: float = 0.3
const CHECKPOINT_DELAY: float = 0.3


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


func execute(a_label: Label) -> void:
	var l_timer: Timer = Timer.new()
	add_child(l_timer)

	for l_loadable: Loadable in loadables:
		a_label.text = "%s..." % l_loadable.info_text
		await _execute(l_timer, l_loadable.function)

	l_timer.start(CHECKPOINT_DELAY)
	await l_timer.timeout

	for l_loadable: Loadable in after_loadables:
		a_label.text = "%s..." % l_loadable.info_text
		await _execute(l_timer, l_loadable.function)

	a_label.text = "Finalizing ..."
	l_timer.start(CHECKPOINT_DELAY)
	await l_timer.timeout

	# Cleanup
	l_timer.queue_free()
	loadables = []
	after_loadables = []
	loaded = true


func _execute(a_timer: Timer, a_func: Callable) -> void:
	a_timer.start(MINIMUM_DELAY)
	await a_func.call()

	if !a_timer.is_stopped():
		await a_timer.timeout


class Loadable:
	var info_text: String
	var function: Callable


	func _init(a_info_text: String, a_func: Callable) -> void:
		info_text = a_info_text
		function = a_func

