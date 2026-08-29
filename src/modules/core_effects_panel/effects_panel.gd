class_name EffectsPanel
extends PanelContainer

# NOTES:
# - Load in effects;
# - Show effects;
# - Make it possible to edit values;
# - Draw basic panel UI (not effects UI);


const HEADER: String = "EffectsPanel:" # NO_TRANSLATE

const MIN_VALUE: float = -100000
const MAX_VALUE: float = 100000

const SIZE_EFFECT_HEADER_ICON: Vector2i = Vector2i(16, 16)

const PRESETS_PATH: String = "user://presets/"


@export var section_text: VBoxContainer
@export var section_transitions: FoldableContainer
@export var section_visuals: FoldableContainer
@export var section_audio: FoldableContainer
@export var section_module: FoldableContainer


@onready var scroll: ScrollContainer = $Margin/Scroll


var current_clip: ClipData = null
var current_file: FileData = null

var drop_indicator_pos: int = -1
var drop_indicator_vbox: VBoxContainer = null
var _drag_overlays: Array[Control] = []

var clip_enable_visuals_button: CheckButton
var clip_enable_audio_button: CheckButton



func _ready() -> void:
	if DirAccess.make_dir_absolute(PRESETS_PATH) not in [ERR_ALREADY_EXISTS, OK]:
		printerr(HEADER, "Couldn't create folder at '%s'!" % PRESETS_PATH)

	clip_enable_visuals_button = CheckButton.new()
	clip_enable_visuals_button.flat = true
	clip_enable_visuals_button.tooltip_text = tr("Enable clip visuals.")

	clip_enable_audio_button = CheckButton.new()
	clip_enable_audio_button.flat = true
	clip_enable_audio_button.tooltip_text = tr("Enable clip audio.")

	@warning_ignore_start("return_value_discarded")
	ClipLogic.deleted.connect(func(clip_id: int) -> void:
			if current_clip and clip_id == current_clip.id:
				_on_clip_pressed(null))
	ClipLogic.selected.connect(_on_clip_pressed)

	EditorCore.visual_frame_changed.connect(func() -> void:
			if current_clip: _update_ui_values())

	EffectsHandler.effect_added.connect(_on_effect_added)
	EffectsHandler.effect_removed.connect(_on_effect_removed)
	EffectsHandler.effect_moved.connect(_on_effect_moved)
	EffectsHandler.effect_values_updated.connect(_update_ui_values)

	EffectsHandler.transition_updated.connect(_on_transition_updated)

	clip_enable_visuals_button.toggled.connect(_on_visuals_enable_button_toggled)
	clip_enable_audio_button.toggled.connect(_on_audio_enable_button_toggled)
	@warning_ignore_restore("return_value_discarded")

	section_transitions.visible = false
	section_transitions.folded = true


	section_visuals.add_title_bar_control(clip_enable_visuals_button)
	section_visuals.add_title_bar_control(_get_section_preset_button(true))
	section_visuals.add_title_bar_control(_get_add_effects_button(1))
	section_visuals.folded = true

	section_audio.add_title_bar_control(clip_enable_audio_button)
	section_audio.add_title_bar_control(_get_section_preset_button(false))
	section_audio.add_title_bar_control(_get_add_effects_button(2))
	section_audio.folded = true


func _input(event: InputEvent) -> void:
	if !PopupManager._open_popups.is_empty() or !Project.is_loaded: return

	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var is_ui_cancel: bool = event.is_action_pressed("ui_cancel", false, true)

	if focus_owner is LineEdit or focus_owner is TextEdit:
		if is_ui_cancel:
			focus_owner.release_focus()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("add_effect", false, true):
		_open_add_effects_popup(0, false)
	elif is_ui_cancel:
		_on_clip_pressed(null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		for overlay: Control in _drag_overlays:
			if !is_instance_valid(overlay): continue
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drop_indicator_pos = -1
		if drop_indicator_vbox:
			drop_indicator_vbox.queue_redraw()
			drop_indicator_vbox = null


func _get_drag_data_effect(_pos: Vector2, effect: Effect, is_visual: bool) -> Variant:
	for overlay: Control in _drag_overlays:
		if !is_instance_valid(overlay): continue
		overlay.mouse_filter = Control.MOUSE_FILTER_PASS

	var index: int = _get_effect_index(effect, is_visual)
	var drag_data: RequestEffectDrag = RequestEffectDrag.new()
	var preview: Label = Label.new()
	drag_data.is_visual = is_visual
	drag_data.effect_index = index
	drag_data.effect = effect
	preview.text = "Moving: " + effect.nickname
	set_drag_preview(preview)

	return drag_data


func _can_drop_effect(at_pos: Vector2, data: Variant, is_visual: bool, vbox: VBoxContainer) -> bool:
	if not data is RequestEffectDrag or data.is_visual != is_visual:
		drop_indicator_vbox = null
		drop_indicator_pos = -1
		vbox.queue_redraw()
		return false

	var child_offset: int = 0
	if not is_visual and current_file and current_file.audio_streams.size() > 1:
		child_offset = 2

	var drop_index: int = child_offset
	for index: int in range(child_offset, vbox.get_child_count()):
		var child: Control = vbox.get_child(index)
		if at_pos.y > child.position.y + (child.size.y / 2.0):
			drop_index = index + 1
	drop_indicator_pos = drop_index
	drop_indicator_vbox = vbox
	vbox.queue_redraw()
	return true


func _drop_effect(at_pos: Vector2, data: Variant, is_visual: bool, vbox: VBoxContainer) -> void:
	drop_indicator_pos = -1
	drop_indicator_vbox = null
	vbox.queue_redraw()

	if not data is RequestEffectDrag or data.is_visual != is_visual: return

	var child_offset: int = 0
	if not is_visual and current_file and current_file.audio_streams.size() > 1:
		child_offset = 2

	var old_index: int = data.effect_index
	var new_index: int = 0
	for index: int in range(child_offset, vbox.get_child_count()):
		var child: Control = vbox.get_child(index)
		if at_pos.y > child.position.y + (child.size.y / 2.0):
			new_index = index - child_offset + 1
	if new_index > old_index: new_index -= 1

	if old_index != new_index:
		EffectsHandler.move_effect(current_clip, old_index, new_index, is_visual)


func _draw_drop_indicator(vbox: VBoxContainer) -> void:
	if drop_indicator_vbox != vbox or drop_indicator_pos == -1:
		return

	var pos: Vector2 = Vector2.ZERO
	if drop_indicator_pos < vbox.get_child_count():
		pos.y = (vbox.get_child(drop_indicator_pos) as Control).position.y
	elif vbox.get_child_count() > 0:
		var last_child: Control = vbox.get_child(vbox.get_child_count() - 1)
		pos.y = last_child.position.y + last_child.size.y

	var length: Vector2 = Vector2(vbox.size.x, pos.y)
	vbox.draw_line(pos, length, vbox.get_theme_color("drop_line_color", "EffectsPanel"), 3.0)


func _on_clip_pressed(clip_data: ClipData) -> void:
	if !clip_data or !ClipLogic.clips.has(clip_data.id):
		section_text.visible = false
		section_visuals.visible = false
		section_audio.visible =  false
		current_clip = null
		current_file = null
		_load_effects() # Clear the ui.
		return

	var clip: ClipData = ClipLogic.clips.get(clip_data.id)
	if current_clip and clip.id == current_clip.id:
		return _update_ui_values()

	section_text.visible = clip.type == EditorCore.Type.TEXT
	section_visuals.visible = clip.type in EditorCore.VISUAL_TYPES and clip.type != EditorCore.Type.PCK
	section_module.visible = clip.type == EditorCore.Type.PCK
	section_audio.visible = clip.type in EditorCore.AUDIO_TYPES
	current_clip = clip
	current_file = FileLogic.files[clip.file]
	_load_effects()
	section_visuals.folded = not clip.effects.is_showing
	section_audio.folded = clip.effects.is_muted


func _on_effect_added(clip: ClipData, index: int, is_visual: bool) -> void:
	if current_clip and clip and clip.id == current_clip.id:
		var effect: FoldableContainer
		var location: Control

		if is_visual:
			var target_effect: Effect = clip.effects.video[index]
			effect = _create_effect_ui(target_effect, is_visual)
			if target_effect.id == "pck_effect_params":
				location = section_module.get_child(0).get_child(0)
			else:
				location = section_visuals.get_child(0).get_child(0)

			var target_ui_index: int = 0
			for i: int in range(0, index):
				if (clip.effects.video[i].id == "pck_effect_params") == (target_effect.id == "pck_effect_params"):
					target_ui_index += 1
			location.add_child(effect)
			location.move_child(effect, target_ui_index)

			await get_tree().process_frame
			if is_instance_valid(effect): scroll.ensure_control_visible(effect)
			return
		else:
			effect = _create_effect_ui(clip.effects.audio[index], is_visual)
			location = section_audio.get_child(0).get_child(0)
			if current_file and current_file.audio_streams.size() > 1:
				index += 2

		location.add_child(effect)
		location.move_child(effect, index)

		await get_tree().process_frame
		if is_instance_valid(effect): scroll.ensure_control_visible(effect)


func _on_effect_removed(clip: ClipData, index: int, is_visual: bool) -> void:
	if current_clip and clip and clip.id == current_clip.id:
		var removed_effect: Control
		var location: Control
		if is_visual: return _load_effects() # We just rebuild the entire thing.
		else:
			location = section_audio.get_child(0).get_child(0)
			var child_offset: int = 0
			if current_file and current_file.audio_streams.size() > 1:
				child_offset = 2
			removed_effect = location.get_child(index + child_offset)
			location.remove_child(removed_effect)
		removed_effect.queue_free()


func _on_effect_moved(clip: ClipData, old_index: int, new_index: int, is_visual: bool) -> void:
	if !current_clip or !clip or clip.id != current_clip.id: return

	if is_visual: _load_effects() # Rebuilding, it's easier. :p
	else:
		var location: Control = section_audio.get_child(0).get_child(0)
		if current_file and current_file.audio_streams.size() > 1:
			old_index += 2
			new_index += 2
		location.move_child(location.get_child(old_index), new_index)


func _create_transitions_ui(parent: Control) -> void:
	var clip_effects: ClipEffects = current_clip.effects
	var has_visual: bool = current_clip.type in EditorCore.VISUAL_TYPES
	var has_audio: bool = current_clip.type in EditorCore.AUDIO_TYPES

	var left_label: Label = Label.new()
	left_label.text = "Left Transition"
	left_label.theme_type_variation = "title_label"
	parent.add_child(left_label)

	if has_visual: # Visual fade in.
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var spinbox: SpinBox = SpinBox.new()

		label.text = "Visual Fade (frames)"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		spinbox.max_value = 10000
		spinbox.value = clip_effects.fade_visual.x
		@warning_ignore("return_value_discarded")
		spinbox.value_changed.connect(
				_on_visual_in_value_changed.bind(clip_effects, spinbox))

		hbox.add_child(label)
		hbox.add_child(spinbox)
		parent.add_child(hbox)

	if has_audio: # Audio fade in.
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var spinbox: SpinBox = SpinBox.new()

		label.text = "Audio Fade (frames)"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		spinbox.max_value = 10000
		spinbox.value = clip_effects.fade_audio.x
		@warning_ignore("return_value_discarded")
		spinbox.value_changed.connect(
				_on_audio_in_value_changed.bind(clip_effects, spinbox))

		hbox.add_child(label)
		hbox.add_child(spinbox)
		parent.add_child(hbox)

	if has_visual: # Transition in.
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var option_button: OptionButton = OptionButton.new()

		label.text = "Style"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		for transition_name: String in EffectsHandler.transitions:
			option_button.add_item(transition_name)
			if !clip_effects.transition_left: continue
			elif clip_effects.transition_left.id == EffectsHandler.transitions[transition_name]:
				option_button.selected = option_button.item_count - 1
		@warning_ignore("return_value_discarded")
		option_button.item_selected.connect(
				_on_transition_in_style_item_selected.bind(option_button))

		hbox.add_child(label)
		hbox.add_child(option_button)
		parent.add_child(hbox)

		var params: Array[EffectParam] = []
		if clip_effects.transition_left: params = clip_effects.transition_left.params

		for param: EffectParam in params:
			parent.add_child(_create_transition_param_ui(clip_effects.transition_left, param, true))

	parent.add_child(HSeparator.new())

	var right_label: Label = Label.new()
	right_label.text = "Right Transition"
	right_label.theme_type_variation = "title_label"
	parent.add_child(right_label)

	if has_visual: # Visual fade out.
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var spinbox: SpinBox = SpinBox.new()

		label.text = "Visual Fade (frames)"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		spinbox.max_value = 10000
		spinbox.value = clip_effects.fade_visual.y
		@warning_ignore("return_value_discarded")
		spinbox.value_changed.connect(
				_on_visual_out_value_changed.bind(clip_effects, spinbox))

		hbox.add_child(label)
		hbox.add_child(spinbox)
		parent.add_child(hbox)

	if has_audio: # Audio fade out.
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var spinbox: SpinBox = SpinBox.new()

		label.text = "Audio Fade (frames)"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		spinbox.max_value = 10000
		spinbox.value = clip_effects.fade_audio.y
		@warning_ignore("return_value_discarded")
		spinbox.value_changed.connect(
				_on_audio_out_value_changed.bind(clip_effects, spinbox))

		hbox.add_child(label)
		hbox.add_child(spinbox)
		parent.add_child(hbox)

	if has_visual: # Transition in.
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = "Style"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var option_button: OptionButton = OptionButton.new()
		for transition_name: String in EffectsHandler.transitions:
			option_button.add_item(transition_name)
			if clip_effects.transition_right and clip_effects.transition_right.id == EffectsHandler.transitions[transition_name]:
				option_button.selected = option_button.item_count - 1
		@warning_ignore("return_value_discarded")
		option_button.item_selected.connect(_on_transition_out_style_item_selected.bind(option_button))
		hbox.add_child(label)
		hbox.add_child(option_button)
		parent.add_child(hbox)

		if clip_effects.transition_right:
			for param: EffectParam in clip_effects.transition_right.params:
				parent.add_child(_create_transition_param_ui(clip_effects.transition_right, param, false))


func _create_transition_param_ui(transition: Effect, param: EffectParam, is_left: bool) -> HBoxContainer:
	var param_hbox: HBoxContainer = HBoxContainer.new()
	var param_title: Label = Label.new()
	var update_call: Callable = func(val: Variant) -> void:
		EffectsHandler.update_transition_param(current_clip, is_left, param.id, val)

	var param_settings: Control = create_param_control(param, update_call)

	param_title.text = param.nickname
	param_title.tooltip_text = param.tooltip
	param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	param_hbox.name = ("LEFT_" if is_left else "RIGHT_") + param.id
	param_hbox.add_child(param_title)
	param_hbox.add_child(param_settings)

	var value: Variant = transition.get_value(param, 0)
	_set_param_settings_value(param_settings, value)

	return param_hbox


func _load_effects() -> void:
	# Clean UI.
	_drag_overlays.clear()
	if section_text.get_child_count() != 0:
		var container: Container = section_text.get_child(0)
		section_text.remove_child(container)
		container.queue_free()
	if section_visuals.get_child_count() != 0:
		var container: Container = section_visuals.get_child(0)
		section_visuals.remove_child(container)
		container.queue_free()
	if section_audio.get_child_count() != 0:
		var container: Container = section_audio.get_child(0)
		section_audio.remove_child(container)
		container.queue_free()
	if section_module.get_child_count() != 0:
		var container: Container = section_module.get_child(0)
		section_module.remove_child(container)
		container.queue_free()

	var margin_visuals: MarginContainer = MarginContainer.new()
	var vbox_visuals: VBoxContainer = VBoxContainer.new()
	var overlay_visuals: Control = Control.new()
	overlay_visuals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_visuals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_visuals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drag_overlays.append(overlay_visuals)

	margin_visuals.add_child(vbox_visuals)
	margin_visuals.add_child(overlay_visuals)
	section_visuals.add_child(margin_visuals)

	var margin_audio: MarginContainer = MarginContainer.new()
	var vbox_audio: VBoxContainer = VBoxContainer.new()
	var overlay_audio: Control = Control.new()
	overlay_audio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_audio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_audio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drag_overlays.append(overlay_audio)

	margin_audio.add_child(vbox_audio)
	margin_audio.add_child(overlay_audio)
	section_audio.add_child(margin_audio)

	var margin_module: MarginContainer = MarginContainer.new()
	var vbox_module: VBoxContainer = VBoxContainer.new()
	margin_module.add_child(vbox_module)
	section_module.add_child(margin_module)


	if current_clip and current_file and current_file.audio_streams.size() > 1:
		var hbox: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = "Audio Track"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var option_button: OptionButton = OptionButton.new()
		for i: int in current_file.audio_streams.size():
			option_button.add_item("Track %d" % (i + 1), current_file.audio_streams[i])
			var current_index: int = current_clip.effects.audio_stream_index
			if current_index == -1: current_index = current_file.audio_streams[0]
			if current_file.audio_streams[i] == current_index:
				option_button.selected = i

		@warning_ignore("return_value_discarded")
		option_button.item_selected.connect(func(index: int) -> void:
				InputManager.undo_redo.create_action("Change audio track")
				InputManager.undo_redo.add_do_method(
						ClipLogic._set_audio_stream.bind(
								current_clip.effects,
								option_button.get_item_id(index)))
				InputManager.undo_redo.add_undo_method(
						ClipLogic._set_audio_stream.bind(
								current_clip.effects,
								current_clip.effects.audio_stream_index))
				InputManager.undo_redo.commit_action())

		hbox.add_child(label)
		hbox.add_child(option_button)
		vbox_audio.add_child(hbox)
		vbox_audio.add_child(HSeparator.new())

	if section_transitions.get_child_count() != 0:
		var vbox: VBoxContainer = section_transitions.get_child(0)
		section_transitions.remove_child(vbox)
		vbox.queue_free()
	var vbox_transitions: VBoxContainer = VBoxContainer.new()
	section_transitions.add_child(vbox_transitions)

	overlay_visuals.set_drag_forwarding(Callable(), _can_drop_effect.bind(true, vbox_visuals), _drop_effect.bind(true, vbox_visuals))
	overlay_audio.set_drag_forwarding(Callable(), _can_drop_effect.bind(false, vbox_audio), _drop_effect.bind(false, vbox_audio))

	@warning_ignore_start("return_value_discarded")
	vbox_visuals.draw.connect(_draw_drop_indicator.bind(vbox_visuals))
	vbox_audio.draw.connect(_draw_drop_indicator.bind(vbox_audio))
	@warning_ignore_restore("return_value_discarded")

	if !current_clip or !ClipLogic.clips.has(current_clip.id):
		_update_ui_values()
		return

	# Creating/updating new UI.
	var clip_effects: ClipEffects = current_clip.effects
	if section_text.visible: # Set text params.
		var text_effect: Effect = current_file.temp_file.text_effect
		var ui: FoldableContainer = _create_effect_ui(text_effect, true, true)
		section_text.add_child(ui)

	for index: int in clip_effects.video.size(): # Add visual effects.
		var effect: Effect = clip_effects.video[index]
		if effect.id == "pck_effect_params":
			vbox_module.add_child(_create_effect_ui(effect, true))
		else:
			vbox_visuals.add_child(_create_effect_ui(effect, true))

	for index: int in clip_effects.audio.size(): # Add audio effects.
		vbox_audio.add_child(_create_effect_ui(clip_effects.audio[index], false))

	_create_transitions_ui(vbox_transitions)
	section_transitions.visible = current_clip.type in EditorCore.VISUAL_TYPES or current_clip.type in EditorCore.AUDIO_TYPES
	_update_ui_values()


func _create_effect_ui(effect: Effect, is_visual: bool, is_file_effect: bool = false) -> FoldableContainer:
	# NOTE: We can add the position of the effect inside of the effect array
	# inside of the metadata and let the buttons check if they are at the top
	# or bottom to disable the correct buttons.
	var relative_frame_nr: int = clampi(
			EditorCore.frame_nr - current_clip.start, 0,
			maxi(0, current_clip.duration - 1))

	var container: FoldableContainer = FoldableContainer.new()
	container.title = effect.nickname if not (is_file_effect and effect.id == "text") else "Text Properties"
	container.tooltip_text = effect.tooltip
	container.theme_type_variation = "EffectContainer"

	if not is_file_effect:
		var button_visible: TextureButton = TextureButton.new()
		var button_preset: TextureButton = TextureButton.new()
		button_visible.name = "VisibleButton"
		if effect.is_enabled:
			button_visible.texture_normal = preload(Library.ICON_VISIBLE)
		else:
			button_visible.texture_normal = preload(Library.ICON_INVISIBLE)

		button_preset.texture_normal = preload(Library.ICON_EFFECT_SETTINGS)
		button_preset.tooltip_text = tr("Presets & Options")

		@warning_ignore_start("return_value_discarded")
		button_visible.pressed.connect(_on_switch_enabled.bind(effect, is_visual))
		button_preset.pressed.connect(func() -> void:
				_show_preset_popup(false, is_visual, effect, button_preset))
		@warning_ignore_restore("return_value_discarded")

		for button: TextureButton in [button_preset, button_visible]:
			button.ignore_texture_size = true
			button.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Not a button but will act like a button. Easier to use for this use case.
		var button_drag: TextureRect = TextureRect.new()
		button_drag.texture = preload(Library.ICON_MOVE_HANDLE)
		button_drag.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
		button_drag.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		button_drag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button_drag.mouse_default_cursor_shape = Control.CURSOR_DRAG
		button_drag.mouse_filter = Control.MOUSE_FILTER_STOP
		button_drag.set_drag_forwarding(
				_get_drag_data_effect.bind(effect, is_visual), Callable(), Callable())

		container.add_title_bar_control(button_preset)
		container.add_title_bar_control(button_visible)
		container.add_title_bar_control(button_drag)
	else:
		var button_reset: TextureButton = TextureButton.new()
		button_reset.texture_normal = preload(Library.ICON_REFRESH)
		button_reset.ignore_texture_size = true
		button_reset.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
		button_reset.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button_reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button_reset.tooltip_text = tr("Reset to default")
		if button_reset.pressed.connect(_on_reset_text_effect): Print.stack_connect()
		container.add_title_bar_control(button_reset)

	var content_vbox: VBoxContainer = VBoxContainer.new()
	container.add_child(content_vbox)
	container.mouse_filter = Control.MOUSE_FILTER_PASS

	@warning_ignore("return_value_discarded")
	container.gui_input.connect(func(event: InputEvent) -> void:
			if event is not InputEventMouseButton: return

			var event_mouse_button: InputEventMouseButton = event
			if !event_mouse_button.pressed: return
			elif event_mouse_button.button_index == MOUSE_BUTTON_LEFT:
				EffectsHandler.effect_selected.emit(effect))

	# Adding effect params.
	var keyframes_found: bool = false
	if effect.custom_ui.is_empty():
		for param: EffectParam in effect.params:
			var param_hbox: HBoxContainer = create_effect_param_hbox(param, effect, is_visual)
			if param.keyframeable: keyframes_found = true
			content_vbox.add_child(param_hbox)
	else:
		for effect_ui: EffectUI in effect.custom_ui:
			if effect_ui == null: continue
			if effect_ui.param_id != "":
				var param: EffectParam = _get_param_by_id(effect, effect_ui.param_id)
				if param:
					var param_hbox: HBoxContainer = create_effect_param_hbox(param, effect, is_visual, effect_ui)
					if param.keyframeable: keyframes_found = true
					content_vbox.add_child(param_hbox)
			elif effect_ui.custom_ui != null:
				var custom_scene: Node = effect_ui.custom_ui.instantiate()
				if custom_scene.has_method("setup"):
					custom_scene.call("setup", effect, current_clip, is_visual)
				content_vbox.add_child(custom_scene)

	if keyframes_found:
		var track_scroll: ScrollContainer = ScrollContainer.new()
		track_scroll.name = "TrackScroll"
		var track: KeyframeTrack = KeyframeTrack.new()

		track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_scroll.custom_minimum_size.y = 32

		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.size_flags_vertical = Control.SIZE_EXPAND_FILL
		track.setup(effect, current_clip.duration, relative_frame_nr)

		@warning_ignore_start("return_value_discarded")
		track.keyframe_moved_effect.connect(_on_keyframe_moved_effect_ui.bind(effect, is_visual))
		track.keyframe_deleted_effect.connect(_on_keyframe_deleted_effect_ui.bind(effect, is_visual))
		track.keyframe_dragged_to.connect(_on_keyframe_dragged_to_effect_ui)
		@warning_ignore_restore("return_value_discarded")

		track_scroll.add_child(track)
		content_vbox.add_child(HSeparator.new())
		content_vbox.add_child(track_scroll)
	return container


func _get_param_by_id(effect: Effect, param_id: String) -> EffectParam:
	for param: EffectParam in effect.params:
		if param.id == param_id: return param
	return null


func _on_reset_text_effect() -> void:
	var text_effect: Effect = current_file.temp_file.text_effect
	var old_keyframes: Dictionary = Effect.duplicate_keyframes(text_effect.keyframes)

	InputManager.undo_redo.create_action("Reset text effect")
	InputManager.undo_redo.add_do_method(_reset_text_effect)
	InputManager.undo_redo.add_undo_method(_restore_text_effect_keyframes.bind(old_keyframes))
	InputManager.undo_redo.commit_action()


func _reset_text_effect() -> void:
	var text_effect: Effect = current_file.temp_file.text_effect
	text_effect.keyframes.clear()
	text_effect.set_default_keyframe()
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()


func _restore_text_effect_keyframes(old_keyframes: Dictionary) -> void:
	var text_effect: Effect = current_file.temp_file.text_effect
	text_effect.keyframes = Effect.duplicate_keyframes(old_keyframes)
	text_effect._cache_dirty = true
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()


func _on_keyframe_moved_effect_ui(old_frame: int, new_frame: int, preserve_existing: bool, is_copy: bool, effect: Effect, is_visual: bool) -> void:
	var effect_index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.move_effect_keyframe_at_frame(current_clip, effect_index, is_visual, old_frame, new_frame, preserve_existing, is_copy)
	_update_ui_values()


func _on_keyframe_deleted_effect_ui(frame: int, effect: Effect, is_visual: bool) -> void:
	var effect_index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.remove_effect_keyframe_at_frame(current_clip, effect_index, is_visual, frame)
	_update_ui_values()


func _on_keyframe_dragged_to_effect_ui(relative_frame: int) -> void:
	EditorCore.scrub_to_frame(current_clip.start + relative_frame)


func create_effect_param_hbox(param: EffectParam, effect: Effect, is_visual: bool, effect_ui: EffectUI = null) -> HBoxContainer:
	var param_hbox: HBoxContainer = HBoxContainer.new()
	var param_id: String = param.id
	param_hbox.name = "HBOX_" + param_id

	var param_title: Label = Label.new()
	var update_call: Callable = _effect_param_update_call.bind(effect, is_visual, param_id)
	var param_settings: Control = create_param_control(param, update_call, effect_ui)

	param_title.text = param.nickname.replace("param_", "").capitalize()
	param_title.tooltip_text = param.tooltip
	param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_title.clip_text = true
	param_settings.name = "PARAM_" + param_id

	var param_reset_button: TextureButton = TextureButton.new()
	param_reset_button.texture_normal = preload(Library.ICON_REFRESH)
	param_reset_button.tooltip_text = tr("Reset parameter")
	param_reset_button.ignore_texture_size = true
	param_reset_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	param_reset_button.custom_minimum_size = Vector2(14, 14)

	@warning_ignore("return_value_discarded")
	param_reset_button.pressed.connect(
			_effect_param_update_call.bind(param.default_value, effect, is_visual, param_id))

	var title_hbox: HBoxContainer = HBoxContainer.new()
	title_hbox.visible = effect_ui.show_label if effect_ui else true
	title_hbox.add_child(param_title)
	title_hbox.add_child(param_reset_button)
	title_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.size_flags_stretch_ratio = 0.4

	param_hbox.add_child(title_hbox)
	param_hbox.add_child(param_settings)

	if param.keyframeable:
		var param_prev_button: TextureButton = TextureButton.new()
		param_prev_button.name = "PREV_KEYFRAME_" + param_id
		param_prev_button.texture_normal = load(Library.ICON_PREV_KEYFRAME)
		param_prev_button.ignore_texture_size = true
		param_prev_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_prev_button.custom_minimum_size.x = 8

		@warning_ignore("return_value_discarded")
		param_prev_button.pressed.connect(_jump_prev_keyframe.bind(effect, param_id))

		var param_keyframe_button: TextureButton = TextureButton.new()
		param_keyframe_button.name = "KEYFRAME_" + param_id
		param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)
		param_keyframe_button.ignore_texture_size = true
		param_keyframe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_keyframe_button.custom_minimum_size.x = 14

		@warning_ignore("return_value_discarded")
		param_keyframe_button.pressed.connect(_keyframe_button_pressed.bind(
				effect, is_visual, param_id))

		var param_next_button: TextureButton = TextureButton.new()
		param_next_button.name = "NEXT_KEYFRAME_" + param_id
		param_next_button.texture_normal = load(Library.ICON_NEXT_KEYFRAME)
		param_next_button.ignore_texture_size = true
		param_next_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_next_button.custom_minimum_size.x = 8
		@warning_ignore("return_value_discarded")
		param_next_button.pressed.connect(_jump_next_keyframe.bind(effect, param_id))

		param_hbox.add_child(param_prev_button)
		param_hbox.add_child(param_keyframe_button)
		param_hbox.add_child(param_next_button)

	return param_hbox


func create_param_control(param: EffectParam, update_call: Callable, effect_ui: EffectUI = null) -> Control:
	var value: Variant = param.default_value
	if value == null:
		printerr(HEADER, "Value is null! %s" % param)
		value = 0

	match typeof(value):
		TYPE_STRING:
			if param.id == "font":
				var option_button: OptionButton = OptionButton.new()
				option_button.add_item("Default")
				option_button.set_item_metadata(0, "")
				var fonts: Array = Array(Settings.available_system_fonts)
				fonts.sort()
				for i: int in fonts.size():
					option_button.add_item(fonts[i] as String)
					option_button.set_item_metadata(i + 1, fonts[i])

				@warning_ignore("return_value_discarded")
				option_button.item_selected.connect(func(id: int) -> void:
						update_call.call(option_button.get_item_metadata(id)))
				option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return option_button

			if effect_ui and effect_ui.is_multiline:
				var text_edit: TextEdit = TextEdit.new()
				text_edit.placeholder_text = "Text ..."
				@warning_ignore("return_value_discarded")
				text_edit.text_changed.connect(func() -> void: update_call.call(text_edit.text))
				text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text_edit.custom_minimum_size.y = 80
				text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
				return text_edit
			else:
				var line_edit: LineEdit = LineEdit.new()
				@warning_ignore_start("return_value_discarded")
				line_edit.text_changed.connect(update_call)
				line_edit.text_submitted.connect((func() -> void: line_edit.release_focus()).unbind(1))
				@warning_ignore_restore("return_value_discarded")
				line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return line_edit
		TYPE_BOOL:
			var check_button: CheckButton = CheckButton.new()
			@warning_ignore("return_value_discarded")
			check_button.toggled.connect(update_call)
			check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return check_button
		TYPE_INT, TYPE_FLOAT:
			var horizontal: bool = param.id == "text_h_align"
			if horizontal or param.id == "text_v_align" or param.id == "mode" or param.id == "font_weight":
				var option_button: OptionButton = OptionButton.new()
				if horizontal:
					option_button.add_item("Left", HORIZONTAL_ALIGNMENT_LEFT)
					option_button.add_item("Center", HORIZONTAL_ALIGNMENT_CENTER)
					option_button.add_item("Right", HORIZONTAL_ALIGNMENT_RIGHT)
				elif param.id == "text_v_align": # Vertical.
					option_button.add_item("Top", VERTICAL_ALIGNMENT_TOP)
					option_button.add_item("Center", VERTICAL_ALIGNMENT_CENTER)
					option_button.add_item("Bottom", VERTICAL_ALIGNMENT_BOTTOM)
				elif param.id == "mode": # Blend modes.
					option_button.add_item("Mix (Normal)", 0)
					option_button.add_item("Add", 1)
					option_button.add_item("Subtract", 2)
					option_button.add_item("Multiply", 3)
					option_button.add_item("Premultiplied Alpha", 4)
				elif param.id == "font_weight":
					option_button.add_item("Thin", 100)
					option_button.add_item("Extra Light", 200)
					option_button.add_item("Light", 300)
					option_button.add_item("Regular", 400)
					option_button.add_item("Medium", 500)
					option_button.add_item("Semi Bold", 600)
					option_button.add_item("Bold", 700)
					option_button.add_item("Extra Bold", 800)
					option_button.add_item("Black", 900)
				@warning_ignore("return_value_discarded")
				option_button.item_selected.connect(func(index: int) -> void:
						update_call.call(option_button.get_item_id(index)))
				option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return option_button
			var spinbox: SpinBox = SpinBox.new()
			spinbox.min_value = param.min_value if param.min_value != null else MIN_VALUE
			spinbox.max_value = param.max_value if param.max_value != null else MAX_VALUE
			spinbox.step = param.step if param.step > 0.0 else (0.01 if typeof(value) == TYPE_FLOAT else 1.0)
			spinbox.allow_lesser = param.min_value == null
			spinbox.allow_greater = param.max_value == null
			spinbox.custom_arrow_step = spinbox.step

			var scroll_handler: Callable = func(event: InputEvent) -> void:
					if event is InputEventMouseButton:
						var mouse_event: InputEventMouseButton = event
						if !mouse_event.pressed:
							return
						elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
							spinbox.value += spinbox.step
							spinbox.accept_event()
						elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
							spinbox.value -= spinbox.step
							spinbox.accept_event()

			@warning_ignore_start("return_value_discarded")
			spinbox.gui_input.connect(scroll_handler)
			spinbox.get_line_edit().gui_input.connect(scroll_handler)
			@warning_ignore_restore("return_value_discarded")

			if param.has_slider:
				var hbox: HBoxContainer = HBoxContainer.new()
				var slider: HSlider = HSlider.new()
				slider.name = "Slider"
				spinbox.name = "SpinBox"
				slider.min_value = param.min_value if param.min_value != null else 0.0
				slider.max_value = param.max_value if param.max_value != null else 100.0
				slider.step = spinbox.step
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

				var slider_range: float = slider.max_value - slider.min_value
				if slider.step > 0.0 and (slider_range / slider.step) <= 20.0:
					slider.tick_count = int(slider_range / slider.step) + 1
				else:
					slider.tick_count = 13
				slider.ticks_on_borders = true

				@warning_ignore("return_value_discarded")
				slider.value_changed.connect(func(val: float) -> void:
						spinbox.set_value_no_signal(val)
						update_call.call(val))

				@warning_ignore("return_value_discarded")
				spinbox.value_changed.connect(func(val: float) -> void:
						if spinbox.get_line_edit().has_focus():
							spinbox.get_line_edit().release_focus()
						slider.set_value_no_signal(val)
						update_call.call(val))

				hbox.add_child(slider)
				hbox.add_child(spinbox)
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return hbox
			else:
				@warning_ignore("return_value_discarded")
				spinbox.value_changed.connect(func(val: float) -> void:
						if spinbox.get_line_edit().has_focus():
							spinbox.get_line_edit().release_focus()
						update_call.call(val))
				spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return spinbox
		TYPE_VECTOR2, TYPE_VECTOR2I:
			var hbox: HBoxContainer = HBoxContainer.new()
			var spinbox_x: SpinBox = SpinBox.new()
			var spinbox_y: SpinBox = SpinBox.new()
			spinbox_x.name = "SpinBoxX"
			spinbox_y.name = "SpinBoxY"

			# X
			spinbox_x.min_value = param.min_value.x if param.min_value != null else MIN_VALUE
			spinbox_x.max_value = param.max_value.x if param.max_value != null else MAX_VALUE
			spinbox_x.step = param.step if param.step > 0.0 else (0.01 if typeof(value) == TYPE_VECTOR2 else 1.0)
			spinbox_x.allow_lesser = param.min_value == null
			spinbox_x.allow_greater = param.max_value == null
			spinbox_x.custom_arrow_step = spinbox_x.step
			spinbox_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if param.is_linkable and param.is_linked:
				spinbox_x.prefix = ""
			else:
				spinbox_x.prefix = "X:"

			@warning_ignore("return_value_discarded")
			spinbox_x.value_changed.connect(func(new_value: float) -> void:
					if spinbox_x.get_line_edit().has_focus():
						spinbox_x.get_line_edit().release_focus()
					if param.is_linkable and param.is_linked:
						spinbox_y.set_value_no_signal(new_value)
					var vector_val: Variant = Vector2(new_value, spinbox_y.value)
					if typeof(value) == TYPE_VECTOR2I:
						vector_val = Vector2i(vector_val as Vector2)
					update_call.call(vector_val))

			var scroll_handler_x: Callable = func(event: InputEvent) -> void:
					if event is InputEventMouseButton:
						var mouse_event: InputEventMouseButton = event
						if !mouse_event.pressed:
							return
						if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
							spinbox_x.value += spinbox_x.step
							spinbox_x.accept_event()
						elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
							spinbox_x.value -= spinbox_x.step
							spinbox_x.accept_event()

			if spinbox_x.gui_input.connect(scroll_handler_x): Print.stack_connect()
			if spinbox_x.get_line_edit().gui_input.connect(scroll_handler_x): Print.stack_connect()

			# Y
			spinbox_y.min_value = param.min_value.y if param.min_value != null else MIN_VALUE
			spinbox_y.max_value = param.max_value.y if param.max_value != null else MAX_VALUE
			spinbox_y.step = param.step if param.step > 0.0 else (0.01 if typeof(value) == TYPE_VECTOR2 else 1.0)
			spinbox_y.allow_lesser = param.min_value == null
			spinbox_y.allow_greater = param.max_value == null
			spinbox_y.custom_arrow_step = spinbox_y.step
			spinbox_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			@warning_ignore("return_value_discarded")
			spinbox_y.value_changed.connect(func(new_value: float) -> void:
					if spinbox_y.get_line_edit().has_focus():
						spinbox_y.get_line_edit().release_focus()
					if param.is_linkable and param.is_linked:
						spinbox_x.set_value_no_signal(new_value)
					var vector_val: Variant = Vector2(spinbox_x.value, new_value)
					if typeof(value) == TYPE_VECTOR2I:
						vector_val = Vector2i(vector_val as Vector2)
					update_call.call(vector_val))

			var scroll_handler_y: Callable = func(event: InputEvent) -> void:
					if event is InputEventMouseButton:
						var mouse_event: InputEventMouseButton = event
						if !mouse_event.pressed:
							return
						if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
							spinbox_y.value += spinbox_y.step
							spinbox_y.accept_event()
						elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
							spinbox_y.value -= spinbox_y.step
							spinbox_y.accept_event()
			@warning_ignore_start("return_value_discarded")
			spinbox_y.gui_input.connect(scroll_handler_y)
			spinbox_y.get_line_edit().gui_input.connect(scroll_handler_y)
			@warning_ignore_restore("return_value_discarded")

			hbox.add_child(spinbox_x)

			if param.is_linkable:
				var link_button: TextureButton = TextureButton.new()
				link_button.texture_normal = preload(Library.ICON_LINK)
				link_button.toggle_mode = true
				link_button.button_pressed = param.is_linked
				link_button.modulate = Color(1, 1, 1, 1) if link_button.button_pressed else Color(1, 1, 1, 0.5)
				link_button.ignore_texture_size = true
				link_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				link_button.custom_minimum_size = Vector2(14, 14)
				link_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				link_button.tooltip_text = "Link X and Y"

				if link_button.toggled.connect(func(toggled: bool) -> void:
						param.is_linked = toggled
						link_button.modulate = Color(1, 1, 1, 1) if toggled else Color(1, 1, 1, 0.5)
						spinbox_y.visible = not toggled
						spinbox_x.prefix = "" if toggled else "X:" # NO_TRANSLATE
						if toggled:
							spinbox_y.set_value_no_signal(spinbox_x.value)
							spinbox_y.value_changed.emit(spinbox_x.value)): Print.stack_connect()
				hbox.add_child(link_button)

			hbox.add_child(spinbox_y)
			spinbox_y.visible = not param.is_linked
			spinbox_y.prefix = "Y:" # NO_TRANSLATE
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return hbox
		TYPE_COLOR:
			var color_picker: ColorPickerButton = ColorPickerButton.new()
			color_picker.custom_minimum_size.x = 40
			color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			@warning_ignore("return_value_discarded")
			color_picker.color_changed.connect(update_call)
			return color_picker
	return Control.new() # Fallback.


func _get_effect_index(effect: Effect, is_visual: bool) -> int:
	if is_visual:
		return current_clip.effects.video.find(effect)
	return current_clip.effects.audio.find(effect)


func _get_current_ui_value_for_param(effect: Effect, param_id: String, relative_frame_nr: int) -> Variant:
	for param: EffectParam in effect.params:
		if param.id == param_id:
			return effect.get_value(param, relative_frame_nr)
	return null


func _on_remove_effect(effect: Effect, is_visual: bool) -> void:
	var index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.remove_effect(current_clip, index, is_visual)


func _on_reset_effect(effect: Effect, is_visual: bool) -> void:
	var index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.reset_effect(current_clip, index, is_visual)


func _update_ui_values() -> void:
	if !current_clip or !ClipLogic.clips.has(current_clip.id):
		current_clip = null
		return

	clip_enable_visuals_button.set_pressed_no_signal(current_clip.effects.is_showing)
	clip_enable_audio_button.set_pressed_no_signal(!current_clip.effects.is_muted)
	var frame_nr: int = clampi(EditorCore.frame_nr - current_clip.start, 0, maxi(0, current_clip.duration - 1))
	if section_text.visible and section_text.get_child_count() > 0:
		var text_effect: Effect = current_file.temp_file.text_effect
		var container: FoldableContainer = section_text.get_child(0)
		_update_ui_values_for_container(text_effect, container.get_child(0) as VBoxContainer, frame_nr)

	for i: int in current_clip.effects.video.size():
		_update_ui_values_effect(current_clip.effects.video, i, frame_nr)
	for i: int in current_clip.effects.audio.size():
		_update_ui_values_effect(current_clip.effects.audio, i, frame_nr)

	if !section_transitions.visible or section_transitions.get_child_count() <= 0: return
	var transition_vbox: VBoxContainer = section_transitions.get_child(0)

	if current_clip.effects.transition_left:
		for param: EffectParam in current_clip.effects.transition_left.params:
			var hbox: HBoxContainer = transition_vbox.get_node_or_null(NodePath("LEFT_" + param.id)) as HBoxContainer
			if hbox and hbox.get_child_count() > 1:
				_set_param_settings_value(hbox.get_child(1) as Control, current_clip.effects.transition_left.get_value(param, 0))

	if current_clip.effects.transition_right:
		for param: EffectParam in current_clip.effects.transition_right.params:
			var hbox: HBoxContainer = transition_vbox.get_node_or_null(NodePath("RIGHT_" + param.id)) as HBoxContainer
			if hbox and hbox.get_child_count() > 1:
				_set_param_settings_value(hbox.get_child(1) as Control, current_clip.effects.transition_right.get_value(param, 0))


func _update_ui_values_for_container(effect: Effect, content_vbox: VBoxContainer, frame_nr: int) -> void:
	var keyframes_found: bool = false

	for param: EffectParam in effect.params:
		var param_id: String = param.id
		var param_hbox: HBoxContainer = content_vbox.get_node_or_null("HBOX_" + param_id)
		if not param_hbox: continue

		var reset_button: TextureButton = param_hbox.get_child(0).get_child(1)
		var param_settings: Control = param_hbox.get_node("PARAM_" + param_id)
		var value: Variant = effect.get_value(param, frame_nr)
		_set_param_settings_value(param_settings, value)

		reset_button.visible = not _is_same_value(value, param.default_value)

		if param.keyframeable:
			var keyframe_button: TextureButton = param_hbox.get_node_or_null("KEYFRAME_" + param_id)
			if keyframe_button:
				var effect_keyframes: Dictionary = effect.keyframes[param_id]
				if effect_keyframes.has(frame_nr):
					keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
				else:
					keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)
			keyframes_found = true

	if keyframes_found:
		var track_scroll: ScrollContainer = content_vbox.get_node_or_null("TrackScroll")
		if track_scroll:
			var track: KeyframeTrack = track_scroll.get_child(0)
			track.current_relative_frame = frame_nr
			track.clip_duration = current_clip.duration
			track.queue_redraw()


func _update_ui_values_effect(effects: Array, index: int, frame_nr: int) -> void:
	var effect: Effect = effects[index]
	var section: FoldableContainer
	var child_offset: int = 0
	if effects == current_clip.effects.video:
		if effect.id == "pck_effect_params":
			section = section_module
			child_offset = -index
		else:
			section = section_visuals
			for i: int in range(0, index):
				if effects[i].id == "pck_effect_params":
					child_offset -= 1
	else:
		section = section_audio
		if current_file and current_file.audio_streams.size() > 1:
			child_offset = 2

	var effect_container: FoldableContainer = section.get_child(0).get_child(0).get_child(index + child_offset)
	var content_vbox: VBoxContainer = effect_container.get_child(0)
	if !effect.is_enabled:
		effect_container.folded = true

	_update_ui_values_for_container(effect, content_vbox, frame_nr)


func _is_same_value(value_a: Variant, value_b: Variant) -> bool:
	if typeof(value_a) in [TYPE_FLOAT, TYPE_INT] and typeof(value_b) in [TYPE_FLOAT, TYPE_INT]:
		return is_equal_approx(value_a as float, value_b as float)
	elif typeof(value_a) in [TYPE_VECTOR2, TYPE_VECTOR2I] and typeof(value_b) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		return (value_a as Vector2).is_equal_approx(value_b as Vector2)
	elif value_a is Color and value_b is Color:
		return (value_a as Color).is_equal_approx(value_b as Color)
	return value_a == value_b


func _set_param_settings_value(param_settings: Control, value: Variant) -> void:
	if param_settings is LineEdit:
		var line_edit: LineEdit = param_settings
		if line_edit.text != str(value):
			line_edit.text = str(value)
	elif param_settings is TextEdit:
		var text_edit: TextEdit = param_settings
		if text_edit.text != str(value):
			text_edit.text = str(value)
	elif param_settings is OptionButton:
		var option_button: OptionButton = param_settings
		for i: int in option_button.item_count:
			if option_button.get_item_metadata(i) == value:
				option_button.selected = i
				break
	elif param_settings is SpinBox:
		var spinbox: SpinBox = param_settings
		spinbox.set_value_no_signal(value as float)
	elif param_settings is CheckButton:
		var check_button: CheckButton = param_settings
		check_button.set_pressed_no_signal(value as bool)
	elif param_settings is HBoxContainer:
		if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_VECTOR2I:
			var spinbox_x: SpinBox = param_settings.get_node("SpinBoxX")
			var spinbox_y: SpinBox = param_settings.get_node("SpinBoxY")
			spinbox_x.set_value_no_signal(value.x as float)
			spinbox_y.set_value_no_signal(value.y as float)
		elif param_settings.has_node("Slider") and param_settings.has_node("SpinBox"):
			var slider: HSlider = param_settings.get_node("Slider")
			var spinbox: SpinBox = param_settings.get_node("SpinBox")
			slider.set_value_no_signal(value as float)
			spinbox.set_value_no_signal(value as float)
	elif param_settings is ColorPickerButton:
		var color_picker: ColorPickerButton = param_settings
		color_picker.color = value
	else:
		printerr(HEADER, "Invalid param settings control! %s - %s" % [param_settings, typeof(param_settings)])


func _on_switch_enabled(effect: Effect, is_visual: bool) -> void:
	var index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.switch_enabled(current_clip, index, is_visual)
	var section: FoldableContainer = section_visuals if is_visual else section_audio
	var child_offset: int = 0
	if not is_visual and current_file and current_file.audio_streams.size() > 1:
		child_offset = 2
	var effect_container: FoldableContainer = section.get_child(0).get_child(0).get_child(index + child_offset)
	var visible_button: TextureButton = effect_container.find_child("VisibleButton", true, false)
	var is_enabled: bool

	if is_visual:
		effect_container.folded = !current_clip.effects.video[index].is_enabled
	else:
		effect_container.folded = !current_clip.effects.audio[index].is_enabled

	if effect_container.folded:
		visible_button.texture_normal = load(Library.ICON_INVISIBLE)
	else:
		visible_button.texture_normal = load(Library.ICON_VISIBLE)


## Type: 0 = All, 1 = Visuals, 2 = Audio
func _get_add_effects_button(type: int) -> TextureButton:
	var texture_button: TextureButton = TextureButton.new()
	texture_button.texture_normal = preload(Library.ICON_ADD)
	texture_button.tooltip_text = tr("Add effects")
	texture_button.ignore_texture_size = true
	texture_button.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
	texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	texture_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	@warning_ignore("return_value_discarded")
	texture_button.pressed.connect(_open_add_effects_popup.bind(type, true))
	return texture_button


## Type: 0 = All, 1 = Visuals, 2 = Audio.
## From_add_button is to avoid adding effects to all clips when using Ctrl+A.
func _open_add_effects_popup(type: int, from_add_button: bool) -> void:
	if current_clip:
		var popup: Control = PopupManager.get_popup(PopupManager.ADD_EFFECTS)
		var pass_clips: Array[ClipData] = []
		if from_add_button:
			pass_clips.append(current_clip)
		else:
			pass_clips.assign(ClipLogic.selected_clips)
		popup.call("load_effects", type, pass_clips)


func _effect_param_update_call(value: Variant, effect: Effect, is_visual: bool, param_id: String) -> void:
	EffectsHandler.effect_selected.emit(effect)
	if current_file and current_file.temp_file and current_file.temp_file.text_effect == effect:
		var frame_nr: int = clampi(EditorCore.frame_nr - current_clip.start, 0, maxi(0, current_clip.duration - 1))
		var param_obj: EffectParam = _get_param_by_id(effect, param_id)
		var is_keyframeable: bool = param_obj.keyframeable if param_obj else false
		var param_keyframes: Dictionary = effect.keyframes[param_id]

		if param_keyframes.size() <= 1 or not is_keyframeable:
			var base_frame: int = param_keyframes.keys()[0] if param_keyframes.size() > 0 else 0
			var old_value: Variant = param_keyframes.get(base_frame, param_obj.default_value)
			FileLogic.update_text_param(current_file, param_id, base_frame, value, old_value, false)
		else:
			var is_new: bool = not param_keyframes.has(frame_nr)
			var old_value: Variant = param_keyframes[frame_nr] if not is_new else effect.get_value(param_obj, frame_nr)
			FileLogic.update_text_param(current_file, param_id, frame_nr, value, old_value, is_new)
	else:
		EffectsHandler.update_param(
				current_clip, _get_effect_index(effect, is_visual), is_visual, param_id, value, false)


func _jump_prev_keyframe(effect: Effect, param_id: String) -> void:
	if not effect.keyframes.has(param_id):
		EditorCore.set_frame(current_clip.start)
		return
	var relative_frame: int = clampi(EditorCore.visual_frame_nr - current_clip.start, 0, maxi(0, current_clip.duration - 1))
	var keys: Array = (effect.keyframes[param_id] as Dictionary).keys()
	keys.sort()
	var target: int = 0
	for index: int in range(keys.size() - 1, -1, -1):
		if keys[index] < relative_frame:
			target = keys[index]
			break
	EditorCore.set_frame(current_clip.start + target)


func _jump_next_keyframe(effect: Effect, param_id: String) -> void:
	if not effect.keyframes.has(param_id):
		EditorCore.set_frame(current_clip.end)
		return
	var relative_frame: int = clampi(EditorCore.visual_frame_nr - current_clip.start, 0, maxi(0, current_clip.duration - 1))
	var keys: Array = (effect.keyframes[param_id] as Dictionary).keys()
	keys.sort()
	var target: int = current_clip.duration
	for key: int in keys:
		if key > relative_frame:
			target = key
			break
	EditorCore.set_frame(current_clip.start + target)


func _keyframe_button_pressed(effect: Effect, is_visual: bool, param_id: String) -> void:
	var relative_frame_nr: int = clampi(EditorCore.frame_nr - current_clip.start, 0, maxi(0, current_clip.duration - 1))

	if current_file and current_file.temp_file and current_file.temp_file.text_effect == effect:
		var param_keyframes: Dictionary = effect.keyframes[param_id]
		if !param_keyframes.has(relative_frame_nr):
			var param_obj: EffectParam = _get_param_by_id(effect, param_id)
			var value: Variant = effect.get_value(param_obj, relative_frame_nr)
			FileLogic.update_text_param(current_file, param_id, relative_frame_nr, value, null, true)
		elif relative_frame_nr != 0:
			FileLogic.remove_text_keyframe(current_file, param_id, relative_frame_nr)
		_update_ui_values()
	else:
		var index: int = _get_effect_index(effect, is_visual)
		var effect_keyframes: Dictionary = effect.keyframes[param_id]
		if effect_keyframes.has(relative_frame_nr):
			if relative_frame_nr != 0:
				EffectsHandler.remove_keyframe(current_clip, index, is_visual, param_id, relative_frame_nr)
		else:
			var value: Variant = _get_current_ui_value_for_param(effect, param_id, relative_frame_nr)
			EffectsHandler.update_param(current_clip, index, is_visual, param_id, value, true)
		_update_ui_values()


#--- Preset stuff ---

func _get_section_preset_button(is_visual: bool) -> TextureButton:
	var texture_button: TextureButton = TextureButton.new()
	texture_button.texture_normal = preload(Library.ICON_EFFECT_SETTINGS)
	texture_button.tooltip_text = tr("Presets")
	texture_button.ignore_texture_size = true
	texture_button.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
	texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	texture_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	@warning_ignore("return_value_discarded")
	texture_button.pressed.connect(func() -> void: _show_preset_popup(true, is_visual, null, texture_button))
	return texture_button


func _show_preset_popup(is_section: bool, is_visual: bool, effect: Effect, button: Control) -> void:
	var popup: PopupPanel = PopupPanel.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	popup.add_child(vbox)
	vbox.add_theme_constant_override("separation", 5)

	if !is_section:
		var button_reset: Button = Button.new()
		button_reset.text = tr("Reset effect")
		button_reset.icon = preload(Library.ICON_REFRESH)
		button_reset.expand_icon = true
		button_reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button_reset.flat = true

		@warning_ignore("return_value_discarded")
		button_reset.pressed.connect(func() -> void:
				_on_reset_effect(effect, is_visual)
				popup.queue_free())
		vbox.add_child(button_reset)

		var button_delete: Button = Button.new()
		button_delete.text = tr("Delete effect")
		button_delete.icon = preload(Library.ICON_DELETE)
		button_delete.expand_icon = true
		button_delete.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button_delete.flat = true

		@warning_ignore("return_value_discarded")
		button_delete.pressed.connect(func() -> void:
				_on_remove_effect(effect, is_visual)
				popup.queue_free())
		vbox.add_child(button_delete)
		vbox.add_child(HSeparator.new())

	var button_save: Button = Button.new()
	button_save.text = tr("Save as preset...")
	button_save.icon = preload(Library.ICON_ADD)
	button_save.expand_icon = true
	button_save.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button_save.flat = true

	@warning_ignore("return_value_discarded")
	button_save.pressed.connect(func() -> void:
			_prompt_save_preset(is_section, is_visual, effect)
			popup.queue_free())
	vbox.add_child(button_save)
	vbox.add_child(HSeparator.new())

	var prefix: String = ("visual" if is_visual else "audio") if is_section else effect.id
	if is_section:
		var default_hbox: HBoxContainer = HBoxContainer.new()
		var button_default: Button = Button.new()
		button_default.text = tr("Default")
		button_default.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button_default.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button_default.flat = true

		@warning_ignore("return_value_discarded")
		button_default.pressed.connect(func() -> void:
				_apply_default_section_preset(is_visual)
				popup.queue_free())
		default_hbox.add_child(button_default)
		vbox.add_child(default_hbox)

	var dir: DirAccess = DirAccess.open(PRESETS_PATH)
	if dir:
		if dir.list_dir_begin():
			printerr(HEADER, "Couldn't go to beginning of '%s' directory!" % PRESETS_PATH)

		var file_name: String = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.begins_with(prefix + "_") and file_name.ends_with(".preset"):
				var preset_name: String = file_name.trim_prefix(prefix + "_").trim_suffix(".preset")
				var hbox: HBoxContainer = HBoxContainer.new()
				var button_apply: Button = Button.new()
				button_apply.text = preset_name
				button_apply.alignment = HORIZONTAL_ALIGNMENT_LEFT
				button_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button_apply.flat = true
				@warning_ignore("return_value_discarded")
				button_apply.pressed.connect(func() -> void:
						_apply_preset(PRESETS_PATH + file_name, is_section, is_visual, effect)
						popup.queue_free())
				var button_delete: TextureButton = TextureButton.new()
				button_delete.texture_normal = preload(Library.ICON_DELETE)
				button_delete.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
				button_delete.ignore_texture_size = true
				button_delete.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				@warning_ignore("return_value_discarded")
				button_delete.pressed.connect(func() -> void:
						DirAccess.remove_absolute(PRESETS_PATH + file_name)
						hbox.queue_free())
				hbox.add_child(button_apply)
				hbox.add_child(button_delete)
				vbox.add_child(hbox)
			file_name = dir.get_next()

	@warning_ignore("return_value_discarded")
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	popup.position = Vector2i(button.get_screen_transform().origin) + Vector2i(0, int(button.size.y))
	popup.popup()


func _prompt_save_preset(is_section: bool, is_visual: bool, effect: Effect) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	var vbox: VBoxContainer = VBoxContainer.new()
	var line_edit: LineEdit = LineEdit.new()
	dialog.title = tr("Save preset")
	line_edit.placeholder_text = tr("Preset name")
	vbox.add_child(line_edit)
	dialog.add_child(vbox)

	var confirm_lambda: Callable = func() -> void:
			var preset_name: String = line_edit.text.strip_edges()
			if preset_name.is_empty():
				preset_name = "Custom"
			var prefix: String = ("visual" if is_visual else "audio") if is_section else effect.id
			var path: String = PRESETS_PATH + prefix + "_" + preset_name.validate_filename() + ".preset"

			var save_data: Variant
			if is_section:
				var serialized_effects: Array = []
				var effects: Array
				if is_visual:
					effects = current_clip.effects.video
				else:
					effects = current_clip.effects.audio

				for clip_effect: Effect in effects:
					serialized_effects.append(clip_effect.serialize())
				save_data = serialized_effects
			else:
				save_data = effect.serialize()

			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file:
				@warning_ignore("return_value_discarded")
				file.store_var(save_data)
				file.close()
			else:
				printerr(HEADER, "Could not save preset to '%s'!" % path)
			dialog.queue_free()

	@warning_ignore_start("return_value_discarded")
	dialog.confirmed.connect(confirm_lambda)
	line_edit.text_submitted.connect(func(_text: String) -> void: confirm_lambda.call())
	dialog.canceled.connect(dialog.queue_free)
	@warning_ignore_restore("return_value_discarded")

	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 100))
	line_edit.grab_focus()


func _apply_preset(path: String, is_section: bool, is_visual: bool, effect: Effect) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var data: Variant = file.get_var()
	file.close()

	if is_section:
		if typeof(data) != TYPE_ARRAY:
			return

		var new_effects: Array = []
		for effect_value: Variant in data as Array:
			var effect_id: String = (effect_value as Dictionary).get("id", "")
			var new_effect: Effect
			if is_visual and EffectsHandler.visual_effect_instances.has(effect_id):
				new_effect = EffectsHandler.visual_effect_instances[effect_id].deep_copy()
			elif not is_visual and EffectsHandler.audio_effect_instances.has(effect_id):
				new_effect = EffectsHandler.audio_effect_instances[effect_id].deep_copy()
			else:
				continue
			new_effect.deserialize(effect_value as Dictionary)
			EffectsHandler._apply_param_exceptions(new_effect)
			new_effect.set_default_keyframe()
			new_effects.append(new_effect)

		var old_effects: Array = _copy_effect_array(current_clip.effects.video as Array if is_visual else current_clip.effects.audio as Array)

		InputManager.undo_redo.create_action("Apply section preset")
		InputManager.undo_redo.add_do_method(_set_section_effects.bind(current_clip, new_effects, is_visual))
		InputManager.undo_redo.add_undo_method(_set_section_effects.bind(current_clip, old_effects, is_visual))
		InputManager.undo_redo.commit_action()
	elif typeof(data) == TYPE_DICTIONARY:
		var effect_id: String = (data as Dictionary).get("id", "")
		var new_effect: Effect
		if is_visual and EffectsHandler.visual_effect_instances.has(effect_id):
			new_effect = EffectsHandler.visual_effect_instances[effect_id].deep_copy()
		elif not is_visual and EffectsHandler.audio_effect_instances.has(effect_id):
			new_effect = EffectsHandler.audio_effect_instances[effect_id].deep_copy()
		else:
			return
		new_effect.deserialize(data as Dictionary)
		EffectsHandler._apply_param_exceptions(new_effect)
		new_effect.set_default_keyframe()

		var old_effect: Effect = effect.deep_copy()
		old_effect.keyframes = effect.keyframes.duplicate(true)
		InputManager.undo_redo.create_action("Apply effect preset")

		var index: int = _get_effect_index(effect, is_visual)
		InputManager.undo_redo.add_do_method(_replace_effect.bind(current_clip, index, new_effect, is_visual))
		InputManager.undo_redo.add_undo_method(_replace_effect.bind(current_clip, index, old_effect, is_visual))
		InputManager.undo_redo.commit_action()


func _apply_default_section_preset(is_visual: bool) -> void:
	InputManager.undo_redo.create_action("Apply default preset")
	var old_effects: Array = _copy_effect_array(current_clip.effects.video as Array if is_visual else current_clip.effects.audio as Array)
	var new_effects: Array = []
	if is_visual:
		var transform_effect: Effect = (load(Library.EFFECT_VISUAL_TRANSFORM) as Effect).deep_copy()
		for param: EffectParam in transform_effect.params:
			if param.id == "pivot":
				param.default_value = Vector2i(Project.get_resolution() / 2.0)
		transform_effect.set_default_keyframe()
		new_effects.append(transform_effect)
	else:
		var volume_effect: Effect = (load(Library.EFFECT_AUDIO_VOLUME) as Effect).deep_copy()
		volume_effect.set_default_keyframe()
		new_effects.append(volume_effect)

	InputManager.undo_redo.add_do_method(_set_section_effects.bind(current_clip, new_effects, is_visual))
	InputManager.undo_redo.add_undo_method(_set_section_effects.bind(current_clip, old_effects, is_visual))
	InputManager.undo_redo.commit_action()


func _set_section_effects(clip: ClipData, effects: Array, is_visual: bool) -> void:
	var cloned_effects: Array = _copy_effect_array(effects)
	if is_visual:
		clip.effects.video.assign(cloned_effects)
	else:
		clip.effects.audio.assign(cloned_effects)
	Project.unsaved_changes = true
	_load_effects()
	EffectsHandler.effects_updated.emit()


func _replace_effect(clip: ClipData, index: int, new_effect: Effect, is_visual: bool) -> void:
	var cloned_effect: Effect = new_effect.deep_copy()
	cloned_effect.keyframes = new_effect.keyframes.duplicate(true)
	if is_visual:
		clip.effects.video[index] = cloned_effect
	else:
		clip.effects.audio[index] = cloned_effect
	Project.unsaved_changes = true
	_load_effects()
	EffectsHandler.effects_updated.emit()


func _copy_effect_array(array: Array) -> Array:
	var data: Array = []
	for effect: Effect in array:
		var copy: Effect = effect.deep_copy()
		copy.keyframes = effect.keyframes.duplicate(true)
		data.append(copy)
	return data


func _on_transition_updated(clip: ClipData, _is_left: bool) -> void:
	if current_clip and clip.id == current_clip.id:
		if section_transitions.get_child_count() != 0:
			var vbox: VBoxContainer = section_transitions.get_child(0)
			section_transitions.remove_child(vbox)
			vbox.queue_free()
		var vbox_transitions: VBoxContainer = VBoxContainer.new()
		section_transitions.add_child(vbox_transitions)
		_create_transitions_ui(vbox_transitions)


func _on_visuals_enable_button_toggled(toggled_on: bool) -> void:
	if current_clip and current_clip.effects.is_showing != toggled_on:
		ClipLogic.toggle_clip_visible(current_clip, toggled_on)
	section_visuals.folded = !toggled_on


func _on_audio_enable_button_toggled(toggled_on: bool) -> void:
	if current_clip and current_clip.effects.is_muted == toggled_on:
		ClipLogic.toggle_clip_mute(current_clip, !toggled_on)
	section_audio.folded = !toggled_on


#---- Transition spinbox stuff ----

func _on_visual_in_value_changed(value: float, clip_effects: ClipEffects, spinbox: SpinBox) -> void:
	if spinbox.get_line_edit().has_focus():
		EffectsHandler.set_fade(current_clip, true, Vector2i(int(value), clip_effects.fade_visual.y))


func _on_visual_out_value_changed(value: float, clip_effects: ClipEffects, spinbox: SpinBox) -> void:
	if spinbox.get_line_edit().has_focus():
		EffectsHandler.set_fade(current_clip, true, Vector2i(clip_effects.fade_visual.x, int(value)))


func _on_audio_in_value_changed(value: float, clip_effects: ClipEffects, spinbox: SpinBox) -> void:
	if spinbox.get_line_edit().has_focus():
		EffectsHandler.set_fade(current_clip, false, Vector2i(int(value), clip_effects.fade_audio.y))


func _on_audio_out_value_changed(value: float, clip_effects: ClipEffects, spinbox: SpinBox) -> void:
	if spinbox.get_line_edit().has_focus():
		EffectsHandler.set_fade(current_clip, false, Vector2i(clip_effects.fade_audio.x, int(value)))


func _on_transition_in_style_item_selected(index: int, option_button: OptionButton) -> void:
	var transition_id: String = EffectsHandler.transitions[option_button.get_item_text(index)]
	EffectsHandler.set_transition(current_clip, true, transition_id)


func _on_transition_out_style_item_selected(index: int, option_button: OptionButton) -> void:
	var transition_id: String = EffectsHandler.transitions[option_button.get_item_text(index)]
	EffectsHandler.set_transition(current_clip, false, transition_id)
