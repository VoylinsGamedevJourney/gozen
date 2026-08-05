class_name ProjectProfile
extends Resource


@export var profile_name: String = ""

@export var resolution: Vector2i = Vector2i(1920, 1080)
@export var framerate: float = 30

@export var advanced_settings_enabled: bool = false
@export var background_color: Color = Color.BLACK
@export var track_amount: int = Settings.get_tracks_amount()
