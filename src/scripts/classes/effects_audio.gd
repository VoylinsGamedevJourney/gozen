class_name EffectsAudio
extends Node


enum MONO { DISABLE = 0, LEFT_CHANNEL = 1, RIGHT_CHANNEL = 2 }


@export var mute: bool = false
@export var gain: float = 0
@export var mono: MONO = MONO.DISABLE

