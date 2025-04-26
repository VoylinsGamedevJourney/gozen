class_name SettingsData
extends DataManager


enum THEME { DARK, LIGHT }


# Appearance
var theme: THEME = THEME.DARK

# Defaults
var image_duration: int = 300
var default_project_path: String = OS.get_executable_path().trim_suffix(OS.get_executable_path().get_file())
var default_resolution: Vector2i = Vector2i(1920, 1080)
var default_framerate: float = 30.0

# Timeline
var tracks_amount: int = 6 # The amount of tracks
var pause_after_drag: bool = false

