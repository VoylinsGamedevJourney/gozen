class_name ViewPanel extends PanelContainer
# Current frame_nr should be gotten from the Playhead class

const VISUAL_TYPES: PackedInt64Array = [ File.TYPE.IMAGE, File.TYPE.VIDEO ]
const AUDIO_TYPES: PackedInt64Array = [ File.TYPE.AUDIO, File.TYPE.VIDEO ]


static var instance: ViewPanel

var is_playing: bool = false
var loaded_clips: Array[ClipData] = []

var time_elapsed: float = 0.0
var frame_time: float = 0.0
var skips: int = 0



func _ready() -> void:
	instance = self
	frame_time = 1.0 / Project.framerate

	for i: int in 6: # 6 static tracks
		loaded_clips.append(null)


func _process(a_delta: float) -> void:
	if is_playing:
		# Check if enough time has passed for next frame or not
		# move playhead as well
		skips = 0
		time_elapsed += a_delta

		if time_elapsed < frame_time:
			return

		while time_elapsed >= frame_time:
			time_elapsed -= frame_time
			skips += 1

		if skips <= 1:
			_set_frame(Playhead.instance.skip(skips))
			# TODO: We have to adjust the audio playback as well when skipping happens
		else:
			_set_frame()


func _on_play_button_pressed() -> void:
	if Playhead.frame_nr == Project.timeline_end:
		AudioHandler.instance.stop_all_audio()
		return _on_end_reached()

	is_playing = !is_playing

	if is_playing:
		AudioHandler.instance.play_all_audio()
	else:
		AudioHandler.instance.stop_all_audio()


func _on_end_reached() -> void:
	is_playing = false


func _update_frame() -> void:
	_set_frame(Playhead.frame_nr, true)


func _set_frame(a_frame_nr: int = Playhead.instance.step(), a_force_playhead: bool = false) -> void:
	# WARN: We need to take in mind frame skipping! We can skip over the moment
	# that a frame is supposed to appear or start playing!
	for i: int in loaded_clips.size():
		# Check if current clip is correct
		if _check_clip(i, a_frame_nr, a_force_playhead):
			update_view(i)
			continue

		# Getting the next frame if possible
		var l_clip_id: int = _get_next_clip(a_frame_nr, i)

		if l_clip_id == -1:
			loaded_clips[i] = null
			AudioHandler.instance.stop_audio(i)
		else:
			loaded_clips[i] = Project.clips[l_clip_id]
			AudioHandler.instance.set_audio(
					i, loaded_clips[i].get_audio(),
					a_frame_nr - loaded_clips[i].start_frame)
		set_view(i)
		update_view(i)
	
	if a_force_playhead:
		Playhead.instance.move(a_frame_nr)


func set_view(a_id: int) -> void:
	var l_view: TextureRect = $VideoViews.get_child(a_id)
	var l_material: ShaderMaterial = l_view.material

	# Resetting the texture and shader when no clip is set
	if loaded_clips[a_id] == null:
		l_view.texture = null
		l_material.shader = null

	# When clip is an image, set the shader which gives access to the effects
	elif loaded_clips[a_id].type == File.TYPE.IMAGE:
		var l_file_data: FileData = Project._files_data[loaded_clips[a_id].file_id]

		l_view.texture = l_file_data.image
		l_material.shader = preload("res://shaders/rgb.gdshader")

	elif loaded_clips[a_id].type != File.TYPE.VIDEO:
		var l_tex: PlaceholderTexture2D = PlaceholderTexture2D.new()

		l_tex.size = Vector2i(10,10)
		l_view.texture = l_tex
		l_material.shader = preload("res://shaders/rgb.gdshader")

	# TODO: For video's create a new placeholder image for l_view with the 
	# resolution as the size of the image
	#if video.get_pixel_format().begins_with("yuv"):


func update_view(a_id: int) -> void:
	if loaded_clips[a_id] == null or loaded_clips[a_id].type not in VISUAL_TYPES:
		return

	# Setting all effects and settings to clips

	# For images, only set effects
	# For video's set next frame + apply effects
	pass


## Update display/audio and continue if within clip bounds
func _check_clip(a_id: int, a_frame_nr: int, a_set_audio: bool) -> bool:
	if loaded_clips[a_id] == null:
		return false

	if loaded_clips[a_id].start_frame > a_frame_nr:
		return false

	if a_frame_nr > loaded_clips[a_id].start_frame + loaded_clips[a_id].duration:
		return false

	# Setting the audio to the correct position
	if a_set_audio:
		AudioHandler.instance.set_audio(
			a_id, loaded_clips[a_id].get_audio(), a_frame_nr - loaded_clips[a_id].start_frame)
	update_view(a_id)

	return true


func _get_next_clip(a_frame_nr: int, a_track: int) -> int:
	var l_clip_id: int = -1

	# Looking for the correct clip
	for l_frame: int in Project.tracks[a_track].keys():
		if l_frame <= a_frame_nr:
			l_clip_id = Project.tracks[a_track][l_frame]
		else:
			break

	if _check_clip_end(a_frame_nr, l_clip_id):
		return l_clip_id

	return -1

 
func _check_clip_end(a_frame_nr: int, a_clip_id: int) -> bool:
	if a_clip_id == -1:
		return false
	
	var l_clip: ClipData = Project.clips[a_clip_id]

	return a_frame_nr < l_clip.start_frame + l_clip.duration


func get_view_image() -> Image:
	var l_subviewport: SubViewport = $VideoViews

	return l_subviewport.get_texture().get_image()

