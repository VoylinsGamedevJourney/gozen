class_name EffectsPanel
extends PanelContainer


signal update_values(frame_nr: int)


const MIN_VALUE: float = -100000
const MAX_VALUE: float = 100000

const COLOR_KEYFRAMING_ON: Color = Color(1, 1, 1, 1)
const COLOR_KEYFRAMING_OFF: Color = Color(1, 1, 1, 0.5)

const SIZE_EFFECT_HEADER_ICON: Vector2i = Vector2i(16, 16)


@export var section_text: VBoxContainer
@export var section_visuals: FoldableContainer
@export var section_audio: FoldableContainer


var current_clip: ClipData = null
var current_file: FileData = null

var drop_indicator_pos: int = -1
var drop_indicator_vbox: VBoxContainer = null



func _ready() -> void:
	Project.project_ready.connect(_project_ready)
	EditorCore.visual_frame_changed.connect(_on_frame_changed)
	EffectsHandler.effect_added.connect(_on_effect_added)
	EffectsHandler.effect_removed.connect(_on_effect_removed)
	EffectsHandler.effect_moved.connect(_on_effect_moved)
	EffectsHandler.effects_updated.connect(_on_effects_updated.bind(null))
	EffectsHandler.effect_values_updated.connect(_update_ui_values)

	section_visuals.add_title_bar_control(_get_add_effects_button(true))
	section_audio.add_title_bar_control(_get_add_effects_button(false))
	section_visuals.folded = true
	section_audio.folded = true


func _project_ready() -> void:
	ClipLogic.deleted.connect(_on_clip_deleted)
	ClipLogic.selected.connect(_on_clip_pressed)


func _input(event: InputEvent) -> void:
	if !PopupManager._open_popups.is_empty():
		return
	if Project.is_loaded and event.is_action_pressed("ui_cancel"):
		_on_clip_pressed(null)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drop_indicator_pos = -1
		if drop_indicator_vbox:
			drop_indicator_vbox.queue_redraw()
			drop_indicator_vbox = null


func _get_drag_data_effect(_pos: Vector2, effect: Effect, is_visual: bool) -> Variant:
	var index: int = _get_effect_index(effect, is_visual)
	var drag_data: DragData = DragData.new()
	var preview: Label = Label.new()
	drag_data.is_visual = is_visual
	drag_data.effect_index = index
	drag_data.effect = effect
	preview.text = "Moving: " + effect.nickname
	set_drag_preview(preview)

	return drag_data


func _can_drop_effect(at_position: Vector2, data: Variant, is_visual: bool, vbox: VBoxContainer) -> bool:
	if not data is DragData or data.is_visual != is_visual:
		drop_indicator_vbox = null
		drop_indicator_pos = -1
		vbox.queue_redraw()
		return false

	var drop_index: int = 0
	for index: int in vbox.get_child_count():
		var child: Control = vbox.get_child(index)
		if at_position.y > child.position.y + (child.size.y / 2.0):
			drop_index = index + 1
	drop_indicator_pos = drop_index
	drop_indicator_vbox = vbox
	vbox.queue_redraw()
	return true


func _drop_effect(at_position: Vector2, data: Variant, is_visual: bool, vbox: VBoxContainer) -> void:
	drop_indicator_pos = -1
	drop_indicator_vbox = null
	vbox.queue_redraw()
	if not data is DragData or data.is_visual != is_visual:
		return

	var old_index: int = data.effect_index
	var new_index: int = 0
	for index: int in vbox.get_child_count():
		var child: Control = vbox.get_child(index)
		if at_position.y > child.position.y + (child.size.y / 2.0):
			new_index = index + 1
	if new_index > old_index:
		new_index -= 1 # Adjust since the element itself will be shifted
	if old_index != new_index:
		EffectsHandler.move_effect(current_clip, old_index, new_index, is_visual)


func _draw_drop_indicator(vbox: VBoxContainer) -> void:
	if drop_indicator_vbox != vbox or drop_indicator_pos == -1:
		return
	var y_pos: float = 0.0
	if drop_indicator_pos < vbox.get_child_count():
		var effect_container: Control = vbox.get_child(drop_indicator_pos)
		y_pos = effect_container.position.y
	elif vbox.get_child_count() > 0:
		var last_child: Control = vbox.get_child(vbox.get_child_count() - 1)
		y_pos = last_child.position.y + last_child.size.y
	vbox.draw_line(Vector2(0, y_pos), Vector2(vbox.size.x, y_pos), Color(0.65, 0.1, 0.95, 1.0), 3.0)


func _on_clip_pressed(clip_data: ClipData) -> void:
	var clip: ClipData = ClipLogic.clips.get(clip_data.id) if clip_data else null
	if !clip:
		section_text.visible = false
		section_visuals.visible = false
		section_audio.visible =  false
		current_clip = null
		current_file = null
		_load_effects() # Clear the ui.
	elif current_clip and clip.id == current_clip.id:
		_update_ui_values()
	else:
		section_text.visible = clip.type == EditorCore.TYPE.TEXT
		section_visuals.visible = clip.type in EditorCore.VISUAL_TYPES
		section_audio.visible = clip.type in EditorCore.AUDIO_TYPES
		current_clip = clip
		current_file = FileLogic.files[clip.file]
		_load_effects()
		section_visuals.folded = false
		section_audio.folded = false


func _on_clip_deleted(clip_id: int) -> void:
	if current_clip and clip_id == current_clip.id:
		_on_clip_pressed(null)


func _on_frame_changed() -> void:
	if current_clip:
		_update_ui_values()


func _on_effect_added(clip: ClipData, index: int, is_visual: bool) -> void:
	if current_clip and clip and clip.id == current_clip.id:
		var effect: Effect
		if is_visual:
			effect = clip.effects.video[index]
		else:
			effect = clip.effects.audio[index]

		var added_effect: FoldableContainer = _create_effect_ui(effect, is_visual)
		if is_visual:
			section_visuals.get_child(0).add_child(added_effect)
			section_visuals.get_child(0).move_child(added_effect, index)
		else:
			section_audio.get_child(0).add_child(added_effect)
			section_audio.get_child(0).move_child(added_effect, index)


func _on_effect_removed(clip: ClipData, index: int, is_visual: bool) -> void:
	if current_clip and clip and clip.id == current_clip.id:
		var removed_effect: Control
		if is_visual:
			removed_effect = section_visuals.get_child(0).get_child(index)
			section_visuals.get_child(0).remove_child(removed_effect)
		else:
			removed_effect = section_audio.get_child(0).get_child(index)
			section_audio.get_child(0).remove_child(removed_effect)
		removed_effect.queue_free()


func _on_effect_moved(clip: ClipData, old_index: int, new_index: int, is_visual: bool) -> void:
	if current_clip and clip and clip.id == current_clip.id:
		if is_visual:
			var moved_effect: Control = section_visuals.get_child(0).get_child(old_index)
			section_visuals.get_child(0).move_child(moved_effect, new_index)
		else:
			var moved_effect: Control = section_audio.get_child(0).get_child(old_index)
			section_audio.get_child(0).move_child(moved_effect, new_index)


func _on_effects_updated(clip: ClipData) -> void:
	if current_clip and clip and clip.id == current_clip.id:
		_on_clip_pressed(clip)


func _load_effects() -> void:
	# Clean UI.
	if section_text.get_child_count() != 0:
		for child: Control in section_text.get_children():
			section_text.remove_child(child)
			child.queue_free()
	if section_visuals.get_child_count() != 0:
		var vbox: VBoxContainer = section_visuals.get_child(0)
		section_visuals.remove_child(vbox)
		vbox.queue_free()
	if section_audio.get_child_count() != 0:
		var vbox: VBoxContainer = section_audio.get_child(0)
		section_audio.remove_child(vbox)
		vbox.queue_free()

	var vbox_visuals: VBoxContainer = VBoxContainer.new()
	var vbox_audio: VBoxContainer = VBoxContainer.new()
	section_visuals.add_child(vbox_visuals)
	section_audio.add_child(vbox_audio)

	vbox_visuals.set_drag_forwarding(Callable(), _can_drop_effect.bind(true, vbox_visuals), _drop_effect.bind(true, vbox_visuals))
	vbox_audio.set_drag_forwarding(Callable(), _can_drop_effect.bind(false, vbox_audio), _drop_effect.bind(false, vbox_audio))

	vbox_visuals.draw.connect(_draw_drop_indicator.bind(vbox_visuals))
	vbox_audio.draw.connect(_draw_drop_indicator.bind(vbox_audio))

	if !current_clip or !ClipLogic.clips.has(current_clip.id):
		_update_ui_values()
		return

	# Creating/updating new UI.
	var clip_effects: ClipEffects = current_clip.effects
	if section_text.visible: # Set text params.
		_create_text_ui(current_file.temp_file.text_effect)
	for index: int in clip_effects.video.size(): # Add visual effects.
		vbox_visuals.add_child(_create_effect_ui(clip_effects.video[index], true))
	for index: int in clip_effects.audio.size(): # Add audio effects.
		vbox_audio.add_child(_create_effect_ui(clip_effects.audio[index], false))
	_update_ui_values()


func _create_effect_ui(effect: Effect, is_visual: bool) -> FoldableContainer:
	# NOTE: We can add the position of the effect inside of the effect array
	# inside of the metadata and let the buttons check if they are at the top
	# or bottom to disable the correct buttons.
	var relative_frame_nr: int = EditorCore.visual_frame_nr - current_clip.start
	var button_visible: TextureButton = TextureButton.new()
	var button_delete: TextureButton = TextureButton.new()
	var button_reset: TextureButton = TextureButton.new()

	if effect.is_enabled:
		button_visible.texture_normal = preload(Library.ICON_VISIBLE)
	else:
		button_visible.texture_normal = preload(Library.ICON_INVISIBLE)
	button_delete.texture_normal = preload(Library.ICON_DELETE)
	button_reset.texture_normal = preload(Library.ICON_REFRESH)
	button_reset.tooltip_text = tr("Reset to default")

	button_visible.pressed.connect(_on_switch_enabled.bind(effect, is_visual))
	button_delete.pressed.connect(_on_remove_effect.bind(effect, is_visual))
	button_reset.pressed.connect(_on_reset_effect.bind(effect, is_visual))

	for button: TextureButton in [button_reset, button_delete, button_visible]:
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
	button_drag.set_drag_forwarding(_get_drag_data_effect.bind(effect, is_visual), Callable(), Callable())

	var content_vbox: VBoxContainer = VBoxContainer.new()
	var container: FoldableContainer = FoldableContainer.new()
	container.title = effect.nickname
	container.tooltip_text = effect.tooltip
	#container.theme_type_variation = "box" # TODO: Create specific theme (light + dark).
	container.add_theme_font_size_override("font_size", 11)
	container.add_theme_color_override("font_color", "#b8b8b8")
	container.add_title_bar_control(button_reset)
	container.add_title_bar_control(button_delete)
	container.add_title_bar_control(button_visible)
	container.add_title_bar_control(button_drag)
	container.add_child(content_vbox)
	container.mouse_filter = Control.MOUSE_FILTER_PASS

	# Adding effect params.
	var keyframes_found: bool = false
	var custom_ui: EffectUI = effect.get_custom_ui()
	if custom_ui:
		content_vbox.add_child(custom_ui.get_ui(update_values))
		for param: EffectParam in effect.params:
			if param.keyframeable:
				keyframes_found = true
	else:
		for param: EffectParam in effect.params:
			var param_hbox: HBoxContainer = HBoxContainer.new()
			var param_id: String = param.id
			var param_title: Label = Label.new()
			var param_settings: Control = _create_param_control(param, effect, is_visual, false)

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
			param_reset_button.pressed.connect(
					_effect_param_update_call.bind(param.default_value, effect, is_visual, param_id))

			param_hbox.add_child(param_title)
			param_hbox.add_child(param_reset_button)
			param_hbox.add_child(param_settings)

			if param.keyframeable:
				var param_keyframe_button: TextureButton = TextureButton.new()
				param_keyframe_button.name = "KEYFRAME_" + param_id
				param_keyframe_button.ignore_texture_size = true
				param_keyframe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				param_keyframe_button.custom_minimum_size.x = 14
				param_keyframe_button.pressed.connect(_keyframe_button_pressed.bind(
						effect, is_visual, param_id))
				if effect.keyframes.has(param.id) and (effect.keyframes[param_id] as Dictionary).has(relative_frame_nr):
					param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
				else:
					param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)
				param_hbox.add_child(param_keyframe_button)
				keyframes_found = true
			content_vbox.add_child(param_hbox)

	if keyframes_found:
		var track_scroll: ScrollContainer = ScrollContainer.new()
		var track: KeyframeTrack = KeyframeTrack.new()

		track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_scroll.custom_minimum_size.y = 32

		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.size_flags_vertical = Control.SIZE_EXPAND_FILL
		track.setup(effect, current_clip.duration, relative_frame_nr)
		track.keyframe_moved_effect.connect(_on_keyframe_moved_effect_ui.bind(effect, is_visual))
		track.keyframe_deleted_effect.connect(_on_keyframe_deleted_effect_ui.bind(effect, is_visual))
		track.keyframe_dragged_to.connect(_on_keyframe_dragged_to_effect_ui)

		track_scroll.add_child(track)
		content_vbox.add_child(HSeparator.new())
		content_vbox.add_child(track_scroll)
	return container


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


func _create_param_control(param: EffectParam, effect: Effect, is_visual: bool, is_text: bool) -> Control:
	var value: Variant = param.default_value
	if value == null:
		printerr("EffectsPanel: Value is null! %s" % param)
		value = 0

	var update_call: Callable
	if is_text:
		update_call = _text_param_update_call.bind(param.id)
	else:
		update_call = _effect_param_update_call.bind(effect, is_visual, param.id)

	match typeof(value):
		TYPE_STRING:
			if param.id == "font":
				var opt: OptionButton = OptionButton.new()
				opt.add_item("Default")
				opt.set_item_metadata(0, "")
				var fonts: Array[String] = Settings.fonts.keys()
				fonts.sort()
				for i: int in fonts.size():
					opt.add_item(fonts[i])
					opt.set_item_metadata(i + 1, fonts[i])
				opt.item_selected.connect(func(id: int) -> void: update_call.call(opt.get_item_metadata(id)))
				opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return opt
			var line_edit: LineEdit = LineEdit.new()
			line_edit.text_changed.connect(update_call)
			line_edit.text_submitted.connect((func() -> void: line_edit.release_focus()).unbind(1))
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return line_edit
		TYPE_BOOL:
			var check_button: CheckButton = CheckButton.new()
			check_button.toggled.connect(update_call)
			check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return check_button
		TYPE_INT, TYPE_FLOAT:
			var horizontal: bool = param.id == "text_h_align"
			if horizontal or param.id == "text_v_align" or param.id == "mode":
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
				option_button.item_selected.connect(func(idx: int) -> void:
						update_call.call(option_button.get_item_id(idx)))
				option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				return option_button
			var spinbox: SpinBox = SpinBox.new()
			spinbox.min_value = param.min_value if param.min_value != null else MIN_VALUE
			spinbox.max_value = param.max_value if param.max_value != null else MAX_VALUE
			spinbox.step = param.step if param.step > 0.0 else (0.01 if typeof(value) == TYPE_FLOAT else 1.0)
			spinbox.allow_lesser = param.min_value == null
			spinbox.allow_greater = param.max_value == null
			spinbox.custom_arrow_step = spinbox.step
			spinbox.value_changed.connect(update_call)
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
			spinbox_x.value_changed.connect(func(new_value: float) -> void:
				if param.get("is_linkable") and param.get("is_linked"):
					spinbox_y.set_value_no_signal(new_value)
				var vector_val: Variant = Vector2(new_value, spinbox_y.value)
				if typeof(value) == TYPE_VECTOR2I:
					vector_val = Vector2i(vector_val as Vector2)
				update_call.call(vector_val))
			# Y
			spinbox_y.min_value = param.min_value.y if param.min_value != null else MIN_VALUE
			spinbox_y.max_value = param.max_value.y if param.max_value != null else MAX_VALUE
			spinbox_y.step = param.step if param.step > 0.0 else (0.01 if typeof(value) == TYPE_VECTOR2 else 1.0)
			spinbox_y.allow_lesser = param.min_value == null
			spinbox_y.allow_greater = param.max_value == null
			spinbox_y.custom_arrow_step = spinbox_y.step
			spinbox_y.value_changed.connect(func(new_value: float) -> void:
				if param.get("is_linkable") and param.get("is_linked"):
					spinbox_x.set_value_no_signal(new_value)
				var vector_val: Variant = Vector2(spinbox_x.value, new_value)
				if typeof(value) == TYPE_VECTOR2I:
					vector_val = Vector2i(vector_val as Vector2)
				update_call.call(vector_val))

			hbox.add_child(spinbox_x)

			if param.get("is_linkable"):
				var link_button: TextureButton = TextureButton.new()
				link_button.texture_normal = preload(Library.ICON_LINK)
				link_button.toggle_mode = true
				link_button.button_pressed = param.get("is_linked")
				link_button.modulate = Color(1, 1, 1, 1) if link_button.button_pressed else Color(1, 1, 1, 0.5)
				link_button.ignore_texture_size = true
				link_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				link_button.custom_minimum_size = Vector2(14, 14)
				link_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				link_button.tooltip_text = tr("Link X and Y")
				link_button.toggled.connect(func(toggled: bool) -> void:
					param.set("is_linked", toggled)
					link_button.modulate = Color(1, 1, 1, 1) if toggled else Color(1, 1, 1, 0.5)
					if toggled:
						spinbox_y.value = spinbox_x.value
				)
				hbox.add_child(link_button)

			hbox.add_child(spinbox_y)
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			return hbox
		TYPE_COLOR:
			var color_picker: ColorPickerButton = ColorPickerButton.new()
			color_picker.custom_minimum_size.x = 40
			color_picker.color_changed.connect(update_call)
			color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var frame_nr: int = EditorCore.visual_frame_nr - current_clip.start

	if section_text.visible and section_text.get_child_count() > 0:
		var text_effects: EffectVisual = current_file.temp_file.text_effect
		var text_container: FoldableContainer = section_text.get_child(0)
		var content_vbox: VBoxContainer = text_container.get_child(0)

		for i: int in text_effects.params.size():
			var param: EffectParam = text_effects.params[i]
			var param_hbox: HBoxContainer = content_vbox.get_child(i)
			var reset_button: TextureButton = param_hbox.get_child(1)
			var param_settings: Control = param_hbox.get_child(2)
			var keyframe_button: TextureButton = param_hbox.get_child(3)
			var value: Variant = text_effects.get_value(param, frame_nr)
			_set_param_settings_value(param_settings, value)

			reset_button.visible = not _is_same_value(value, param.default_value)

			var param_keyframes: Dictionary = text_effects.keyframes[param.id]
			if param_keyframes.has(frame_nr):
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
			else:
				keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)

			if param_keyframes.size() <= 1:
				keyframe_button.modulate = COLOR_KEYFRAMING_OFF
			else:
				keyframe_button.modulate = COLOR_KEYFRAMING_ON

		var track_hbox: HBoxContainer = content_vbox.get_child(-1)
		if track_hbox:
			var scroll: ScrollContainer = track_hbox.get_child(1)
			var track: KeyframeTrack = scroll.get_child(0)
			track.current_relative_frame = frame_nr
			track.effect.keyframes = text_effects.keyframes
			track.clip_duration = current_clip.duration
			track.queue_redraw()

	for i: int in current_clip.effects.video.size():
		_update_ui_values_effect(current_clip.effects.video, i, frame_nr)
	for i: int in current_clip.effects.audio.size():
		_update_ui_values_effect(current_clip.effects.audio, i, frame_nr)


func _update_ui_values_effect(effects: Array, index: int, frame_nr: int) -> void:
	var effect: Effect = effects[index]
	var section: FoldableContainer
	if effects == current_clip.effects.video:
		section = section_visuals
	else:
		section = section_audio
	var effect_container: FoldableContainer = section.get_child(0).get_child(index)
	var content_vbox: VBoxContainer = effect_container.get_child(0)
	if !effect.is_enabled:
		effect_container.folded = true

	var keyframes_found: bool = false
	if !effect.custom_ui_path.is_empty():
		update_values.emit(frame_nr)
		for param: EffectParam in effect.params:
			if param.keyframeable:
				keyframes_found = true
	else:
		for i: int in effect.params.size():
			var param: EffectParam = effect.params[i]
			var param_id: String = param.id
			var param_hbox: HBoxContainer = content_vbox.get_child(i)
			var reset_button: TextureButton = param_hbox.get_child(1)
			var param_settings: Control = param_hbox.get_child(2)
			var value: Variant = effect.get_value(param, frame_nr)
			_set_param_settings_value(param_settings, value)

			reset_button.visible = not _is_same_value(value, param.default_value)

			var effect_keyframes: Dictionary = effect.keyframes[param_id]
			if param.keyframeable:
				var keyframe_button: TextureButton = param_hbox.get_child(3)
				if effect_keyframes.has(frame_nr):
					keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
				else:
					keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)
				keyframes_found = true

	if keyframes_found:
		var scroll: ScrollContainer = content_vbox.get_child(-1)
		var track: KeyframeTrack = scroll.get_child(0)
		track.current_relative_frame = frame_nr
		track.clip_duration = current_clip.duration
		track.queue_redraw()


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
	elif param_settings is ColorPickerButton:
		var color_picker: ColorPickerButton = param_settings
		color_picker.color = value
	else:
		printerr("EffectsPanel: Invalid param settings control! %s - %s" % [param_settings, typeof(param_settings)])


func _on_switch_enabled(effect: Effect, is_visual: bool) -> void:
	var index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.switch_enabled(current_clip, index, is_visual)
	var section: FoldableContainer = section_visuals if is_visual else section_audio
	var effect_container: FoldableContainer = section.get_child(0).get_child(index)
	var visible_button: TextureButton = effect_container.get_child(1, true)
	var is_enabled: bool

	if is_visual:
		effect_container.folded = !current_clip.effects.video[index].is_enabled
	else:
		effect_container.folded = !current_clip.effects.audio[index].is_enabled

	if effect_container.folded:
		visible_button.texture_normal = load(Library.ICON_INVISIBLE)
	else:
		visible_button.texture_normal = load(Library.ICON_VISIBLE)


func _get_add_effects_button(is_visual: bool) -> TextureButton:
	var tex_button: TextureButton = TextureButton.new()
	tex_button.texture_normal = preload(Library.ICON_ADD)
	tex_button.tooltip_text = tr("Add effects")
	tex_button.ignore_texture_size = true
	tex_button.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
	tex_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	tex_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tex_button.pressed.connect(_open_add_effects_popup.bind(is_visual))
	return tex_button


func _open_add_effects_popup(is_visual: bool) -> void:
	if current_clip:
		var popup: Control = PopupManager.get_popup(PopupManager.ADD_EFFECTS)
		popup.call("load_effects", is_visual, current_clip)


func _effect_param_update_call(value: Variant, effect: Effect, is_visual: bool, param_id: String) -> void:
	var index: int = _get_effect_index(effect, is_visual)
	EffectsHandler.update_param(current_clip, index, is_visual, param_id, value, false)


func _keyframe_button_pressed(effect: Effect, is_visual: bool, param_id: String) -> void:
	var index: int = _get_effect_index(effect, is_visual)
	var relative_frame_nr: int = EditorCore.visual_frame_nr - current_clip.start

	var effect_keyframes: Dictionary = effect.keyframes[param_id]
	if effect_keyframes.has(relative_frame_nr):
		if relative_frame_nr != 0:
			EffectsHandler.remove_keyframe(current_clip, index, is_visual, param_id, relative_frame_nr)
	else:
		var value: Variant = _get_current_ui_value_for_param(effect, param_id, relative_frame_nr)
		EffectsHandler.update_param(current_clip, index, is_visual, param_id, value, true)
	_update_ui_values()


func _create_text_ui(text_effect: EffectVisual) -> void:
	var relative_frame_nr: int = EditorCore.visual_frame_nr - current_clip.start
	var container: FoldableContainer = FoldableContainer.new()
	container.title = "Text Properties"
	container.add_theme_font_size_override("font_size", 11)
	container.add_theme_color_override("font_color", "#b8b8b8")

	var button_reset: TextureButton = TextureButton.new()
	button_reset.texture_normal = preload(Library.ICON_REFRESH)
	button_reset.ignore_texture_size = true
	button_reset.custom_minimum_size = SIZE_EFFECT_HEADER_ICON
	button_reset.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button_reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_reset.tooltip_text = tr("Reset to default")
	button_reset.pressed.connect(_on_reset_text_effect)
	container.add_title_bar_control(button_reset)

	var content_vbox: VBoxContainer = VBoxContainer.new()
	container.add_child(content_vbox)
	for param: EffectParam in text_effect.params:
		var param_hbox: HBoxContainer = HBoxContainer.new()
		var param_id: String = param.id
		var param_title: Label = Label.new()
		var param_settings: Control = _create_param_control(param, null, false, true)
		var param_keyframe_button: TextureButton = TextureButton.new()

		param_title.text = param.nickname.replace("param_", "").capitalize()
		param_title.tooltip_text = param.tooltip
		param_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		param_title.clip_text = true

		param_settings.name = "PARAM_" + param_id
		param_keyframe_button.name = "KEYFRAME_" + param_id
		param_keyframe_button.ignore_texture_size = true
		param_keyframe_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_keyframe_button.custom_minimum_size.x = 14
		param_keyframe_button.pressed.connect(_text_keyframe_button_pressed.bind(param_id))

		var keyframes: Dictionary = text_effect.keyframes[param.id]
		if keyframes.has(relative_frame_nr):
			param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME)
		else:
			param_keyframe_button.texture_normal = load(Library.ICON_EFFECT_KEYFRAME_EMPTY)

		param_keyframe_button.visible = param.keyframeable

		var param_reset_button: TextureButton = TextureButton.new()
		param_reset_button.texture_normal = preload(Library.ICON_REFRESH)
		param_reset_button.tooltip_text = tr("Reset parameter")
		param_reset_button.ignore_texture_size = true
		param_reset_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		param_reset_button.custom_minimum_size = Vector2(14, 14)
		param_reset_button.pressed.connect(
				_text_param_update_call.bind(param.default_value, param_id))

		param_hbox.add_child(param_title)
		param_hbox.add_child(param_reset_button)
		param_hbox.add_child(param_settings)
		param_hbox.add_child(param_keyframe_button)
		content_vbox.add_child(param_hbox)

	var track: KeyframeTrack = KeyframeTrack.new()
	var track_scroll: ScrollContainer = ScrollContainer.new()
	var track_hbox: HBoxContainer = HBoxContainer.new()
	var track_label: Label = Label.new()

	track_label.text = "Keyframes"
	track_label.custom_minimum_size.x = 80
	track_label.modulate = Color(1, 1, 1, 0.5)

	track_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_scroll.custom_minimum_size.y = 32

	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track.setup(text_effect, current_clip.duration, relative_frame_nr)

	track.keyframe_moved_effect.connect(_on_text_keyframe_moved)
	track.keyframe_deleted_effect.connect(_on_text_keyframe_deleted)
	track.keyframe_dragged_to.connect(_on_keyframe_dragged_to_effect_ui)

	track_scroll.add_child(track)
	track_hbox.add_child(track_label)
	track_hbox.add_child(track_scroll)
	content_vbox.add_child(HSeparator.new())
	content_vbox.add_child(track_hbox)

	section_text.add_child(container)


func _on_text_keyframe_moved(old_frame: int, new_frame: int, preserve: bool, is_copy: bool) -> void:
	var text_effect: EffectVisual = current_file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes

	InputManager.undo_redo.create_action("Move/Copy Text Keyframes")
	for param: EffectParam in text_effect.params:
		var param_id: String = param.id
		var param_keyframes: Dictionary = keyframes[param_id]
		if not param_keyframes.has(old_frame):
			continue

		var value_move: Variant = param_keyframes[old_frame]
		var has_target: Variant = param_keyframes.has(new_frame)
		var value_target: Variant = param_keyframes[new_frame] if has_target else null
		var value_final: Variant = value_target if (has_target and preserve) else value_move
		if old_frame != 0 and not is_copy:
			InputManager.undo_redo.add_do_method(FileLogic.remove_text_keyframe.bind(current_file, param_id, old_frame))
			InputManager.undo_redo.add_undo_method(FileLogic._set_text_keyframe.bind(current_file, param_id, old_frame, value_move))

		if not (has_target and preserve):
			InputManager.undo_redo.add_do_method(FileLogic._set_text_keyframe.bind(current_file, param_id, new_frame, value_final))
			if has_target:
				InputManager.undo_redo.add_undo_method(FileLogic._set_text_keyframe.bind(current_file, param_id, new_frame, value_target))
			else:
				InputManager.undo_redo.add_undo_method(FileLogic.remove_text_keyframe.bind(current_file, param_id, new_frame))
	InputManager.undo_redo.commit_action()
	_update_ui_values()


func _on_text_keyframe_deleted(frame_nr: int) -> void:
	if frame_nr == 0:
		return
	var text_effect: EffectVisual = current_file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes

	InputManager.undo_redo.create_action("Delete Text Keyframes")
	for param: EffectParam in text_effect.params:
		var param_keyframes: Dictionary = keyframes[param.id]
		if param_keyframes.has(frame_nr):
			var old_value: Variant = param_keyframes[frame_nr]
			InputManager.undo_redo.add_do_method(FileLogic.remove_text_keyframe.bind(current_file, param.id, frame_nr))
			InputManager.undo_redo.add_undo_method(FileLogic._set_text_keyframe.bind(current_file, param.id, frame_nr, old_value))
	InputManager.undo_redo.commit_action()
	_update_ui_values()


func _text_param_update_call(value: Variant, param_id: String) -> void:
	var frame_nr: int = EditorCore.visual_frame_nr - current_clip.start
	var text_effect: EffectVisual = current_file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes

	var param_obj: EffectParam
	for param: EffectParam in text_effect.params:
		if param.id == param_id:
			param_obj = param
			break

	var is_keyframeable: bool = param_obj.keyframeable if param_obj else false
	var param_keyframes: Dictionary = keyframes[param_id]

	if param_keyframes.size() <= 1 or not is_keyframeable:
		var base_frame: int = param_keyframes.keys()[0] if param_keyframes.size() > 0 else 0
		var old_value: Variant = param_keyframes.get(base_frame, param_obj.default_value)
		FileLogic.update_text_param(current_file, param_id, base_frame, value, old_value, false)
	else:
		var is_new: bool = not param_keyframes.has(frame_nr)
		var old_value: Variant = param_keyframes[frame_nr] if not is_new else text_effect.get_value(param_obj, frame_nr)
		FileLogic.update_text_param(current_file, param_id, frame_nr, value, old_value, is_new)
	_update_ui_values()


func _text_keyframe_button_pressed(param_id: String) -> void:
	var frame_nr: int = EditorCore.visual_frame_nr - current_clip.start
	var text_effect: EffectVisual = current_file.temp_file.text_effect
	var keyframes: Dictionary = text_effect.keyframes
	var param_keyframes: Dictionary = keyframes[param_id]

	if !param_keyframes.has(frame_nr):
		var param_obj: EffectParam
		for param: EffectParam in text_effect.params:
			if param.id == param_id:
				param_obj = param
				break
		var value: Variant = text_effect.get_value(param_obj, frame_nr)
		FileLogic.update_text_param(current_file, param_id, frame_nr, value, null, true)
	elif frame_nr != 0:
		FileLogic.remove_text_keyframe(current_file, param_id, frame_nr)
	_update_ui_values()


func _on_reset_text_effect() -> void:
	var text_effect: EffectVisual = current_file.temp_file.text_effect
	var old_keyframes: Dictionary = text_effect.keyframes.duplicate(true)

	InputManager.undo_redo.create_action("Reset text effect")
	InputManager.undo_redo.add_do_method(_reset_text_effect.bind(current_file))
	InputManager.undo_redo.add_undo_method(_restore_text_effect_keyframes.bind(current_file, old_keyframes))
	InputManager.undo_redo.commit_action()


func _reset_text_effect(file: FileData) -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	text_effect.keyframes.clear()
	text_effect.set_default_keyframe()
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()


func _restore_text_effect_keyframes(file: FileData, old_keyframes: Dictionary) -> void:
	var text_effect: EffectVisual = file.temp_file.text_effect
	text_effect.keyframes = old_keyframes.duplicate(true)
	text_effect._cache_dirty = true
	Project.unsaved_changes = true
	ClipLogic.updated.emit()
	EffectsHandler.effect_values_updated.emit()



class DragData:
	var is_visual: bool
	var effect_index: int
	var effect: Effect
