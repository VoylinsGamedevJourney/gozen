extends Node

const PATH := "user://module_settings"
const PATH_MODULE := "res://modules/|/%s/|.tscn"

var modules := {
	"startup": "default",
	"editor": "default",
	"command_bar": "default",
	"top_bar": "default",
	"status_bar": "default", }


func _ready() -> void:
	if FileAccess.file_exists(PATH): _load()
	else: _save()


func _save() -> void:
	FileManager.save_dic(modules, PATH)


func _load() -> void:
	var data := FileManager.load_dic(PATH)
	# TODO: Check for custom modules and if they still exist or not.
	# We could implement custom modules by loading up the selected custom
	# modules in a dictionary called custom_modules. Inside of this dictionary
	# we have each entry be like this:
	# {key(module name): custom_module_packedscene}
	# Having the custom modules being loaded at startup makes the startup time
	# slower, but the overal speed of the editor will be faster as the custom
	# modules don't need to be loaded first.
	for key in data:
		if modules.has(key):
			modules[key] = data[key]
		else:
			print_debug("Key '%s' can not be found in modules!" % key)


func get_module(module: String) -> Node:
	return load(PATH_MODULE.replace('|', module) % modules[module]).instantiate()
