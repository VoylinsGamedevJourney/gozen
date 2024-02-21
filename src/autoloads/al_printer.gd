extends Node
# TODO:
#  Create log files where this info gets written to.
#  Reason: Could help with debugging problems but only write to file
#          when debug build. For Release there will be a toggle in settings
#          to enable logging.

func _ready() -> void:
	_print_wall("purple", [
		["--==  GoZen - Video Editor  ==--"],
		["GoZen version", ProjectSettings.get_setting("application/config/version")],
		["Distribution", OS.get_distribution_name()],
		["OS Version", OS.get_version()],
		["Processor", OS.get_processor_name()],
		["Threads", OS.get_processor_count()],
		["Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
			str("%0.2f" % (float(OS.get_memory_info().physical)/1_073_741_824)), 
			str("%0.2f" % (float(OS.get_memory_info().available)/1_073_741_824))]],
		["Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
			RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_api_version(),
			RenderingServer.get_video_adapter_type()]],
		["Debug build", OS.is_debug_build()],
		["--==--================--==--"]
	])


func todo(message: String) -> void:
	_print(["green", "TODO", message])


func error(message: String) -> void:
	_print(["red", "ERROR", message])


func debug(message: String) -> void:
	todo("Have a toggle in settings to enable/disable debug.")
	# TODO: Have a toggle in settings to enable/disable debug
	_print(["grey", "DEBUG", message])


func _print(data: PackedStringArray) -> void:
	print_rich("[color=%s][b]%s:[/b] %s" % [data[0], data[1], data[2]])


func _print_wall(color: String, data: Array) -> void:
	for line: PackedStringArray in data:
		if line.size() == 1:
			print_rich("[color=%s][b]%s[/b]" % [color, line[0]])
			continue
		print_rich("[color=%s][b]%s:[/b] %s" % [color, line[0], line[1]])
