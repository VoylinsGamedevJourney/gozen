extends Node

var commands: Array[String] = [] ## Localized strings.
var base_commands: Array[String] = [] ## Non-localized strings.

var calls: Array[Callable] = []
var actions: Array[String] = []



func _ready() -> void:
	if OS.has_feature("demo"): return # No commands for demo :p

	register(Command.new("Open editor settings", Settings.open_settings_menu, "open_settings"))
	register(Command.new("Open project settings", Project.open_settings_menu, "open_project_settings"))
	register(Command.new("Open module manager", PopupManager.open.bind(PopupManager.MODULE_MANAGER), ""))

	register(Command.new("Switch to Edit workspace", InputManager.show_editor_workspace, ""))
	register(Command.new("Switch to Render workspace", InputManager.show_render_workspace, ""))
	register(Command.new("Switch workspace", InputManager.switch_workspace, "switch_workspace"))
	register(Command.new("Toggle tab titles", WorkspaceManager.toggle_tab_titles, ""))

	register(Command.new("Save project", Project.save, "save_project"))
	register(Command.new("Save project as", Project.save_as, "save_project_as"))
	register(Command.new("Open project", Project.open_project, "open_project"))
	register(Command.new("Archive project", Project.archive_as, ""))

	register(Command.new("Add text file", FileLogic.add.bind(["temp://text"]), ""))
	register(Command.new("Add color file", PopupManager.open.bind(PopupManager.COLOR), ""))

	register(Command.new("Play/Pause timeline", EditorCore.on_play_pressed, "timeline_play_pause"))
	register(Command.new("Focus on playhead", Timeline.focus_on_playhead, "focus_on_playhead"))
	register(Command.new("Select mode", Timeline.set_state.bind(Timeline.State.SELECT), "timeline_mode_select"))
	register(Command.new("Split mode", Timeline.set_state.bind(Timeline.State.SPLIT), "timeline_mode_split"))

	register(Command.new("Next frame", EditorCore.next_frame, "next_frame"))
	register(Command.new("Previous frame", EditorCore.previous_frame, "prev_frame"))
	register(Command.new("Set render region in", Project.set_render_region_in, "render_region_in"))
	register(Command.new("Set render region out", Project.set_render_region_out, "render_region_out"))

	register(Command.new("Split clips at playhead", Timeline.split_clips_at, "split_clips_at_playhead"))
	register(Command.new("Copy selected clips", ClipLogic.copy_selected_clips, "ui_copy"))
	register(Command.new("Cut selected clips", ClipLogic.cut_selected_clips, "ui_cut"))
	register(Command.new("Paste clips", InputManager.clipboard_paste, "ui_paste"))
	register(Command.new("Delete selected clips", ClipLogic.delete_selected_clips, "delete_clips"))
	register(Command.new("Ripple delete selected clips", ClipLogic.ripple_delete_selected_clips, "ripple_delete_clips"))
	register(Command.new("Duplicate selected clips", ClipLogic.duplicate_selected_clips, "duplicate_selected_clips"))
	register(Command.new("Group selected clips", ClipLogic.group_selected_clips, "group_clips"))
	register(Command.new("Ungroup selected clips", ClipLogic.ungroup_selected_clips, "ungroup_clips"))
	register(Command.new("Trim clips to start", Timeline.trim_clips_to_start, "trim_clips_to_start"))
	register(Command.new("Trim clips to end", Timeline.trim_clips_to_end, "trim_clips_to_end"))

	register(Command.new("Add track", TrackLogic.add_track_to_end, ""))
	register(Command.new("Clear selection", ClipLogic.clear_selection, ""))

	register(Command.new("Undo", InputManager.undo_redo.undo, "ui_undo"))
	register(Command.new("Redo", InputManager.undo_redo.redo, "ui_redo"))

	register(Command.new("Open marker popup", InputManager.open_marker_popup, "open_marker_popup"))
	register(Command.new("About GoZen", PopupManager.open.bind(PopupManager.CREDITS), "help"))

	if Settings.on_localization_updated.connect(_localize_commands): print_stack()


func _localize_commands() -> void:
	for i: int in commands.size(): commands[i] = tr(base_commands[i])


#--- Command registering ---

func register(cmd: Command) -> void:
	commands.append(tr(cmd.command))
	base_commands.append(cmd.command) # Has to be the original English translation.

	calls.append(cmd.callable)
	actions.append(cmd.action)


#--- Getters ---

func get_text(index: int) -> String:   return ("%s [%s]" % [commands[index], actions[index]]).replace(' []', '')
func get_call(index: int) -> Callable: return calls[index]
func get_action(index: int) -> String: return actions[index]


func get_sorted_indexes() -> Array[int]:
	var data: Array[int] = []
	for index: int in commands.size(): data.append(index)

	data.sort_custom(func(a: int, b: int) -> bool:
			return commands[a].naturalcasecmp_to(commands[b]) < 0)
	return data



class Command:
	var command: StringName
	var callable: Callable
	var action: StringName


	func _init(_command: StringName, _callable: Callable, _action: StringName) -> void:
		command = _command
		callable = _callable
		action = _action
