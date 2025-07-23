class_name EffectsAudio
extends Node


enum MONO { DISABLE = 0, LEFT_CHANNEL = 1, RIGHT_CHANNEL = 2 }


var clip_id: int = -1

@export var mute: bool = false
@export var gain: Dictionary[int, float] = { 0: 0 }
@export var mono: MONO = MONO.DISABLE

@export var fade_in: int # In frames
@export var fade_out: int # In frames

