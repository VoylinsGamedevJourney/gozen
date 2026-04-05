extends Control

const STYLE_BOX_PREVIEW: StyleBox = preload("uid://dx2v44643hfvy")



func _draw() -> void:
	var zoom: float = Timeline.zoom
	if Timeline.state in [Timeline.STATE.MOVING, Timeline.STATE.DROPPING] and Timeline.draggable != null:
		if !Timeline.drop_valid:
			return
		if Timeline.draggable.is_file:
			var preview_size: Vector2 = Vector2(Timeline.draggable.duration * zoom, Timeline.track_height)
			var preview_position: Vector2 = Vector2(
					(Timeline.draggable.frame_offset) * zoom,
					Timeline.draggable.track_offset * Timeline.track_total_size)
			draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
		else:
			for clip_id: int in Timeline.draggable.ids:
				var clip: ClipData = ClipLogic.clips[clip_id]
				var preview_position: Vector2 = Vector2(
						(clip.start + Timeline.draggable.frame_offset) * zoom,
						(clip.track + Timeline.draggable.track_offset) * Timeline.track_total_size)
				var preview_size: Vector2 = Vector2(clip.duration * zoom, Timeline.track_height)
				draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
	elif Timeline.state in [Timeline.STATE.RESIZING, Timeline.STATE.SPEEDING]:
		var clip: ClipData = Timeline.resize_target.clip
		var draw_start: float = clip.start
		var draw_length: int = clip.duration
		if !Timeline.resize_target.is_end:
			draw_start += Timeline.resize_target.delta
			draw_length -= Timeline.resize_target.delta
		else:
			draw_length += Timeline.resize_target.delta

		var preview_position: Vector2 = Vector2(draw_start * zoom, clip.track * Timeline.track_total_size)
		var preview_size: Vector2 = Vector2(draw_length * zoom, Timeline.track_height)
		var box_pos: Vector2 = Vector2(clip.start * zoom, Timeline.track_total_size * clip.track)
		var clip_rect: Rect2 = Rect2(box_pos, Vector2(clip.duration * zoom, Timeline.track_height))
		var color: Color = Color(1.0, 1.0, 1.0, 0.3) # Resizing color.
		if Timeline.state == Timeline.STATE.SPEEDING:
			color = Color(1.0, 0.5, 0.0, 0.3) # Have different color on speeding.

		# Drawing the original clip box and actual resized box.
		draw_rect(clip_rect, color)
		draw_style_box(STYLE_BOX_PREVIEW, Rect2(preview_position, preview_size))
