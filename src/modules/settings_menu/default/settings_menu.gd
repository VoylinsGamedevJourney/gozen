extends PanelContainer

# TODO: Make search work
# TODO: Display all module settings in their own category


func _ready() -> void:
	build_settings()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func build_settings() -> void:
	var cat_main := SettingsCategory.new("Main")
	cat_main.append(
		SettingsSetting.new(
			"Language",
			SettingsSetting.TYPE.LIST,
			SettingsManager.set_language,
			
		)
	)
	pass
