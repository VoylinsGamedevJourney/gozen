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
			str("%0.2f" % (OS.get_memory_info().physical/1_073_741_824)), 
			str("%0.2f" % (OS.get_memory_info().available/1_073_741_824))]],
		["Video adapter", "\n\tName: %s\n\tVersion: %s\n\tType: %s" % [
			RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_api_version(),
			RenderingServer.get_video_adapter_type()]],
		["Debug build", OS.is_debug_build()],
		["--==--================--==--"]
	])
	print('')


func todo(a_message: String) -> void:
	_print(["green", "TODO", a_message])


func connect_error(a_error: int) -> void:
	if !a_error:
		return
	var l_message: String = "Connect error '%s'" % a_error
	l_message += "\n\tFile: '%s'" % get_stack()[1].source
	l_message += "\n\tFunction: '%s'" % get_stack()[1].function
	l_message += "\n\tLine: '%s'" % get_stack()[1].line
	_print(["red", "ERROR", l_message])


func error(a_message: String) -> void:
	a_message += "\n\tFile: '%s'" % get_stack()[1].source
	a_message += "\n\tFunction: '%s'" % get_stack()[1].function
	a_message += "\n\tLine: '%s'" % get_stack()[1].line
	_print(["red", "ERROR", a_message])


func debug(a_message: String) -> void:
	if SettingsManager.get_debug_enabled():
		_print(["grey", "DEBUG", a_message])


func _print(a_data: PackedStringArray) -> void:
	_add_to_log("%s: %s" % [a_data[1], a_data[2]])
	print_rich("[color=%s][b]%s:[/b] %s" % [a_data[0], a_data[1], a_data[2]])


func _print_wall(a_color: String, a_data: Array) -> void:
	for l_line: PackedStringArray in a_data:
		if l_line.size() == 1:
			_add_to_log(l_line[0])
			print_rich("[color=%s][b]%s[/b]" % [a_color, l_line[0]])
			continue
		_add_to_log("%s: %s" % [l_line[0], l_line[1]])
		print_rich("[color=%s][b]%s:[/b] %s" % [a_color, l_line[0], l_line[1]])


func _add_to_log(a_message: String) -> void:
	if !Engine.has_singleton("EditorInterface"):
		a_message = "{hour}-{minute}-{second}:  " + a_message
		log_file.seek_end()
		log_file.store_line(a_message.format(Time.get_time_dict_from_system()))
		log_file.flush()
