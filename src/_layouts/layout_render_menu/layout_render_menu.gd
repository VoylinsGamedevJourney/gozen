extends Control
# TODO: Mini timeline should just show beginning and ending and will only be 
# used for quickly checking the video and to eventually select an area of the 
# video which has to be rendered separately.
# TODO: ProjectView will be to display where the marker is on the mini timeline
# This can not be the project_view module as it's possible that people have
# their own project view module which they'd like to use.
# TODO: Create a render profile system in form of a resource/Dictionary which
# can be saved to a pck file or preferably just a text file instead so we can
# use a RenderProfile class and use var_to_str and str_to_var
# TODO: Render settings should have a dropdown with the necesarry settings
# displayed underneath the dropdown which change after selecting a render profile.
# TODO: Use a config file to save all custom profiles, section key is name

@onready var project_preview_buttons := $VBox/HSplit/ProjectView/VBox/ProjectPreviewButtonsHBox


func _ready() -> void:
	# TODO: Display a * next to ntries in option button menu of which have hardware acceleration
	# Maybe have a checkbox is they want hardware acceleration to be enabled or not?
	var l_id: int = 0
	
	for l_codec_info: Dictionary in GoZenInterface.get_supported_video_codecs():
		%VideoCodecOptionButton.add_item("{codec_id}{hardware_encoding}".format({
			hardware_encoding = '*' if l_codec_info.hardware_accel else '', 
			codec_id = l_codec_info.codec_id }))
		%VideoCodecOptionButton.set_item_disabled(l_id, !l_codec_info.supported)
		l_id += 1
	
	l_id = 0
	for l_codec_info: Dictionary in GoZenInterface.get_supported_audio_codecs():
		%AudioCodecOptionButton.add_item("{codec_id}{hardware_encoding}".format({
			hardware_encoding = '*' if l_codec_info.hardware_accel else '',
			codec_id = l_codec_info.codec_id }))
		%AudioCodecOptionButton.set_item_disabled(l_id, !l_codec_info.supported)
		l_id += 1


#region #####################  Playback buttons  ###############################

func _on_to_begin_button_pressed() -> void:
	pass # Replace with function body.


func _on_rewind_button_pressed() -> void:
	pass # Replace with function body.


func _on_play_button_pressed() -> void:
	project_preview_buttons.get_node("PlayButton").visible = false
	project_preview_buttons.get_node("PauseButton").visible = true


func _on_pause_button_pressed() -> void:
	project_preview_buttons.get_node("PlayButton").visible = true
	project_preview_buttons.get_node("PauseButton").visible = false


func _on_forward_button_pressed() -> void:
	pass # Replace with function body.


func _on_to_end_button_pressed() -> void:
	pass # Replace with function body.

#endregion
#region #####################  Render buttons  #################################

func _on_export_video_only_button_pressed() -> void:
	pass # TODO: Replace with function body.


func _on_export_audio_only_button_pressed() -> void:
	pass # TODO: Replace with function body.


func _on_export_video_button_pressed() -> void:
	pass # TODO: Replace with function body.

#endregion
