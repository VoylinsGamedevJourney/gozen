extends Node


var log_file : FileAccess
var log_path : String


func _ready() -> void:
	# Creating log file
	if !Engine.has_singleton("EditorInterface"):
		log_path = "user://log_{year}-{month}-{day}".format(Time.get_date_dict_from_system())
		if FileAccess.file_exists(log_path):
			log_file = FileAccess.open(log_path, FileAccess.READ_WRITE)
		else:
			log_file = FileAccess.open(log_path, FileAccess.WRITE)
	
	# Printing startup debug info
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
	if SettingsManager.get_debug_enabled():
		_print(["grey", "DEBUG", message])


func _print(data: PackedStringArray) -> void:
	_add_to_log("%s: %s" % [data[1], data[2]])
	print_rich("[color=%s][b]%s:[/b] %s" % [data[0], data[1], data[2]])


func _print_wall(color: String, data: Array) -> void:
	for line: PackedStringArray in data:
		if line.size() == 1:
			_add_to_log(line[0])
			print_rich("[color=%s][b]%s[/b]" % [color, line[0]])
			continue
		_add_to_log("%s: %s" % [line[0], line[1]])
		print_rich("[color=%s][b]%s:[/b] %s" % [color, line[0], line[1]])


func _add_to_log(message: String) -> void:
	if !Engine.has_singleton("EditorInterface"):
		message = "{hour}-{minute}-{second}:  " + message
		log_file.seek_end()
		log_file.store_line(message.format(Time.get_time_dict_from_system()))
		log_file.flush()
