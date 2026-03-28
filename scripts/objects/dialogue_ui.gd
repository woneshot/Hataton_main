extends CanvasLayer

# Ссылки на узлы по иерархии из ТЗ
@onready var actor_name: Label = $DialogRoot/Panel/MarginContainer/VBoxContainer/ActorName
@onready var dialog_text: Label = $DialogRoot/Panel/MarginContainer/VBoxContainer/DialogText
@onready var continue_hint: Label = $DialogRoot/Panel/MarginContainer/VBoxContainer/ContinueHint

# Текущий ресурс диалога, который мы перетащим в инспекторе
@export var current_entry: DialogueEntry

var is_typing: bool = false

func _ready() -> void:
	# Настройки внешнего вида по ТЗ
	actor_name.uppercase = true
	continue_hint.modulate = Color8(150, 150, 150) # Серый
	
	if current_entry:
		display_entry(current_entry)
	else:
		hide() # Прячем интерфейс, если диалога нет

func display_entry(entry: DialogueEntry) -> void:
	if not entry:
		hide()
		return
	
	show()
	current_entry = entry
	actor_name.text = entry.speaker_name
	_animate_text(entry.text)

func _animate_text(content: String) -> void:
	is_typing = true
	continue_hint.hide()
	dialog_text.text = content
	dialog_text.visible_ratio = 0.0
	
	# Библейский эффект печати через Tween
	var tween = create_tween()
	tween.tween_property(dialog_text, "visible_ratio", 1.0, 1.0)
	tween.finished.connect(func(): 
		is_typing = false
		continue_hint.show()
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if is_typing:
			# Скип анимации (показываем всё сразу)
			pass 
		elif continue_hint.visible:
			# Переходим к следующему ресурсу, если он есть
			display_entry(current_entry.next_entry)
