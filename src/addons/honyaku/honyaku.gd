@tool
extends Control

const PATH: String = "res://translations/"

const COLOR_KEY: Color = Color.DARK_GRAY
const COLOR_FUZZY: Color = Color(0.6, 0.1, 0.6, 0.2)
const COLOR_EMPTY: Color = Color(0.6, 0.1, 0.1, 0.2)
const COLOR_CLEAR: Color = Color(0,0,0,0)

const COLOR_PROGRESS_SAVED: Color = Color.WHITE
const COLOR_PROGRESS_UNSAVED: Color = Color.RED


@export var translation_tree: Tree
@export var button_save: Button
@export var button_add_language: Button
@export var button_refresh_list: Button
@export var menu_languages: MenuButton


var translation_data: Dictionary = {} ## { "KEY": { "references": PackedStringArray, "translations": { "en": { "str": translation, "fuzzy": bool } } } }
var list_languages: PackedStringArray = []
var hidden_languages: PackedStringArray =[]

var context_menu: PopupMenu
var context_item: TreeItem
var context_column: int

var add_language_dialog: ConfirmationDialog
var add_language_input: LineEdit



func _ready() -> void:
	button_save.pressed.connect(_on_save_pressed)
	button_add_language.pressed.connect(_on_add_language_pressed)
	button_refresh_list.pressed.connect(_refresh_all)
	translation_tree.item_edited.connect(_on_item_edited)
	translation_tree.button_clicked.connect(_on_grid_button_clicked)

	var popup: PopupMenu = menu_languages.get_popup()
	popup.hide_on_checkable_item_selection = false
	popup.id_pressed.connect(_on_language_toggled)

	context_menu = PopupMenu.new()
	context_menu.add_item("Toggle Fuzzy", 0)
	context_menu.id_pressed.connect(_on_context_menu_pressed)

	add_child(context_menu)
	_setup_add_language_dialog()
	_refresh_all()


func _get_all_files(path: String, ignored: Array) -> Array:
	for ignore: String in ignored:
		if path.begins_with(ignore):
			return []

	var files: PackedStringArray =[]
	var dir: DirAccess = DirAccess.open(path)
	if not dir: return files

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			files.append_array(_get_all_files(path.path_join(file_name), ignored))
		elif file_name.ends_with(".gd") or file_name.ends_with(".tscn"):
			files.append(path.path_join(file_name))
		file_name = dir.get_next()
	return files


func _load_existing_po_files() -> void:
	list_languages.clear()
	translation_data.clear()

	var pot_path: String = PATH.path_join("localization_template.pot")
	_parse_po_file(pot_path, "")
	var valid_keys: Array = translation_data.keys().duplicate()

	var dir: DirAccess = DirAccess.open(PATH)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".po"):
			var language: String = file_name.get_basename()
			list_languages.append(language)
			if !hidden_languages.has(language):
				hidden_languages.append(language)
			_parse_po_file(PATH.path_join(file_name), language)
		file_name = dir.get_next()

	for key: String in translation_data.keys():
		if key not in valid_keys:
			translation_data.erase(key)


func _parse_po_file(file_path: String, language: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	var current_msgid: String = ""
	var current_msgstr: String = ""
	var current_references: PackedStringArray =[]
	var is_fuzzy: bool = false
	var parsing_msgid: bool = false
	var parsing_msgstr: bool = false

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("#:"):
			var reference_line: String = line.substr(2).strip_edges()
			if reference_line != "":
				for reference: String in reference_line.split(" ", false):
					current_references.append(reference.strip_edges())
		elif line.begins_with("#, fuzzy"):
			is_fuzzy = true
		elif line.begins_with("msgid "):
			if parsing_msgid or parsing_msgstr:
				_add_parsed_entry(current_msgid, current_msgstr, current_references, is_fuzzy, language)
				current_msgid = ""
				current_msgstr = ""
				current_references.clear()
				is_fuzzy = false
			current_msgid = _extract_string(line)
			parsing_msgid = true
			parsing_msgstr = false
		elif line.begins_with("msgstr "):
			current_msgstr = _extract_string(line)
			parsing_msgstr = true
			parsing_msgid = false
		elif line.begins_with("\"") and line.ends_with("\""):
			if parsing_msgid:
				current_msgid += _extract_string(line)
			elif parsing_msgstr:
				current_msgstr += _extract_string(line)
		elif line == "":
			if parsing_msgid or parsing_msgstr:
				_add_parsed_entry(current_msgid, current_msgstr, current_references, is_fuzzy, language)
				current_msgid = ""
				current_msgstr = ""
				current_references.clear()
				is_fuzzy = false
				parsing_msgid = false
				parsing_msgstr = false

	if parsing_msgid or parsing_msgstr:
		_add_parsed_entry(current_msgid, current_msgstr, current_references, is_fuzzy, language)


func _add_parsed_entry(msgid: String, msgstr: String, references: Array, fuzzy: bool, language: String) -> void:
	if msgid == "":
		return
	elif not translation_data.has(msgid):
		translation_data[msgid] = { "references":[], "translations": {} }

	for reference: String in references:
		if not reference in translation_data[msgid]["references"]:
			translation_data[msgid]["references"].append(reference)

	if language != "":
		translation_data[msgid]["translations"][language] = {"str": msgstr, "fuzzy": fuzzy}


func _extract_string(line: String) -> String:
	var start: int = line.find("\"")
	var end: int = line.rfind("\"")
	if start != -1 and end != -1 and start != end:
		return line.substr(start + 1, end - start - 1).c_unescape()
	return ""


func _setup_add_language_dialog() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = "Enter Locale Code (e.g. en, fr, ja):"

	add_language_dialog = ConfirmationDialog.new()
	add_language_dialog.title = "Add New Language"
	add_language_dialog.min_size = Vector2(300, 100)

	add_language_input = LineEdit.new()
	add_language_input.custom_minimum_size.x = 250
	add_language_dialog.confirmed.connect(_on_language_confirmed)

	vbox.add_child(label)
	vbox.add_child(add_language_input)
	add_language_dialog.add_child(vbox)
	add_child(add_language_dialog)


func _on_add_language_pressed() -> void:
	add_language_input.text = ""
	add_language_dialog.popup_centered()
	add_language_input.grab_focus()


func _on_language_confirmed() -> void:
	var new_language: String = add_language_input.text.strip_edges()
	if new_language.is_empty():
		return
	elif new_language in list_languages:
		print("Language '%s' already exists." % new_language)
		return

	list_languages.append(new_language)
	for key: String in translation_data:
		if not translation_data[key]["translations"].has(new_language):
			translation_data[key]["translations"][new_language] = {"str": "", "fuzzy": false}

	button_save.text = "Save progress*"
	button_save.modulate = COLOR_PROGRESS_UNSAVED
	_update_language_menu()
	_refresh_grid()


func _update_language_menu() -> void:
	var popup: PopupMenu = menu_languages.get_popup()
	popup.clear()
	for i: int in list_languages.size():
		popup.add_check_item(list_languages[i], i)
		popup.set_item_checked(i, not list_languages[i] in hidden_languages)


func _on_language_toggled(id: int) -> void:
	var popup: PopupMenu = menu_languages.get_popup()
	var language: String = list_languages[id]
	if popup.is_item_checked(id):
		hidden_languages.append(language)
		popup.set_item_checked(id, false)
	else:
		hidden_languages.erase(language)
		popup.set_item_checked(id, true)
	_refresh_grid()


func _refresh_all() -> void:
	if button_save.modulate == COLOR_PROGRESS_UNSAVED:
		print("Please save your changes before refreshing.")
		return
	var list: PackedStringArray = hidden_languages.duplicate()
	_load_existing_po_files()
	if list.size() != 0:
		hidden_languages = list

	_update_language_menu()
	_refresh_grid()
	button_save.text = "Save progress"
	button_save.modulate = COLOR_PROGRESS_SAVED


func _refresh_grid() -> void:
	translation_tree.clear()
	var visible_languages: PackedStringArray =[]
	for language in list_languages:
		if not language in hidden_languages:
			visible_languages.append(language)

	translation_tree.columns = 1 + visible_languages.size()
	translation_tree.set_column_custom_minimum_width(0, 150)
	var root: TreeItem = translation_tree.create_item()
	translation_tree.set_column_title(0, "Original Key")
	for i: int in visible_languages.size():
		translation_tree.set_column_title(i + 1, visible_languages[i])
		translation_tree.set_column_expand(i + 1, true)
		translation_tree.set_column_custom_minimum_width(i + 1, 150)

	var open_icon: Texture2D = EditorInterface.get_editor_theme().get_icon("FileBrowse", "EditorIcons")
	for key: String in translation_data.keys():
		var item: TreeItem = translation_tree.create_item(root)
		var color: Color = COLOR_KEY
		color.a = 0.1
		item.set_text(0, key)
		item.set_metadata(0, key)
		item.set_custom_bg_color(0, color)
		item.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD)

		if translation_data[key]["references"].size() > 0:
			item.add_button(0, open_icon, 0, false, "Open source file")
			item.set_tooltip_text(0, _generate_context_tooltip(translation_data[key]["references"]))

		for i: int in visible_languages.size():
			var language: String = visible_languages[i]
			var column: int = i + 1
			item.set_editable(column, true)
			item.set_autowrap_mode(column, TextServer.AUTOWRAP_WORD)

			if translation_data[key]["translations"].has(language):
				var translation_info: Dictionary = translation_data[key]["translations"][language]
				item.set_text(column, translation_info.str)

				if translation_info.fuzzy:
					item.set_custom_bg_color(column, COLOR_FUZZY)
				elif translation_info.str.strip_edges() == "":
					item.set_custom_bg_color(column, COLOR_EMPTY)
			else:
				item.set_custom_bg_color(column, COLOR_EMPTY)


func _generate_context_tooltip(references: Array) -> String:
	var tooltip: String = "Found in:\n"
	for reference: String in references:
		tooltip += "- " + reference + "\n"

	if references.size() > 0:
		var parts: PackedStringArray = references[0].split(":")
		if parts.size() == 2:
			var path: String = parts[0]
			var line: int = int(parts[1]) - 1
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if !file:
				return tooltip
			var lines: PackedStringArray = file.get_as_text().split("\n")
			tooltip += "\n--- Context preview --- \n"
			for i: int in range(max(0, line - 3), min(lines.size(), line + 4)):
				var prefix: String = ">> " if i == line else "   "
				tooltip += prefix + lines[i].strip_edges() + "\n"
	return tooltip


func _on_grid_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	var key: String = item.get_metadata(0)
	var references: PackedStringArray = translation_data[key]["references"]
	if references.size() > 0:
		var parts: PackedStringArray = references[0].split(":")
		var path: String = parts[0]
		var line: int = int(parts[1]) if parts.size() > 1 else 0
		var resource: Variant = load(path)
		if resource:
			EditorInterface.edit_resource(resource)
			if resource is Script:
				EditorInterface.get_script_editor().goto_line(line - 1)


func _on_item_edited() -> void:
	var item: TreeItem = translation_tree.get_edited()
	var column: int = translation_tree.get_edited_column()
	var key: String = item.get_metadata(0)
	var visible_languages: PackedStringArray =[]
	for language: String in list_languages:
		if not language in hidden_languages:
			visible_languages.append(language)

	var language: String = visible_languages[column - 1]
	if not translation_data[key]["translations"].has(language):
		translation_data[key]["translations"][language] = {"str": "", "fuzzy": false}

	translation_data[key]["translations"][language]["str"] = item.get_text(column)
	translation_data[key]["translations"][language]["fuzzy"] = false
	item.set_custom_bg_color(column, Color(0,0,0,0))
	if item.get_text(column).strip_edges() == "":
		item.set_custom_bg_color(column, Color(0.6, 0.1, 0.1, 0.5))
	button_save.text = "Save progress*"
	button_save.modulate = COLOR_PROGRESS_UNSAVED


func _on_save_pressed() -> void:
	DirAccess.make_dir_absolute(PATH)
	for language: String in list_languages:
		var path: String = PATH.path_join("%s.po" % language)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_line('msgid ""\nmsgstr ""\n"Project-Id-Version: GoZen\\n"\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n"Language: %s\\n"\n' % language)

		for key: String in translation_data.keys():
			var entry: Dictionary = translation_data[key]
			var translation: Dictionary = entry["translations"].get(language, {"str": "", "fuzzy": false})
			for reference: String in entry["references"]:
				file.store_line("#: " + reference)
			if translation["fuzzy"]:
				file.store_line("#, fuzzy")

			_save_po_entry(file, "msgid", key)
			_save_po_entry(file, "msgstr", translation["str"])
			file.store_line("") # Empty line between entries.

	button_save.text = "Save progress"
	button_save.modulate = COLOR_PROGRESS_SAVED
	print("PO Files Saved successfully!")


func _save_po_entry(file: FileAccess, prefix: String, text: String) -> void:
	var escaped_text: String = text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\t", "\\t")
	if escaped_text.length() < 80 and not "\n" in escaped_text:
		file.store_line('%s "%s"' % [prefix, escaped_text])
		return

	file.store_line('%s ""' % prefix)
	var lines: PackedStringArray = escaped_text.split("\n")
	for i in lines.size():
		var line_content: String = lines[i]

		# Split at 80 columns.
		if i < lines.size() - 1:
			line_content += "\\n"
		if line_content.length() > 80:
			var chunks: PackedStringArray = _chunk_string(line_content, 78) # 78 because of "".
			for chunk: String in chunks:
				file.store_line('"%s"' % chunk)
		else:
			file.store_line('"%s"' % line_content)


func _chunk_string(text: String, size: int) -> PackedStringArray:
	var chunks: PackedStringArray = []
	var i: int = 0
	while i < text.length():
		chunks.append(text.substr(i, size))
		i += size
	return chunks


func _on_translation_tree_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event

	var item: TreeItem = translation_tree.get_item_at_position(mouse_event.position)
	if !item:
		return
	var column: int = translation_tree.get_column_at_position(mouse_event.position)
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
		if mouse_event.double_click:
			var key: String = item.get_metadata(0)
			DisplayServer.clipboard_set(key)
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and column > 0:
		context_item = item
		context_column = column
		context_menu.position = get_global_mouse_position()
		context_menu.popup()


func _on_context_menu_pressed(id: int) -> void:
	if !context_item:
		return

	var key: String = context_item.get_metadata(0)
	var visible_languages: PackedStringArray = []
	for language: String in list_languages:
		if language not in hidden_languages:
			visible_languages.append(language)

	var language: String = visible_languages[context_column - 1]
	if !translation_data[key]["translations"].has(language):
		translation_data[key]["translations"][language] = {"str": "", "fuzzy": false }

	var entry = translation_data[key]["translations"][language]
	entry["fuzzy"] = !entry["fuzzy"]

	if entry["fuzzy"]:
		context_item.set_custom_bg_color(context_column, COLOR_FUZZY)
	else:
		context_item.set_custom_bg_color(context_column, COLOR_CLEAR)
