class_name SettingsData
extends DataManager


enum THEME { DARK, LIGHT }
enum AUDIO_WAVEFORM_STYLE { CENTER, BOTTOM_TO_TOP, TOP_TO_BOTTOM }


# Appearance
var language: String = get_system_locale()
var display_scale: float = get_display_scale()
var theme: THEME = THEME.DARK
var show_menu_bar: bool = true
var audio_waveform_style: AUDIO_WAVEFORM_STYLE = AUDIO_WAVEFORM_STYLE.CENTER 

# Defaults
var image_duration: int = 300
var color_duration: int = 300
var text_duration: int = 300
var default_project_path: String = OS.get_executable_path().trim_suffix(OS.get_executable_path().get_file())
var default_resolution: Vector2i = Vector2i(1920, 1080)
var default_framerate: float = 30.0

# Timeline
var tracks_amount: int = 6 # The amount of tracks
var pause_after_drag: bool = false
var delete_empty_modifier: int = KEY_NONE

# Markers
var marker_colors: PackedColorArray = [ Color.PURPLE, Color.GREEN, Color.BLUE, Color.ORANGE, Color.RED ]

# Extra
var check_version: bool = false
var auto_save: bool = true



func get_system_locale() -> String:
	var locale: String = OS.get_locale()

	# Check if language with country code can be found.
	if OS.get_locale() in TranslationServer.get_loaded_locales():
		return locale

	# Next up check if only the language code can be found.
	locale = OS.get_locale_language()
	if locale in TranslationServer.get_loaded_locales():
		return locale

	# Next up, get the first entry which has the language code,
	# this can happen if we only have instances of the language being
	# available from a certain country.
	for loaded_locale: String in TranslationServer.get_loaded_locales():
		if loaded_locale.begins_with(locale):
			return loaded_locale

	# Return English as a default
	return "en"


func get_display_scale() -> float:
	var size: Vector2 = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())

	if size.y > 1100:
		return 1.5
	elif size.y < 1000:
		return 0.5

	return 1.0

