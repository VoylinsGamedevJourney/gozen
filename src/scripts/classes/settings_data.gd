class_name SettingsData
extends RefCounted


enum AudioWaveformStyle { CENTER, BOTTOM_TO_TOP, TOP_TO_BOTTOM }
enum EmptySpaceClickAction { SEEK, CLEAR_SELECTION }


# Appearance
var language: String = "en"
var display_scale: float = 1.0
var theme: String = Library.THEME_DEFAULT
var show_menu_bar: bool = true
var show_safe_areas_on_startup: bool = false
var audio_waveform_style: AudioWaveformStyle = AudioWaveformStyle.CENTER
var audio_waveform_amp: float = 1.0
var use_native_dialog: bool = true
var panel_tabs_position: int = 0

# Defaults
var image_duration: int = 300
var color_duration: int = 300
var text_duration: int = 300
var default_project_path: String = ""
var default_resolution: Vector2i = Vector2i(1920, 1080)
var default_framerate: float = 30.0
var quick_create_horizontal_res: Vector2i = Vector2i(1920, 1080)
var quick_create_horizontal_fps: float = 30.0
var quick_create_vertical_res: Vector2i = Vector2i(1080, 1920)
var quick_create_vertical_fps: float = 30.0

# Timeline
var tracks_amount: int = 6 ## The amount of tracks.
var tracks_height: float = 30
var pause_after_drag: bool = false
var delete_empty_modifier: int = KEY_NONE
var empty_space_click_action: EmptySpaceClickAction = EmptySpaceClickAction.SEEK
var show_time_mode_bar: bool = true

# Rendering
var default_render_profile: String = "YouTube"

# Performance
var video_smart_seek_threshold: int = 30
var video_cache_size: int = 15 ## This is a ram eater, we should NOT set this too high.
var use_proxies: bool = false
var proxies_path: String = "user://proxies"

# Markers
var marker_names: Array[String] = [ "Marker type 1", "Marker type 2", "Marker type 3", "Marker type 4", "Marker type 5" ]
var marker_colors: Array[Color] = [ Color.PURPLE, Color.GREEN, Color.BLUE, Color.ORANGE, Color.RED ]

# Extra
var auto_save: bool = true

# Input
var shortcuts: Dictionary = {} # { action_name: [InputEvent, InputEvent] }

# Modules
var module_settings: Dictionary = {}


# HIDDEN SETTINGS
var tab_edit_hsplit_offsets: PackedInt32Array = [260, 1608]
var tab_render_hsplit_offsets: PackedInt32Array = [260, 1608]
var tab_vsplit_offsets: PackedInt32Array = [0]
