extends Control


func _draw() -> void:
	if Timeline.current_state == Timeline.State.SPLIT:
		_draw_split()


func _draw_split() -> void:
	var timeline_panel: Control = get_parent()
	var mouse_pos: Vector2 = get_local_mouse_position()

	var fade_pos: float = mouse_pos.x + 1
	var split_color: Color = get_theme_color("split", "Timeline")

	draw_line(Vector2(mouse_pos.x, 0), Vector2(mouse_pos.x, size.y), split_color)
	draw_line(Vector2(fade_pos, 0), Vector2(fade_pos, size.y), get_theme_color("split_fade", "Timeline"))

	var target: ClipData = timeline_panel.call("_get_clip_on_mouse", mouse_pos)
	if !target:
		return

	var frame_pos: int = timeline_panel.call("get_frame_from_mouse", mouse_pos)
	var clips_to_split: Array[ClipData] = []

	if target in ClipLogic.active_clips:
		clips_to_split = ClipLogic.active_clips
	else:
		clips_to_split = ClipLogic.get_clips_to_select(target)

	for clip: ClipData in clips_to_split:
		if TrackLogic.tracks[clip.track].is_locked:
			continue

		if clip.start < frame_pos and clip.end > frame_pos:
			var start: float = clip.track * Timeline.track_total_size
			var end: float = start + Timeline.track_height
			var highlight_color: Color = Color(split_color.r, split_color.g, split_color.b, 1.0)
			draw_line(Vector2(mouse_pos.x, start), Vector2(mouse_pos.x, end), highlight_color, 3.0)
