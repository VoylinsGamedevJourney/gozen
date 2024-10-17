extends VBoxContainer

const ICON_SIZE: int = 20

@onready var hbox: HBoxContainer = $ButtonHBox
@onready var button_mute: TextureButton = $ButtonHBox/MuteButton
@onready var button_visibility: TextureButton = $ButtonHBox/VisibilityButton
@onready var line: HSeparator = $Line


func _ready() -> void:
	button_mute.texture_normal = SettingsManager.get_icon("sound_on")
	button_mute.custom_minimum_size.x = ICON_SIZE

	button_visibility.texture_normal = SettingsManager.get_icon("visibility_on")
	button_visibility.custom_minimum_size.x = ICON_SIZE

