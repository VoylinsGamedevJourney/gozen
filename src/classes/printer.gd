class_name Printer extends Node
# TODO:
#  Create log files where this info gets written to.
#  Reason: Could help with debugging problems but only write to file
#          when debug build. For Release there will be a toggle in settings
#          to enable logging.

static func startup() -> void:
	const color := "purple"
	print_rich("[color=%s][b]--==  GoZen - Video Editor  ==--[/b][/color]" % color) 
	_print([color, "GoZen version", ProjectSettings.get_setting("application/config/version")])
	_print([color, "Distribution", OS.get_distribution_name()])
	_print([color, "OS Version", OS.get_version()])
	_print([color, "Processor", OS.get_processor_name()])
	_print([color, "Threads", OS.get_processor_count()])
	_print([color, "Ram", "\n\tTotal: %s GB\n\tAvailable: %s GB" % [
			str("%0.2f" % (float(OS.get_memory_info().physical)/1_073_741_824)), 
			str("%0.2f" % (float(OS.get_memory_info().available)/1_073_741_824))]])
	_print([color, "Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
			RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_api_version(),
			RenderingServer.get_video_adapter_type()]])
	_print([color, "Debug build", OS.is_debug_build()])
	print_rich("[color=%s][b]--==--================--==--==--[/b][/color]\n" % color) 


static func todo(message: String) -> void:
	_print(["green", "TODO", message])


static func error(message: String) -> void:
	_print(["red", "ERROR", message])


static func debug(message: String) -> void:
	todo("Have a toggle in settings to enable/disable debug.")
	# TODO: Have a toggle in settings to enable/disable debug
	_print(["grey", "DEBUG", message])


static func _print(data: PackedStringArray) -> void:
	print_rich("[color=%s][b]%s:[/b] %s" % [data[0], data[1], data[2]])
