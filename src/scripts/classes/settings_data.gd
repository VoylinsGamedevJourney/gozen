class_name SettingsData
extends RefCounted


enum THEME { DARK, LIGHT }
enum AUDIO_WAVEFORM_STYLE { CENTER, BOTTOM_TO_TOP, TOP_TO_BOTTOM }


# Appearance
var language: String = "en"
var display_scale: float = 1.0
var theme: THEME = THEME.DARK
var show_menu_bar: bool = true
var audio_waveform_style: AUDIO_WAVEFORM_STYLE = AUDIO_WAVEFORM_STYLE.CENTER 
var audio_waveform_amp: float = 1.0
var use_native_dialog: bool = true

# Defaults
var image_duration: int = 300
var color_duration: int = 300
var text_duration: int = 300
var default_project_path: String = ""
var default_resolution: Vector2i = Vector2i(1920, 1080)
var default_framerate: float = 30.0

# Timeline
var tracks_amount: int = 6 # The amount of tracks
var pause_after_drag: bool = false
var delete_empty_modifier: int = KEY_NONE
var show_time_mode_bar: bool = true

# Markers
var marker_names: PackedStringArray = [ "Marker type 1", "Marker type 2", "Marker type 3", "Marker type 4", "Marker type 5" ]
var marker_colors: PackedColorArray = [ Color.PURPLE, Color.GREEN, Color.BLUE, Color.ORANGE, Color.RED ]

# Extra
var check_version: bool = false
var auto_save: bool = true

# Input
var shortcuts: Dictionary = {} # { action_name: [InputEvent, InputEvent] }

