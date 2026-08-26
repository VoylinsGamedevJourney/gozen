extends PanelContainer
# TODO: In 4.8 we can use the native fuzzy search feature.

@export var search_line_edit: LineEdit
@export var effect_buttons: VBoxContainer


@onready var scroll: ScrollContainer = effect_buttons.get_parent()


var current_clips: Array[ClipData] = []
var is_type: int = 0

var button_group: ButtonGroup = ButtonGroup.new()
var shown_buttons: Array[Button] = []
var selected_button: int = 0



func _ready() -> void:
	search_line_edit.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close(PopupManager.ADD_EFFECTS)
	elif event.is_action_pressed("ui_up"):
		if shown_buttons.size() > 0:
			selected_button = maxi(0, selected_button - 1)
			shown_buttons[selected_button].button_pressed = true
			scroll.ensure_control_visible(shown_buttons[selected_button])
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		if shown_buttons.size() > 0:
			selected_button = mini(shown_buttons.size() - 1, selected_button + 1)
			shown_buttons[selected_button].button_pressed = true
			scroll.ensure_control_visible(shown_buttons[selected_button])
			get_viewport().set_input_as_handled()


func load_effects(type: EffectsHandler.TYPE, clips: Array[ClipData]) -> void:
	current_clips = clips
	is_type = type

	var has_visual: bool = false
	var has_audio: bool = false
	for clip: ClipData in current_clips:
		if clip.type in EditorCore.VISUAL_TYPES: has_visual = true
		if clip.type in EditorCore.AUDIO_TYPES:  has_audio  = true
		if has_visual and has_audio: break # No need to go over the other clips anymore.

	match type:
		EffectsHandler.TYPE.ALL:
			if has_visual: _add_effects(EffectsHandler.visual_effects, true)
			if has_audio: _add_effects(EffectsHandler.audio_effects, false)
		EffectsHandler.TYPE.VISUALS:
			if has_visual: _add_effects(EffectsHandler.visual_effects, true)
		EffectsHandler.TYPE.AUDIO:
			if has_audio: _add_effects(EffectsHandler.audio_effects, false)


func _add_effects(effects_data: Dictionary[String, String], is_visual: bool) -> void:
	for effect_option: String in effects_data:
		var button: Button = Button.new()

		button.theme_type_variation = "EffectVisualButton" if is_visual else "EffectAudioButton"
		button.text = tr(effect_option)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = button_group
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		if button.pressed.connect(_on_effect_clicked.bind(effects_data[effect_option], is_visual)):
			printerr("AddEffectsPopup: Couldn't connect 'pressed' on '%s' button!" % tr(effect_option))

		shown_buttons.append(button)
		effect_buttons.add_child(button)
	shown_buttons[0].button_pressed = true
	_on_search_box_text_changed("")


func _on_search_box_text_changed(effect_text: String) -> void:
	var buttons: Array[ButtonScore] = []
	shown_buttons.clear()
	selected_button = 0

	for button: Button in effect_buttons.get_children():
		buttons.append(ButtonScore.new(button, effect_text))
	buttons.sort_custom(ButtonScore.sort_scores)

	for i: int in buttons.size():
		var button: Button = buttons[i].button
		button.visible = buttons[i].score != 0
		effect_buttons.move_child(button, i)
		if button.visible:
			shown_buttons.append(button)

	if shown_buttons.size() > 0:
		shown_buttons[0].button_pressed = true


func _on_search_box_text_submitted(_effect_text: String) -> void:
	if shown_buttons.size() != 0:
		shown_buttons[selected_button].pressed.emit()


func _on_effect_clicked(effect_id: String, is_visual: bool) -> void:
	EffectsHandler.add_effect(
			current_clips,
			EffectsHandler.visual_effect_instances[effect_id].deep_copy() if is_visual else\
			EffectsHandler.audio_effect_instances[effect_id].deep_copy(),
 			is_visual)
	_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close_all()



class ButtonScore:
	var button: Button
	var score: int


	func _init(button_node: Button, effect_text: String) -> void:
		button = button_node
		score = Utils.get_fuzzy_score(effect_text, button.text)

	static func sort_scores(a: ButtonScore, b: ButtonScore) -> bool:
		return a.score > b.score
