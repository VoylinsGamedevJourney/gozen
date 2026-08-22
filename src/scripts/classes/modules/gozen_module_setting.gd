class_name GoZenModuleSetting
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var default_value: Variant

@export_group("Number Settings (Int & Float)")
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
@export var allow_lesser: bool = false
@export var allow_greater: bool = false

@export_group("Dropdown Setting (Option menu)")
@export var options: Dictionary = {} ## Format: {"Label": Value}. If filled, it creates a dropdown.
