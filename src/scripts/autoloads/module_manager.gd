extends Node

const CONFIG_FILE: String = "user://modules_config.json"
const PATH_MODULES_GLOBAL: String = "user://modules/"
const PATH_MODULES_LOCAL: String = "res://modules/"

var loaded_modules: Dictionary = {}
var loaded_gozen_modules: Array[GoZenModule] = []



func _enter_tree() -> void:
	if not DirAccess.dir_exists_absolute(PATH_MODULES_GLOBAL):
		if DirAccess.make_dir_absolute(PATH_MODULES_GLOBAL) not in [ERR_ALREADY_EXISTS, OK]:
			printerr("ModuleManager: '%s' could not be created!" % PATH_MODULES_GLOBAL)

	_load_config()
	_apply_modules()


func _load_config() -> void:
	if FileAccess.file_exists(CONFIG_FILE):
		var file: FileAccess = FileAccess.open(CONFIG_FILE, FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) == TYPE_DICTIONARY:
			loaded_modules = data


func _save_config() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if !file.store_string(JSON.stringify(loaded_modules, "\t")):
		printerr("ModuleManager: Couldn't store string to config file!")


func _apply_modules() -> void:
	for filename: String in loaded_modules.keys():
		var dict: Dictionary = loaded_modules[filename]
		if dict.get("enabled", false):
			var path: String = PATH_MODULES_GLOBAL.path_join(filename)
			if !FileAccess.file_exists(path): continue
			elif !ProjectSettings.load_resource_pack(path):
				printerr("ModuleManager: Couldn't load resource at '%s'!" % path)

	if !DirAccess.dir_exists_absolute(PATH_MODULES_LOCAL): return

	for module_dir: String in DirAccess.get_directories_at(PATH_MODULES_LOCAL):
		if module_dir.begins_with("."): continue
		var module_tres: String = PATH_MODULES_LOCAL.path_join(module_dir).path_join("module.tres")
		if FileAccess.file_exists(module_tres):
			var res: Resource = load(module_tres)
			if res is GoZenModule:
				loaded_gozen_modules.append(res)


func register_panels() -> void:
	for module: GoZenModule in loaded_gozen_modules:
		for module_panel: GoZenModulePanel in module.custom_panels:
			if !module_panel or !module_panel.scene: continue
			var panel: Node = module_panel.scene.instantiate()
			if panel is Control:
				WorkspaceManager.register_panel(panel.name, panel as Control)


func register_effects() -> void:
	for module: GoZenModule in loaded_gozen_modules:
		for module_effect: GoZenModuleEffect in module.custom_effects:
			if module_effect and module_effect.effect:
				var effect: Effect = module_effect.effect
				if !effect.shader_path.is_empty(): # Visual.
					if not EffectsHandler.visual_effect_instances.has(effect.id):
						EffectsHandler.visual_effects[effect.nickname] = effect.id
						EffectsHandler.visual_effect_instances[effect.id] = effect
						EffectsHandler.shader_cache[effect.shader_path] = load(effect.shader_path)
				elif effect.audio_effect:
					if not EffectsHandler.audio_effect_instances.has(effect.id):
						EffectsHandler.audio_effects[effect.nickname] = effect.id
						EffectsHandler.audio_effect_instances[effect.id] = effect
		for module_transition: GoZenModuleTransition in module.custom_transitions:
			if module_transition and module_transition.transition:
				var transition: Effect = module_transition.transition
				if not EffectsHandler.transition_instances.has(transition.id):
					EffectsHandler.transitions[transition.nickname] = transition.id
					EffectsHandler.transition_instances[transition.id] = transition
					EffectsHandler.shader_cache[transition.shader_path] = load(transition.shader_path)


func register_themes() -> void:
	for module: GoZenModule in loaded_gozen_modules:
		for module_theme: GoZenModuleTheme in module.custom_themes:
			if module_theme and module_theme.theme:
				var theme: Theme = module_theme.theme
				var theme_name: String = theme.resource_name
				if theme_name.is_empty():
					theme_name = module.name + " Theme"
				Settings.custom_themes[theme_name] = theme.resource_path


func install_module(path: String) -> void:
	var filename: String = path.get_file()
	var target_path: String = PATH_MODULES_GLOBAL.path_join(filename)
	var err: int = DirAccess.copy_absolute(path, target_path)
	if err != OK:
		printerr("Failed to copy module to: ", target_path)
		return

	loaded_modules[filename] = {
		"enabled": true,
		"name": filename,
		"description": "Custom module" }
	_save_config()


func delete_module(filename: String) -> void:
	if loaded_modules.has(filename):
		if !loaded_modules.erase(filename): Print.stack_erase()
		var target_path: String = PATH_MODULES_GLOBAL.path_join(filename)
		if FileAccess.file_exists(target_path) and DirAccess.remove_absolute(target_path) != OK:
			printerr("ModuleManager: Can't remove dir '%s'!" % target_path)

		_save_config()


func set_module_enabled(filename: String, enabled: bool) -> void:
	if loaded_modules.has(filename):
		var dict: Dictionary = loaded_modules[filename]
		dict["enabled"] = enabled
		_save_config()
