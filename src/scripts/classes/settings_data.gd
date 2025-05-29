class_name SettingsData
extends DataManager


enum THEME { DARK, LIGHT }
enum AUDIO_WAVEFORM_STYLE { CENTER, BOTTOM_TO_TOP, TOP_TO_BOTTOM }


# Appearance
var language: String = OS.get_locale()
var theme: THEME = THEME.DARK
var show_menu_bar: bool = true
var audio_waveform_style: AUDIO_WAVEFORM_STYLE = AUDIO_WAVEFORM_STYLE.CENTER 

# Defaults
var image_duration: int = 300
var default_project_path: String = OS.get_executable_path().trim_suffix(OS.get_executable_path().get_file())
var default_resolution: Vector2i = Vector2i(1920, 1080)
var default_framerate: float = 30.0

# Timeline
var tracks_amount: int = 6 # The amount of tracks
var pause_after_drag: bool = false
var delete_empty_modifier: int = KEY_NONE

# Extra
var check_version: bool = false

