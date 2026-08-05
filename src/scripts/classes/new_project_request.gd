class_name NewProjectRequest
extends Node


# Basic settings.
@export var project_path: String = ""
@export var resolution: Vector2i
@export var framerate: float

# Advanced settings.
@export var track_amount: int = Settings.get_tracks_amount()
@export var background_color: Color = Color.BLACK
