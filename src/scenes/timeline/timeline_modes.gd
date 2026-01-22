extends Control


enum MODE { SELECT, CUT }


const COLOR_CUT: Color = Color(1,0,0,0.6)
const COLOR_CUT_FADE: Color = Color(1,0,0,0.3)


@export var mode_panel: PanelContainer
@export var button_select: TextureButton
@export var button_cut: TextureButton


var mode: MODE = MODE.SELECT



func _ready() -> void:
	InputManager.switch_timeline_mode_select.connect(_on_select_mode_button_pressed)
	InputManager.switch_timeline_mode_cut.connect(_on_cut_mode_button_pressed)

	Settings.on_show_time_mode_bar_changed.connect(_show_hide_mode_bar)

	_show_hide_mode_bar()


func _show_hide_mode_bar(value: bool = Settings.get_show_time_mode_bar()) -> void:
	mode_panel.visible = value


func _draw() -> void:
	var pos_x: float = get_local_mouse_position().x
	
	if mode == MODE.CUT:
		var fade_pos: float = pos_x + 1
		draw_line(Vector2(pos_x, 0), Vector2(pos_x, size.y), COLOR_CUT)
		draw_line(Vector2(fade_pos, 0), Vector2(fade_pos, size.y), COLOR_CUT_FADE)


func _on_select_mode_button_pressed() -> void:
	button_select.set_pressed_no_signal(true)
	mode = MODE.SELECT
	queue_redraw()


func _on_cut_mode_button_pressed() -> void:
	button_cut.set_pressed_no_signal(true)
	mode = MODE.CUT
	queue_redraw()


func _on_mode_draw_gui_input(_event: InputEvent) -> void:
	queue_redraw()
