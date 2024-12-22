extends Control


func _ready() -> void:
	for l_arg: String in OS.get_cmdline_args():
		if l_arg.ends_with(".gozen"):
			# TODO: Load project with the path found
			break

