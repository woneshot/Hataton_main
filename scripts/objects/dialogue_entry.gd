class_name DialogueEntry
extends Resource

enum ConditionType {
	NONE,
	HAS_ITEM,
	FLAG_TRUE,
	FLAG_FALSE
}

@export var condition_type: ConditionType = ConditionType.NONE
@export var condition_value: String = ""

@export_group("Dialogue")
@export var lines: Array[String] = []
@export var voice_lines: Array[AudioStream] = []

@export_group("On Complete")
@export var set_flags: Array[String] = []
@export var consume_item: bool = false
