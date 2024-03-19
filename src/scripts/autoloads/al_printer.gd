extends Node
# TODO:
#  Create log files where this info gets written to.
#  Reason: Could help with debugging problems but only write to file
#          when debug build. For Release there will be a toggle in settings
#          to enable logging.

var log_file : FileAccess
var log_path : String


func _ready() -> void:
	_create_log()
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


###############################################################
#region Log File Handler  #####################################
###############################################################

func _create_log() -> void:
	var date_time: Dictionary = Time.get_datetime_dict_from_system()
	log_path = "user://log_{year}-{month}-{day}_{hour}-{minute}-{second}".format(date_time)
	log_file = FileAccess.open(log_path, FileAccess.WRITE)


func _add_to_log(message: String) -> void:
	if !log_file.is_open():
		print("not open")
		log_file = FileAccess.open(log_path, FileAccess.WRITE)
	log_file.store_line(message)

#endregion
###############################################################
