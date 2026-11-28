extends Node

const PATH_MODULES_LOCAL: String = "res://modules/"


var loaded_modules: Dictionary = {}
var loaded_gozen_modules: Array[GoZenModule] = []



func get_config_file() -> String:
	return Utils.get_config_dir().path_join("modules_config.json")


func get_modules_global_path() -> String:
	return Utils.get_config_dir().path_join("modules")


func _enter_tree() -> void:
	if not DirAccess.dir_exists_absolute(get_modules_global_path()):
		if DirAccess.make_dir_absolute(get_modules_global_path()) not in [ERR_ALREADY_EXISTS, OK]:
			printerr("ModuleManager: '%s' could not be created!" % get_modules_global_path())

	_load_config()
	_apply_modules()


func _load_config() -> void:
	if FileAccess.file_exists(get_config_file()):
		var file: FileAccess = FileAccess.open(get_config_file(), FileAccess.READ)
		if file == null:
			printerr("ModuleManager: Couldn't open config file at '%s'!" % get_config_file())
			return
		var data: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY:
			loaded_modules = data


func _save_config() -> void:
	var file: FileAccess = FileAccess.open(get_config_file(), FileAccess.WRITE)
	if file == null:
		printerr("ModuleManager: Couldn't open config file for writing at '%s'!" % get_config_file())
		return
	if !file.store_string(JSON.stringify(loaded_modules, "\t")) or file.get_error():
		printerr("ModuleManager: Couldn't store string to config file!")
	file.close()


func _apply_modules() -> void:
	if not OS.has_feature("lite"):
		for filename: String in loaded_modules.keys():
			var dict: Dictionary = loaded_modules[filename]
			if dict.get("enabled", false):
				var path: String = get_modules_global_path().path_join(filename)
				if !FileAccess.file_exists(path):
					continue
				elif !ProjectSettings.load_resource_pack(path):
					printerr("ModuleManager: Couldn't load resource at '%s'!" % path)

	if !DirAccess.dir_exists_absolute(PATH_MODULES_LOCAL):
		return

	for module_dir: String in DirAccess.get_directories_at(PATH_MODULES_LOCAL):
		if module_dir.begins_with("."):
			continue
		elif OS.has_feature("lite") and module_dir.begins_with("extra_"):
			continue

		var module_dir_path: String = PATH_MODULES_LOCAL.path_join(module_dir)
		register_module_uids(module_dir_path)

		var module_tres: String = module_dir_path.path_join("module.tres")
		if ResourceLoader.exists(module_tres):
			var module_resource: Resource = load(module_tres)
			if module_resource is GoZenModule:
				loaded_gozen_modules.append(module_resource)

	if not OS.has_feature("lite"):
		var config_changed: bool = false
		for filename: String in loaded_modules.keys():
			var data: Dictionary = loaded_modules[filename]
			if data.get("enabled", false) and data.get("name") == filename:
				for module: GoZenModule in loaded_gozen_modules:
					if module.resource_path.get_base_dir().get_file() == filename.get_basename() or module.name.to_lower().replace(" ", "_") == filename.get_basename():
						data["name"] = module.name
						data["description"] = module.description
						config_changed = true
						break
		if config_changed:
			_save_config()


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
				_register_effect(module_effect)
		for module_transition: GoZenModuleTransition in module.custom_transitions:
			if module_transition and module_transition.transition:
				_register_transition(module_transition)


func _register_effect(module_effect: GoZenModuleEffect) -> void:
	var effect: Effect = module_effect.effect
	if !effect.audio_effect: # Visual.
		if not EffectsHandler.visual_effect_instances.has(effect.id):
			EffectsHandler.visual_effects[effect.nickname] = effect.id
			EffectsHandler.visual_effect_instances[effect.id] = effect
			if effect.shader_path.is_empty():
				EffectsHandler.shader_cache[effect.shader_path] = null
			else:
				var loaded_shader: Resource = load(effect.shader_path)
				if loaded_shader is RDShaderFile:
					EffectsHandler.shader_cache[effect.shader_path] = loaded_shader as RDShaderFile
				else:
					printerr("ModuleManager: Failed to load shader '%s' for effect '%s'!" % [effect.shader_path, effect.id])
	else: # Audio.
		if not EffectsHandler.audio_effect_instances.has(effect.id):
			EffectsHandler.audio_effects[effect.nickname] = effect.id
			EffectsHandler.audio_effect_instances[effect.id] = effect


func _register_transition(module_transition: GoZenModuleTransition) -> void:
	var transition: Effect = module_transition.transition
	if not EffectsHandler.transition_instances.has(transition.id):
		EffectsHandler.transitions[transition.nickname] = transition.id
		EffectsHandler.transition_instances[transition.id] = transition
		if not transition.shader_path.is_empty():
			var loaded_shader: Resource = load(transition.shader_path)
			if loaded_shader is RDShaderFile:
				EffectsHandler.shader_cache[transition.shader_path] = loaded_shader as RDShaderFile
			else:
				printerr("ModuleManager: Failed to load shader '%s' for transition '%s'!" % [transition.shader_path, transition.id])


func register_themes() -> void:
	for module: GoZenModule in loaded_gozen_modules:
		for module_theme: GoZenModuleTheme in module.custom_themes:
			if module_theme and module_theme.theme:
				_register_theme(module_theme)


func _register_theme(module_theme: GoZenModuleTheme) -> void:
	var theme: Theme = module_theme.theme
	var theme_name: String = theme.resource_name
	if theme_name.is_empty():
		theme_name = theme.resource_path.get_file().get_basename().capitalize()
	Settings.custom_themes[theme_name] = theme.resource_path


func install_module(path: String) -> bool:
	var filename: String = path.get_file()
	var target_path: String = get_modules_global_path().path_join(filename)
	var err: int = DirAccess.copy_absolute(path, target_path)
	if err != OK:
		printerr("ModuleManager: Failed to copy module to: ", target_path)
		return false

	var module_name: String = filename
	var module_desc: String = "Custom module"
	var module_loaded: bool = false

	var existing_dirs: Array[String] = []
	if DirAccess.dir_exists_absolute(PATH_MODULES_LOCAL):
		existing_dirs.assign(DirAccess.get_directories_at(PATH_MODULES_LOCAL))

	if not ProjectSettings.load_resource_pack(target_path):
		printerr("ModuleManager: Failed to load resource pack at '%s'!" % target_path)
		if FileAccess.file_exists(target_path):
			DirAccess.remove_absolute(target_path)
		return false

	var expected_dir: String = filename.get_basename()
	var dirs_to_check: Array[String] = []
	for module_dir: String in DirAccess.get_directories_at(PATH_MODULES_LOCAL):
		if !module_dir.begins_with("."):
			if module_dir not in existing_dirs or module_dir == expected_dir:
				dirs_to_check.append(module_dir)

	for module_dir: String in dirs_to_check:
		var module_dir_path: String = PATH_MODULES_LOCAL.path_join(module_dir)
		register_module_uids(module_dir_path)

		var module_tres: String = module_dir_path.path_join("module.tres")

		var already_loaded_mod: GoZenModule = null
		var already_loaded_idx: int = -1
		for i: int in loaded_gozen_modules.size():
			if loaded_gozen_modules[i].resource_path == module_tres:
				already_loaded_mod = loaded_gozen_modules[i]
				already_loaded_idx = i
				break

		@warning_ignore_start("unsafe_property_access")
		if ResourceLoader.exists(module_tres):
			var module: Resource = ResourceLoader.load(module_tres, "", ResourceLoader.CACHE_MODE_REPLACE)
			if module is GoZenModule:
				module_loaded = true
				module_name = module.name
				module_desc = module.description

				if already_loaded_mod != null:
					loaded_gozen_modules[already_loaded_idx] = module
				else:
					loaded_gozen_modules.append(module)

				# Register elements so they appear immediately
				for module_theme: GoZenModuleTheme in module.custom_themes:
					if module_theme and module_theme.theme:
						_register_theme(module_theme)

				for module_effect: GoZenModuleEffect in module.custom_effects:
					if module_effect and module_effect.effect:
						_register_effect(module_effect)

				for module_transition: GoZenModuleTransition in module.custom_transitions:
					if module_transition and module_transition.transition:
						_register_transition(module_transition)

				for module_panel: GoZenModulePanel in module.custom_panels:
					if !module_panel or !module_panel.scene: continue
					var panel: Node = module_panel.scene.instantiate()
					if panel is Control:
						WorkspaceManager.register_panel(panel.name, panel as Control)
		@warning_ignore_restore("unsafe_property_access")

	if not module_loaded:
		printerr("ModuleManager: Module '%s' could not be loaded cleanly. Ensure it was packed with imported assets." % filename)
		if FileAccess.file_exists(target_path):
			DirAccess.remove_absolute(target_path)
		return false

	loaded_modules[filename] = {
			"enabled": true,
			"name": module_name,
			"description": module_desc }
	_save_config()
	return true


func delete_module(filename: String) -> void:
	if !loaded_modules.has(filename):
		return

	var target_path: String = get_modules_global_path().path_join(filename)
	loaded_modules.erase(filename)

	if FileAccess.file_exists(target_path) and DirAccess.remove_absolute(target_path) != OK:
		printerr("ModuleManager: Can't remove dir '%s'!" % target_path)
	_save_config()

	var base_filename: String = filename.get_basename()
	for i: int in range(loaded_gozen_modules.size() - 1, -1, -1):
		var module: GoZenModule = loaded_gozen_modules[i]
		var module_dir: String = module.resource_path.get_base_dir().get_file()
		var module_name_normalized: String = module.name.to_lower().replace(" ", "_")
		if module_dir != base_filename and module_name_normalized != base_filename:
			continue

		for module_theme: GoZenModuleTheme in module.custom_themes:
			_delete_custom_theme(module_theme)

		for module_effect: GoZenModuleEffect in module.custom_effects:
			if module_effect and module_effect.effect:
				_delete_effect(module_effect)

		for module_transition: GoZenModuleTransition in module.custom_transitions:
			if module_transition and module_transition.transition:
				_delete_transition(module_transition)
		loaded_gozen_modules.remove_at(i)
		break


func _delete_custom_theme(module_theme: GoZenModuleTheme) -> void:
	if module_theme and module_theme.theme:
		var theme: Theme = module_theme.theme
		var theme_name: String = theme.resource_name
		if theme_name.is_empty():
			theme_name = theme.resource_path.get_file().get_basename().capitalize()
		Settings.custom_themes.erase(theme_name)
		if Settings.data.theme == theme.resource_path:
			Settings.set_theme_path(Library.THEME_DEFAULT)


func _delete_effect(module_effect: GoZenModuleEffect) -> void:
	var effect: Effect = module_effect.effect
	if not effect.shader_path.is_empty():
		EffectsHandler.visual_effects.erase(effect.nickname)
		EffectsHandler.visual_effect_instances.erase(effect.id)
		EffectsHandler.shader_cache.erase(effect.shader_path)
	elif effect.audio_effect:
		EffectsHandler.audio_effects.erase(effect.nickname)
		EffectsHandler.audio_effect_instances.erase(effect.id)


func _delete_transition(module_transition: GoZenModuleTransition) -> void:
	var transition: Effect = module_transition.transition
	EffectsHandler.transitions.erase(transition.nickname)
	EffectsHandler.transition_instances.erase(transition.id)
	EffectsHandler.shader_cache.erase(transition.shader_path)


func set_module_enabled(filename: String, enabled: bool) -> void:
	if loaded_modules.has(filename):
		var dict: Dictionary = loaded_modules[filename]
		dict["enabled"] = enabled
		_save_config()


#--- UID handling ---

func register_module_uids(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while entry != "":
			if entry not in [".", ".."]:
				var full_path: String = dir_path.path_join(entry)
				if dir.current_is_dir():
					register_module_uids(full_path)
				elif entry.ends_with(".uid"):
					_register_uid_file(full_path)
				elif entry.ends_with(".import"):
					_register_import_uid(full_path)
				elif entry.ends_with(".tres") or entry.ends_with(".tscn"):
					_register_text_resource_uid(full_path)
			entry = dir.get_next()
		dir.list_dir_end()


func _register_uid_file(uid_file_path: String) -> void:
	var file: FileAccess = FileAccess.open(uid_file_path, FileAccess.READ)
	if file:
		var uid_text: String = file.get_as_text().strip_edges()
		file.close()
		_register_uid(uid_text, uid_file_path.trim_suffix(".uid"))


func _register_import_uid(import_file_path: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(import_file_path) == OK:
		var uid_text: String = str(config.get_value("remap", "uid", ""))
		_register_uid(uid_text, import_file_path.trim_suffix(".import"))


func _register_text_resource_uid(resource_file_path: String) -> void:
	var file: FileAccess = FileAccess.open(resource_file_path, FileAccess.READ)
	if file:
		var header_line: String = file.get_line()
		file.close()
		var uid_marker_index: int = header_line.find("uid=\"uid://")
		if uid_marker_index != -1:
			var uid_start: int = uid_marker_index + 5
			var uid_end: int = header_line.find("\"", uid_start)
			if uid_end != -1:
				_register_uid(header_line.substr(uid_start, uid_end - uid_start), resource_file_path)


func _register_uid(uid_text: String, resource_path: String) -> void:
	if uid_text.begins_with("uid://"):
		var uid_id: int = ResourceUID.text_to_id(uid_text)
		if uid_id != ResourceUID.INVALID_ID:
			if !ResourceUID.has_id(uid_id):
				ResourceUID.add_id(uid_id, resource_path)
			elif ResourceUID.get_id_path(uid_id) != resource_path:
				ResourceUID.set_id(uid_id, resource_path)
