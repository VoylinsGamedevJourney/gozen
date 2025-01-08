class_name TimelineClips extends Control

const TRACK_HEIGHT: int = 30
const LINE_HEIGHT: int = 4

static var instance: TimelineClips

@export var preview: PanelContainer



func _ready() -> void:
	instance = self
	preview.size.y = TRACK_HEIGHT

	if mouse_exited.connect(func() -> void: preview.visible = false):
		printerr("Couldn't connect mouse_exited!")

	if Project._on_timeline_scale_changed.connect(_on_timeline_scale_changed):
		printerr("Couldn't connect timeline_scale_changed!")


func _can_drop_data(a_pos: Vector2, a_data: Variant) -> bool:
	var l_draggable: Draggable = a_data
	var l_track: int = get_track_id(a_pos.y)

	var l_frame: int = maxi(get_frame_nr(a_pos.x) - l_draggable.mouse_offset, 0)
	var l_end: int = l_frame + a_data.duration

	var l_lowest: int = get_lowest_frame(l_track, l_frame, l_draggable.ignore)
	var l_highest: int = get_highest_frame(l_track, l_frame, l_draggable.ignore)

	# Check if highest
	if l_highest == -1 and l_lowest < l_frame:
		return show_preview(l_track, l_frame, l_draggable.duration)

	# Fits in between the 2 clips
	if l_frame > l_lowest and l_end < l_highest:
		return show_preview(l_track, l_frame, l_draggable.duration)

	# Overlaps with lowest, add offset and check for interference
	if l_frame <= l_lowest:
		var l_difference: int = l_lowest - l_frame

		if l_frame + l_difference < l_highest or l_highest == -1:
			return show_preview(l_track, l_frame + l_difference, l_draggable.duration)
	elif l_end >= l_highest:
		var l_difference: int = l_end - l_highest

		if l_frame - l_difference > l_lowest:
			return show_preview(l_track, l_frame - l_difference, l_draggable.duration)

	return hide_preview()


func _drop_data(_pos: Vector2, a_data: Variant) -> void:
	var l_start_frame: int = get_frame_nr(preview.position.x)
	var l_draggable: Draggable = a_data
	var l_data: Dictionary = {}

	for l_id: int in l_draggable.ids:
		if l_draggable.files:
			# Creating new clips
			var l_clip_data: ClipData = ClipData.new()
			var l_clip_id: int = Utils.get_unique_id(Project.clips.keys())

			l_clip_data.id = l_clip_id
			l_clip_data.file_id = l_id
			l_clip_data.type = Project.files[l_id].type
			l_clip_data.start_frame = l_start_frame
			l_clip_data.duration = Project.files[l_id].duration

			l_data[l_clip_id] = l_clip_data
			
			l_start_frame += l_clip_data.duration

	if l_draggable.files:
		Project.undo_redo.create_action("Adding new clips to timeline")
		Project.undo_redo.add_do_method(_add_new_clips.bind(
				l_data, get_track_id(preview.position.y)))
		Project.undo_redo.add_do_method(View._update_frame)
		Project.undo_redo.add_undo_method(_remove_new_clips.bind(
				l_data, get_track_id(preview.position.y)))
		Project.undo_redo.add_undo_method(View._update_frame)
		Project.undo_redo.commit_action()
	else:
		# TODO: Make this work when moving multiple nodes
		Project.undo_redo.create_action("Moving clips on timeline")
		for i: int in l_draggable.clip_buttons.size():
			Project.undo_redo.add_do_method(_move_clip.bind(
					l_draggable.clip_buttons[i], preview.position))
			Project.undo_redo.add_undo_method(_move_clip.bind(
					l_draggable.clip_buttons[i], l_draggable.clip_buttons[i].position))

		Project.undo_redo.add_do_method(View._update_frame)
		Project.undo_redo.add_undo_method(View._update_frame)
		Project.undo_redo.add_do_method(update_timeline_end)
		Project.undo_redo.add_undo_method(update_timeline_end)
		Project.undo_redo.commit_action()

	preview.visible = false


func _move_clip(a_node: Button, a_new_pos: Vector2) -> void:
	var l_old_track_id: int = get_track_id(a_node.position.y)
	var l_new_track_id: int = get_track_id(a_new_pos.y)
	var l_old_frame_nr: int = get_frame_nr(a_node.position.x)
	var l_new_frame_nr: int = get_frame_nr(a_new_pos.x)

	if !Project.tracks[l_old_track_id].erase(l_old_frame_nr):
		printerr("Could not erase from tracks!")
	Project.tracks[l_new_track_id][l_new_frame_nr] = a_node.name.to_int()
	Project.get_clip_data(l_new_track_id, l_new_frame_nr).start_frame = l_new_frame_nr

	a_node.position = a_new_pos
	

func _add_new_clips(a_new_clips: Dictionary, a_track_id: int) -> void:
	for id: int in a_new_clips:
		var l_clip_data: ClipData = a_new_clips[id]
		Project.clips[id] = l_clip_data
		Project.tracks[a_track_id][l_clip_data.start_frame] = id
		add_clip(l_clip_data, a_track_id)
	update_timeline_end()

	for l_clip_data: ClipData in a_new_clips.values():
		l_clip_data.update_audio_data()


func _remove_new_clips(a_new_clips: Dictionary, a_track_id: int) -> void:
	for id: int in a_new_clips:
		var l_clip_data: ClipData = a_new_clips[id]
		if !Project.clips.erase(id):
			printerr("Couldn't erase new clips from clips!")
		if !Project.tracks[a_track_id].erase(l_clip_data.start_frame):
			printerr("Couldn't erase new clips from tracks!")
		remove_clip(id)
	update_timeline_end()


func add_clip(a_clip_data: ClipData, a_track_id: int) -> void:
	var l_button: Button = Button.new()

	l_button.clip_text = true
	l_button.name = str(a_clip_data.id)
	l_button.text = " " + Project.files[a_clip_data.file_id].nickname
	l_button.size.x = Project.timeline_scale * a_clip_data.duration
	l_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	l_button.position.x = Project.timeline_scale * a_clip_data.start_frame
	l_button.position.y = a_track_id * (LINE_HEIGHT + TRACK_HEIGHT)
	l_button.mouse_filter = Control.MOUSE_FILTER_PASS

	var l_style_box: StyleBoxFlat = StyleBoxFlat.new()

	if a_clip_data.type == File.TYPE.IMAGE:
		l_style_box = preload("res://styles/style_box_image.tres")
	elif a_clip_data.type == File.TYPE.AUDIO:
		l_style_box = preload("res://styles/style_box_audio.tres")
	elif a_clip_data.type == File.TYPE.VIDEO:
		l_style_box = preload("res://styles/style_box_video.tres")
	
	l_button.add_theme_stylebox_override("normal", l_style_box)
	l_button.add_theme_stylebox_override("focus", l_style_box)
	l_button.add_theme_stylebox_override("hover", l_style_box)
	l_button.add_theme_stylebox_override("pressed", l_style_box)

	l_button.set_script(preload("res://scripts/clip_button.gd"))

	add_child(l_button)


func remove_clip(a_id: int) -> void:
	remove_child(get_node(str(a_id)))


func show_preview(a_track_id: int, a_frame_nr: int, a_duration: int) -> bool:
	preview.position.y = a_track_id * (TRACK_HEIGHT + LINE_HEIGHT)
	preview.position.x = Project.timeline_scale * a_frame_nr
	preview.size.x = Project.timeline_scale * a_duration
	preview.visible = true

	return true


func hide_preview() -> bool:
	preview.visible = false
	return false


static func get_track_id(a_pos_y: float) -> int:
	return floori(a_pos_y / (TRACK_HEIGHT + LINE_HEIGHT))


static func get_frame_nr(a_pos_x: float) -> int:
	return floori(a_pos_x / Project.timeline_scale)


func get_lowest_frame(a_track_id: int, a_frame_nr: int, a_ignore: Array[Vector2i]) -> int:
	var l_lowest: int = -1

	if a_track_id > Project.tracks.size():
		return -1

	for i: int in Project.tracks[a_track_id].keys():
		if i < a_frame_nr:
			if a_ignore.size() >= 1:
				if i == a_ignore[0].y and a_track_id == a_ignore[0].x:
					continue
			l_lowest = i
		elif i >= a_frame_nr:
			break

	if l_lowest == -1:
		return -1

	var l_clip: ClipData = Project.clips[Project.tracks[a_track_id][l_lowest]]
	return l_clip.duration + l_lowest


func get_highest_frame(a_track_id: int, a_frame_nr: int, a_ignore: Array[Vector2i]) -> int:
	for i: int in Project.tracks[a_track_id].keys():
		# TODO: Change the a_ignore when moving multiple clips
		if i > a_frame_nr:
			if a_ignore.size() >= 1:
				if i == a_ignore[0].y and a_track_id == a_ignore[0].x:
					continue
			return i

	return -1


func update_timeline_end() -> void:
	var l_new_end: int = 0

	for l_track: Dictionary in Project.tracks:
		if l_track.size() == 0:
			continue

		var l_clip: ClipData = Project.clips[l_track[l_track.keys().max()]]
		var l_value: int = l_clip.duration + l_clip.start_frame

		if l_new_end < l_value:
			l_new_end = l_value
	
	(get_parent() as Control).custom_minimum_size.x = (l_new_end + 1080) * Project.timeline_scale
	Project.timeline_end = l_new_end


func delete_clip(a_track_id: int, a_frame_nr: int) -> void:
	var l_id: int = Project.tracks[a_track_id][a_frame_nr]

	if !Project.clips.erase(l_id):
		printerr("Couldn't erase new clips from clips!")
	if !Project.tracks[a_track_id].erase(a_frame_nr):
		printerr("Couldn't erase new clips from tracks!")

	remove_clip(l_id)
	update_timeline_end()


func undelete_clip(a_clip_data: ClipData, a_track_id: int) -> void:
	_add_new_clips({a_clip_data.id: a_clip_data}, a_track_id)
	a_clip_data.update_audio_data()
	update_timeline_end()


func _on_timeline_scale_changed() -> void:
	# Get all clips, update their size and position
	for l_clip_button: Button in get_children():
		var l_data: ClipData = Project.clips[l_clip_button.name.to_int()]

		l_clip_button.position.x = l_data.start_frame * Project.timeline_scale
		l_clip_button.size.x = l_data.duration * Project.timeline_scale

	# TODO: make it so the timline moves left/right according to the cursor position
		
	update_timeline_end()

