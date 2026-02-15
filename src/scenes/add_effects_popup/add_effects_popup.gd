extends PanelContainer

@export var search_line_edit: LineEdit
@export var effect_buttons: VBoxContainer


var current_clip_id: int = -1
var is_visual: bool = true

var shown_buttons: Array[Button] = []
var selected_button: int = 0



func _ready() -> void:
	search_line_edit.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		PopupManager.close_popup(PopupManager.ADD_EFFECTS)


func load_effects(visual: bool, clip_id: int) -> void:
	var effects_data: Dictionary[String, String] = {}
	var button_group: ButtonGroup = ButtonGroup.new()

	current_clip_id = clip_id
	is_visual = visual

	if is_visual:
		effects_data = EffectsHandler.visual_effects
	else:
		effects_data = EffectsHandler.audio_effects

	for effect_option: String in effects_data:
		var button: Button = Button.new()

		button.text = tr(effect_option)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.button_group = button_group
		button.toggle_mode = true
		button.pressed.connect(_on_effect_clicked.bind(effects_data[effect_option]))
		button.pressed.connect(_on_close_button_pressed)

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
		shown_buttons.append(button)

	if shown_buttons.size() > 0:
		shown_buttons[0].button_pressed = true


func _on_search_box_text_submitted(_effect_text: String) -> void:
	for button: Button in effect_buttons.get_children():
		if button.visible:
			if selected_button == 0:
				button.pressed.emit()
				return
			else:
				selected_button -= 1


func _on_effect_clicked(effect_id: String) -> void:
	var effect: GoZenEffect

	if is_visual:
		effect = EffectsHandler.visual_effect_instances[effect_id].duplicate()
	else:
		effect = EffectsHandler.audio_effect_instances[effect_id].duplicate()

	EffectsHandler.add_effect(current_clip_id, effect, is_visual)
	_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	PopupManager.close_popup(PopupManager.ADD_EFFECTS)



class ButtonScore:
	var button: Button
	var score: int

	func _init(button_node: Button, effect_text: String) -> void:
		button = button_node
		score = Utils.get_fuzzy_score(effect_text, button.text)

	static func sort_scores(a: ButtonScore, b: ButtonScore) -> bool:
		return a.score > b.score
