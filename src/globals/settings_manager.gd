extends DataManager


const PATH: String = "user://editor_settings"


var default_tracks: int = 6
var default_duration_image: int = 600
var default_duration_color: int = 600
var default_duration_gradient: int = 600
var default_duration_text: int = 600



#------------------------------------------------ GODOT FUNCTIONS
func _ready() -> void:
	print_debug_info()
	load_data()


#------------------------------------------------ DATA HANDLING
func print_debug_info() -> void:
	print_rich("[color=purple][b]--==  GoZen - Video Editor  ==--")
	for l_info: Array in [
			["GoZen Version", ProjectSettings.get_setting("application/config/version")],
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
			["Debug build", OS.is_debug_build()]]:
		print_rich("[color=purple][b]%s[/b] %s" % l_info)
	print_rich("[color=purple][b]--==--================--==--")


#------------------------------------------------ DATA HANDLING
func save_data() -> void:
	if _save_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for saving! ", PATH)


func load_data() -> void:
	if _load_data(PATH) == ERR_FILE_CANT_OPEN:
		printerr("Couldn't open settings file for loading! ", PATH)

