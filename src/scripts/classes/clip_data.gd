class_name ClipData
extends RefCounted



var id: int
var file_id: int
var track_id: int

var start_frame: int # Timeline begin position of clip, use ClipHandler to get end_frame.
var duration: int
var end_frame: int:
	get: return start_frame + duration

var begin: int = 0 # Only for video and audio files

var effects_video: EffectsVideo
var effects_audio: EffectsAudio

