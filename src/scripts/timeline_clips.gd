extends Control

const TRACK_HEIGHT: int = 30
const LINE_HEIGHT: int = 4

@export var preview: PanelContainer



func _ready() -> void:
	preview.size.y = TRACK_HEIGHT

	if mouse_exited.connect(func() -> void:
			preview.visible = false):
		printerr("Couldn't connect mouse_exited!")


func _can_drop_data(a_pos: Vector2, a_data: Variant) -> bool:
	var l_draggable: Draggable = a_data
	var l_track: int = get_track_id(a_pos.y)

	var l_frame: int = maxi(get_frame_nr(a_pos.x) - l_draggable.mouse_offset, 0)
	var l_end: int = l_frame + l_draggable.duration

	var l_lowest: int = get_lowest_frame(l_track, l_frame)
	var l_highest: int = get_highest_frame(l_track, l_frame)

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
			l_clip_data.start_frame = l_start_frame
			l_clip_data.duration = Project.files[l_id].duration

			l_data[l_clip_id] = l_clip_data
			
			l_start_frame += l_clip_data.duration
		else:
			# Moving clips
			pass

	if l_draggable.files:
		Project.undo_redo.create_action("Adding new clips to timeline")
		Project.undo_redo.add_do_method(_add_new_clips.bind(
				l_data, get_track_id(preview.position.y)))
		Project.undo_redo.add_undo_method(_remove_new_clips.bind(
				l_data, get_track_id(preview.position.y)))
		Project.undo_redo.commit_action()
	else:
		Project.undo_redo.create_action("Moving clips on timeline")
		Project.undo_redo.commit_action()

	preview.visible = false


func _add_new_clips(a_new_clips: Dictionary, a_track_id: int) -> void:
	for id: int in a_new_clips:
		var l_clip_data: ClipData = a_new_clips[id]
		Project.clips[id] = l_clip_data
		Project.tracks[a_track_id][l_clip_data.start_frame] = id
		add_clip(l_clip_data, a_track_id)


func _remove_new_clips(a_new_clips: Dictionary, a_track_id: int) -> void:
	for id: int in a_new_clips:
		var l_clip_data: ClipData = a_new_clips[id]
		if !Project.clips.erase(id):
			printerr("Couldn't erase new clips from clips!")
		if !Project.tracks[a_track_id].erase(l_clip_data.start_frame):
			printerr("Couldn't erase new clips from tracks!")
		remove_clip(id)


func add_clip(a_clip_data: ClipData, a_track_id: int) -> void:
	var l_button: Button = Button.new()

	l_button.name = str(a_clip_data.id)
	l_button.mouse_filter = Control.MOUSE_FILTER_PASS
	l_button.text = Project.files[a_clip_data.file_id].nickname
	l_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	l_button.size.x = Project.timeline_scale * a_clip_data.duration
	l_button.position.x = Project.timeline_scale * a_clip_data.start_frame
	l_button.position.y = a_track_id * (LINE_HEIGHT + TRACK_HEIGHT)

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


func get_track_id(a_pos_y: float) -> int:
	return floori(a_pos_y / (TRACK_HEIGHT + LINE_HEIGHT))


func get_frame_nr(a_pos_x: float) -> int:
	return floori(a_pos_x / Project.timeline_scale)


func get_lowest_frame(a_track_id: int, a_frame_nr: int) -> int:
	var l_lowest: int = 0

	for i: int in Project.tracks[a_track_id].keys():
		if i < a_frame_nr:
			l_lowest = i
		elif i >= a_frame_nr:
			break

	if l_lowest == 0 and !Project.tracks[a_track_id].has(0):
		return -1

	var l_clip: ClipData = Project.clips[Project.tracks[a_track_id][l_lowest]]
	return l_clip.duration + l_lowest


func get_highest_frame(a_track_id: int, a_frame_nr: int) -> int:
	for i: int in Project.tracks[a_track_id].keys():
		if i > a_frame_nr:
			return i

	return -1

