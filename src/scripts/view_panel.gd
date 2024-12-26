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


func _force_set_frame(a_frame_nr: int = Playhead.frame_nr) -> void:
	# Should only be called when having moved the playhead as it updates the
	# the currently "loaded" clips.

	for i: int in loaded_clips.size():
		# First check if loaded clip is correct
		if loaded_clips[i] != null and a_frame_nr > loaded_clips[i].start_frame:
			# Check if clip still exists
			if not loaded_clips[i].start_frame in Project.tracks[i]:
				AudioHandler.instance.reset_audio_stream(i)
				loaded_clips[i] = null
				continue
			elif a_frame_nr < loaded_clips[i].start_frame + loaded_clips[i].duration:
				if loaded_clips[i].type in AUDIO_TYPES:
					var l_audio_start_frame: int = a_frame_nr - loaded_clips[i].start_frame

					AudioHandler.instance.set_audio(i, loaded_clips[i].audio_data, l_audio_start_frame)
				continue

		loaded_clips[i] = null
		AudioHandler.instance.reset_audio_stream(i)

		# Take the current frame number and get the previous clip if clip start +
		# duration is higher or equal to the frame number.
		var l_start_frame: int = -1
		for l_frame_nr: int in Project.tracks[i].keys():
			if l_frame_nr > a_frame_nr:
				break
			elif l_frame_nr <= a_frame_nr:
				l_start_frame = l_frame_nr

		# No possibility for a clip found so we skip
		if l_start_frame == -1:
			continue

		# Possibility found so checking if a_frame_nr is in the length
		var l_clip_data: ClipData = Project.get_clip_data(i, l_start_frame)

		if l_clip_data.duration < a_frame_nr - l_start_frame:
			continue

		loaded_clips[i] = l_clip_data

		if l_clip_data.type in AUDIO_TYPES:
			var l_audio_start_frame: int = a_frame_nr - l_clip_data.start_frame

			AudioHandler.instance.set_audio(i, l_clip_data.audio_data, l_audio_start_frame)

	for i: int in loaded_clips.size():
		if loaded_clips[i] != null and loaded_clips[i].type == File.TYPE.AUDIO:
			continue

		update_texture_rect(i)

	if is_playing:
		AudioHandler.instance.play_all_audio()
	
	_set_frame(Playhead.instance.move(a_frame_nr))


func _set_frame(a_frame_nr: int = Playhead.instance.step()) -> void:
	# WARN: We need to take in mind frame skipping! We can skip over the moment
	# that a frame is supposed to appear or start playing!

	# Should only be used to display the next frame as it won't properly
	# Search for the next clips.

	for i: int in loaded_clips.size(): # i is the track id + loaded clips id

		# Check if clip is still valid, else set to null
		if loaded_clips[i] != null:
			if Project.tracks[i].has(a_frame_nr):
				# Check if clip is correct or not
				loaded_clips[i] = null
				update_texture_rect(i)
				AudioHandler.instance.reset_audio_stream(i)

			if loaded_clips[i].start_frame + loaded_clips[i].duration < a_frame_nr:
				# Check if clip is still within bounds
				loaded_clips[i] = null
				update_texture_rect(i)
				AudioHandler.instance.reset_audio_stream(i)


		# if loaded_clip for track is null, check if at current frame_nr in
		# track data if there is an entry or not.
		if loaded_clips[i] == null:
			if !Project.tracks[i].has(a_frame_nr):
				continue

			loaded_clips[i] = Project.get_clip_data(i, a_frame_nr)
			if loaded_clips[i].type in VISUAL_TYPES:
				update_texture_rect(i)
			if loaded_clips[i].type in AUDIO_TYPES:
				AudioHandler.instance.set_audio(
						i, loaded_clips[i].audio_data, 0, is_playing)

		# TODO: Apply/Update effect values to the shader


func update_texture_rect(a_id: int) -> void:
	var l_view: TextureRect = $VideoViews.get_child(a_id)
	var l_material: ShaderMaterial = l_view.material

	if loaded_clips[a_id] == null:
		l_view.texture = null
		l_material.shader = null
		return
	
	if loaded_clips[a_id].type == File.TYPE.IMAGE:
		var l_file_data: FileData = Project._files_data[loaded_clips[a_id].file_id]

		l_view.texture = l_file_data.image
		l_material.shader = preload("res://shaders/rgb.gdshader")
	else:
		# TODO: For video's create a new placeholder image for l_view with the 
		# resolution as the size of the image
		print("shader material for type is not implemented yet! ",
				loaded_clips[a_id].type)


func get_view_image() -> Image:
	var l_subviewport: SubViewport = $VideoViews

	return l_subviewport.get_texture().get_image()

