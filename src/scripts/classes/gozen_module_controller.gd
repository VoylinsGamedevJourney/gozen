@abstract
class_name GoZenModuleController
extends Node


## Called by EditorCore when the scene is first instantiated or when
## project settings change.
@abstract func setup(framerate: float, resolution: Vector2i) -> void


## Called by EditorCore every time the playhead moves to a position
## on the clip with clip_frame_nr being the current frame relative to the start
## of the clip, duration being the total amount of duration of the clip, and
## params being the current values of the EffectParams for that specific frame.
@abstract func update_frame(clip_frame_nr: int, duration: int, params: Dictionary) -> void


## Called when the clip is removed from the timeline.
@abstract func cleanup() -> void


