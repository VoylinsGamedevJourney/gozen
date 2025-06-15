class_name RenderProfile
extends Resource

@export var profile_name: String = ""
@export var icon: CompressedTexture2D

@export_group("Video")
@export var video_codec: Renderer.VIDEO_CODEC = Renderer.VIDEO_CODEC.V_NONE
@export_range(15, 50) var crf: int = 18
@export_range(0, 600) var gop: int = 15
@export var h264_preset: Renderer.H264_PRESETS = Renderer.H264_PRESETS.H264_PRESET_MEDIUM

@export_group("Audio")
@export var audio_codec: Renderer.AUDIO_CODEC = Renderer.AUDIO_CODEC.A_NONE

