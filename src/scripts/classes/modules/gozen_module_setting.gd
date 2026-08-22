class_name GoZenModuleSetting
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var default_value: Variant

@export_group("Number Settings (Int/Float)")
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
