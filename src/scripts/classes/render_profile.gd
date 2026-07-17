class_name RenderProfile
extends Resource


@export var profile_name: String = ""
@export var icon: Texture2D

@export_group("Video")
@export var video_codec: Encoder.VideoCodec = Encoder.VideoCodec.V_NONE
@export_range(15, 50) var crf: int = 18
@export_range(0, 600) var gop: int = 15
@export var h264_preset: Encoder.H264Presets = Encoder.H264Presets.H264_PRESET_MEDIUM

@export_group("Audio")
@export var audio_codec: Encoder.AudioCodec = Encoder.AudioCodec.A_NONE
@export var audio_channels: int = 2
