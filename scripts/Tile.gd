extends Control
class_name Tile

@onready var background = $Background
@onready var label = $Label

var number : int = 0
var grid_position = Vector2()

func _ready():
	background.gui_input.connect(_on_gui_input)
	background.mouse_entered.connect(_on_mouse_entered)
	background.mouse_exited.connect(_on_mouse_exited)
	update_display()

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_pressed()

func _on_mouse_entered():
	if get_parent() and get_parent().has_method("_on_tile_hover"):
		get_parent()._on_tile_hover(self, true)

func _on_mouse_exited():
	if get_parent() and get_parent().has_method("_on_tile_hover"):
		get_parent()._on_tile_hover(self, false)

func _on_pressed():
	if get_parent() and get_parent().has_method("_on_tile_pressed"):
		get_parent()._on_tile_pressed(self)

func set_number(value):
	number = value
	update_display()

func update_display():
	if number > 0:
		label.text = str(number)
	else:
		label.text = ""

func set_highlight(highlighted: bool):
	if highlighted:
		background.add_theme_stylebox_override("panel", get_parent().highlight_style)
	else:
		background.add_theme_stylebox_override("panel", get_parent().normal_style)
