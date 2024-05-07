extends DataHandler

signal _on_language_changed


const PATH: String = "user://settings"


var _loaded: bool = false

var language: String = "en": set = set_language

var embed_subwindows: bool = true: set = set_embed_subwindows

var default_video_track_amount: int = 3: set = set_default_video_track_amount
var default_audio_track_amount: int = 3: set = set_default_audio_track_amount

var default_text_duration: float = 10.0
var default_image_duration: float = 10.0
var default_color_duration: float = 10.0
var default_color_gradient_duration: float = 10.0



func _init() -> void:
	# Print GoZen info on startup
	print_rich("[color=purple][b]--==  GoZen - Video Editor  ==--")
	for l_line: Array in [
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
		["Debug build", OS.is_debug_build()]]:
		print_rich("[color=purple][b]%s[/b]: %s" % l_line)
	print_rich("[color=purple][b]--==--================--==--")


func _ready() -> void:
	# Loading settings on startup
	load_data(PATH)
	_loaded = true


func save_settings() -> void:
	if _loaded:
		save_data(PATH)


##region #####################  Setters and getters  ############################

func set_language(a_value: String) -> void:
	language = a_value
	TranslationServer.set_locale(language)
	_on_language_changed.emit()
	save_settings()


func set_embed_subwindows(a_value: bool) -> void:
	embed_subwindows = a_value
	get_viewport().set_embedding_subwindows(embed_subwindows)
	save_settings()


func set_default_video_track_amount(a_value: int) -> void:
	default_video_track_amount = a_value
	save_settings()

func set_default_audio_track_amount(a_value: int) -> void:
	default_audio_track_amount = a_value
	save_settings()

#endregion
