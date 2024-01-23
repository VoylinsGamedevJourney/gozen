extends Control


func _ready():
	prepare_languages()
	set_current_values()


func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()


func _on_close_button_pressed():
	ScreenMain.instance.close_screen()


func set_current_values() -> void:
	%LanguageOptionButton.selected = TranslationServer.get_loaded_locales().find(
			SettingsManager.get_language())
	%DefaultVideoTracksSpinBox.value = SettingsManager.get_default_video_tracks()
	%DefaultAudioTracksSpinBox.value = SettingsManager.get_default_audio_tracks()


func prepare_languages() -> void:
	for option: String in TranslationServer.get_loaded_locales():
		if option.contains("_"):
			%LanguageOptionButton.add_item("%s - %s" % [
				TranslationServer.get_language_name(option.split('_')[0]),
				TranslationServer.get_country_name(option.split('_')[1])])
		else:
			%LanguageOptionButton.add_item(TranslationServer.get_language_name(option))


###############################################################
#region GENERAL SETTING SETTERS  ############################## 
###############################################################

func _on_language_option_button_item_selected(index):
	SettingsManager.set_language(TranslationServer.get_loaded_locales()[index])

#endregion
###############################################################
#region TIMELINE SETTING SETTERS  #############################
###############################################################

func _on_default_video_tracks_spin_box_value_changed(value):
	SettingsManager.set_default_video_tracks(value)


func _on_default_audio_tracks_spin_box_value_changed(value):
	SettingsManager.set_default_audio_tracks(value)

#endregion
###############################################################
