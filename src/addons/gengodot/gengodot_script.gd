@tool
extends MarginContainer
# TODO: For future, have categories as people will not neceserally use default modules.
# For the modules, these should have an entry in theinfo.tres file of where language files
# are located.

const PATH_POT := "res://translations/gozen-translations/po_files/translations_template.pot"
const PATH_PO_FILES := "res://translations/gozen-translations/po_files/"
const PATH_MO_FILES := "res://translations/"

const POT_HEADERS := [
	"msgid \"\"",
	"msgstr \"\"",
	"\"Project-Id-Version: GoZen - Video Editor\\n\"",
	"\"MIME-Version: 1.0\\n\"",
	"\"Content-Type: text/plain; charset=UTF-8\\n\"",
	"\"Content-Transfer-Encoding: 8-bit\\n\""] 
const POT_HEADER_LANGUAGE := "\"Language: {language_code}\\n\""


# For easily accessing data from the UI
#var ids := []
#var first_language := []
#var second_language := []

var pot_data : Dictionary = {} # Key is 'msgid'


func _on_generate_pot_button_pressed() -> void:
	var l_original_pot_data: Dictionary = _get_po_data(PATH_POT)
	pass


func _on_generate_po(language_code: String, data: Dictionary) -> void:
	# First line: # LANGUAGE translation for GoZen - Video Editor for the following files:
	# After that first all file occurances make packed string array?
	# Make another packed string array with the rest of the file data
	# 
	# Put the first line and occurances, followed by the standard headers
	# Add the language header and repalce language code
	# Add empty line
	# Add all other data
	pass


func _on_generate_mo_button_pressed() -> void:
	var l_po_path: String = PATH_PO_FILES.replace("res://", ProjectSettings.globalize_path("res://"))
	var l_mo_path: String = PATH_MO_FILES.replace("res://", ProjectSettings.globalize_path("res://"))
	print("Generating mo files ...")
	for l_po_file: String in DirAccess.get_files_at(PATH_PO_FILES):
		if l_po_file.split('.')[-1] == "pot":
			continue
		OS.execute("msgfmt", [ l_po_path + l_po_file, "-o", l_mo_path + l_po_file.replace(".po", ".mo")])


func _get_po_data(a_file_path: String) -> Dictionary:
	# NOTE: For testing only, get all data from POT file.
	var l_data: Dictionary = {}
	var l_file := FileAccess.open(a_file_path, FileAccess.READ)
	while l_file.get_line() != "": 
		pass # Getting to the beginning of the data
	
	while !l_file.eof_reached():
		var l_entry := Entry.new()
		while true:
			var string: String = l_file.get_line()
			if string == "": # expecting new entry
				l_data[l_entry.msgid] = l_entry
				break
			elif string[0] == "#": # String location
				l_entry.occurrence.append(string)
			elif string.split(' ')[0] == "msgid":
				l_entry.msgid = string.trim_prefix("msgid \"").trim_suffix("\"")
			elif string.split(' ')[0] == "msgstr":
				l_entry.msgstr = string.trim_prefix("msgstr \"").trim_suffix("\"")
	return l_data


func _on_load_localization_button_pressed() -> void:
	pass


class Entry:
	var msgctxt: String
	var msgid: String
	var msgstr: String
	var occurrence: PackedStringArray
