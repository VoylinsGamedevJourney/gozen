class_name WorkspaceNode
extends Resource


enum { TAB, HSPLIT, VSPLIT}


@export var type: int = TAB

@export var current_tab: int = 0
@export var panel_ids: Array[String] = []
@export var split_offsets: PackedInt32Array = []
@export var children: Array[WorkspaceNode] = []
