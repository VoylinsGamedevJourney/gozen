extends Node


signal state_changed(new_state: STATE)
signal zoom_changed(new_zoom: float)
signal scroll_changed(new_zoom: float)


enum STATE {
	SELECT, SPLIT, SCRUBBING, MOVING, DROPPING,
	RESIZING, SPEEDING, FADING, BOX_SELECTING }


const TRACK_LINE_WIDTH: int = 1


var state: STATE = STATE.SELECT: set = set_state
var zoom: float = 1.0: set = set_zoom
var scroll_x: float: set = set_scroll_x
var scroll_y: float: set = set_scroll_y

var track_height: float = 30.0
var track_total_size: float = track_height + TRACK_LINE_WIDTH

var draggable: Draggable = null
var drop_valid: bool = false

var hovered_clip: ClipData = null
var resize_target: ResizeTarget = null
var fade_target: FadeTarget = null

var box_select_start: Vector2
var box_select_end: Vector2

var snap_enabled: bool = true



func _ready() -> void:
	@warning_ignore_start("return_value_discarded")
	InputManager.switch_timeline_mode_select.connect(set_state.bind(STATE.SELECT))
	InputManager.switch_timeline_mode_split.connect(set_state.bind(STATE.SPLIT))
	@warning_ignore_restore("return_value_discarded")


# --- Setters ---

func set_state(val: STATE) -> void:
	if state != val:
		state = val
		state_changed.emit(state)


func set_zoom(value: float) -> void:
	if zoom != value:
		zoom = value
		zoom_changed.emit(zoom)


func set_scroll_x(value: float) -> void:
	if scroll_x != value:
		scroll_x = value
		scroll_changed.emit(Vector2(scroll_x, scroll_y))


func set_scroll_y(value: float) -> void:
	if scroll_y != value:
		scroll_y = value
		scroll_changed.emit(Vector2(scroll_x, scroll_y))


# --- Logic ---

func find_snap_offset(edges: Array[int], threshold: int, ignores: Array[int] = []) -> int:
	if not snap_enabled:
		return 0

	var snap_points: Array[int] = [EditorCore.frame_nr]
	for marker: MarkerData in MarkerLogic.markers:
		snap_points.append(marker.frame_nr)
	for track_data: TrackLogic.TrackClips in TrackLogic.track_clips:
		for clip: ClipData in track_data.clips:
			if clip.id not in ignores:
				snap_points.append(clip.start)
				snap_points.append(clip.end)

	var best_delta: int = 0
	var min_distance: int = threshold + 1
	for edge: int in edges:
		for snap_point: int in snap_points:
			var distance: int = abs(snap_point - edge)
			if distance < min_distance:
				min_distance = distance
				best_delta = snap_point - edge

	if min_distance <= threshold:
		return best_delta
	return 0


func can_drop_new_clips(track: int, frame: int, safe_zone: int) -> bool:
	draggable.track_offset = track
	if TrackLogic.tracks[draggable.track_offset].is_locked:
		return false
	var target_frame: int = frame - draggable.mouse_offset
	var target_end: int = target_frame + draggable.duration

	var snap_delta: int = find_snap_offset([target_frame, target_end], maxi(1, int(10.0 / zoom)))
	target_frame += snap_delta
	target_end += snap_delta
	var clip_at_pos: ClipData = TrackLogic.get_clip_at_overlap(draggable.track_offset, target_frame)
	var clip_at_end: ClipData = TrackLogic.get_clip_at_overlap(draggable.track_offset, target_end)
	var free_region: Vector2i

	if target_frame < 0:
		target_end += abs(target_frame)
		target_frame = 0

	if !clip_at_pos:
		free_region = TrackLogic.get_free_region(draggable.track_offset, target_frame)

		if free_region.y > target_end:
			draggable.frame_offset = target_frame
			return true # Space fully available from target_frame to target_end.
		elif free_region.y - free_region.x < draggable.duration:
			return false # No space.

		# Check what space is needed on right side and if within safe zone
		# Possible with safe zone so checking if enough space on left side.
		var distance_necessary: int = target_end - free_region.y

		if distance_necessary > safe_zone or target_frame - free_region.x < distance_necessary:
			return false

		draggable.frame_offset = target_frame - distance_necessary
		return true
	elif !clip_at_end:
		free_region = TrackLogic.get_free_region(draggable.track_offset, target_end)
		if free_region.y - free_region.x < draggable.duration:
			return false # No space.

		# Check what space is needed on left side and if within safe zone.
		# Possible with safe zone so checking if enough space on left side.
		var distance_necessary: int = target_frame - free_region.x
		if distance_necessary > safe_zone or target_end - free_region.y > distance_necessary:
			return false

		draggable.frame_offset = target_frame - distance_necessary
		return true
	return false # Not possible to find space.


func can_move_clips(track: int, frame: int, safe_zone: int) -> bool:
	var anchor_clip: ClipData = ClipLogic.clips[draggable.ids[0]]
	var target_start: int = frame - draggable.mouse_offset
	var track_difference: int = track - anchor_clip.track
	var frame_difference: int = target_start - anchor_clip.start
	var ignore_ids: Array[int] = []
	ignore_ids.assign(draggable.ids)

	var edges: Array[int] = []
	for clip_id: int in draggable.ids:
		var c: ClipData = ClipLogic.clips[clip_id]
		edges.append(c.start + frame_difference)
		edges.append(c.end + frame_difference)
	var snap_delta: int = find_snap_offset(edges, maxi(1, int(10.0 / zoom)), ignore_ids)
	frame_difference += snap_delta

	var candidates: Array[int] = [frame_difference]
	for clip_id: int in draggable.ids:
		var clip: ClipData = ClipLogic.clips[clip_id]
		var new_track: int = clip.track + track_difference
		if new_track < 0 or new_track >= TrackLogic.tracks.size() or TrackLogic.tracks[new_track].is_locked:
			return false

		candidates.append(0 - clip.start)
		for other: ClipData in TrackLogic.track_clips[new_track].clips:
			if other.id in ignore_ids:
				continue
			candidates.append(other.start - clip.end)
			candidates.append(other.end - clip.start)

	var best_frame_difference: int = frame_difference
	var best_distance: int = Utils.INT_32_MAX
	var valid_found: bool = false
	for difference: int in candidates:
		var distance: int = abs(difference - frame_difference)
		if distance <= safe_zone and distance < best_distance:
			var is_valid: bool = true
			for clip_id: int in draggable.ids:
				var clip: ClipData = ClipLogic.clips[clip_id]
				var new_track: int = clip.track + track_difference
				var new_start: int = clip.start + difference
				var new_end: int = clip.end + difference
				if new_start < 0:
					is_valid = false
					break
				for other: ClipData in TrackLogic.track_clips[new_track].clips:
					if other.id in ignore_ids:
						continue
					if new_start < other.end and new_end > other.start:
						is_valid = false
						break
				if not is_valid:
					break
			if is_valid:
				best_distance = distance
				best_frame_difference = difference
				valid_found = true
	if not valid_found:
		return false
	draggable.track_offset = track_difference
	draggable.frame_offset = best_frame_difference
	return true



class ResizeTarget:
	var clip: ClipData
	var is_end: bool
	var original_start: int = 0
	var original_duration: int = 0
	var delta: int = 0

	func _init(clip_data: ClipData, _is_end: bool, start: int, duration: int) -> void:
		clip = clip_data
		is_end = _is_end
		original_start = start
		original_duration = duration


class FadeTarget:
	var clip: ClipData
	var is_end: bool
	var is_visual: bool

	func _init(clip_data: ClipData, _is_end: bool, _is_visual: bool) -> void:
		clip = clip_data
		is_end = _is_end
		is_visual = _is_visual
