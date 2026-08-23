class_name RequestProjectNew


# Basic settings.
var project_path: String = ""
var resolution: Vector2i
var framerate: float

# Advanced settings.
var track_amount: int = Settings.get_module_setting("core_timeline_panel", "tracks_amount", 6)
var background_color: Color = Color.BLACK
