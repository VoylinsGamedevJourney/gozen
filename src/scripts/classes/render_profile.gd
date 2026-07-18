class_name RenderProfile
extends Resource

enum AudioChannels { MONO = 1, STEREO = 2}


@export var profile_name: String = ""
@export var icon: Texture2D

@export_category("Video")
@export var video_codec: Encoder.VideoCodec = Encoder.VideoCodec.V_NONE
@export_range(15, 50) var crf: int = 18
@export_range(0, 600) var gop: int = 15
@export var h264_preset: Encoder.H264Presets = Encoder.H264Presets.H264_PRESET_MEDIUM

@export_category("Audio")
@export var audio_codec: Encoder.AudioCodec = Encoder.AudioCodec.A_NONE
@export var audio_channels: AudioChannels = AudioChannels.STEREO

@export_category("Advanced Video")
@export var b_frames: int = 0 ## Higher value equals better compression, but longer render times.
