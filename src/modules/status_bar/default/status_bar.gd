extends Control


func _ready() -> void:
	SettingsManager._on_zen_switched.connect(_on_zen_switch)


func _on_zen_switch(value: bool) -> void:
	self.visible = value
