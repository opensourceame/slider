extends Control
class_name Tile

@onready var background = $Background
@onready var label 		= $Label
@onready var texture_rect = $TextureRect

static func BLANK() -> Tile:
	var t = preload("res://scenes/Tile.tscn").instantiate()
	t.number = 0
	return t

var number : int = 0
var grid_position = Vector2.ZERO
var texture: Texture2D

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
	return self

func set_texture(tex: Texture2D):
	texture = tex
	return self
	
func update_display():
	if texture:
		texture_rect.texture = texture
		texture_rect.visible = true
		label.visible = false
	elif number > 0:
		label.text = str(number)
		label.visible = true
		texture_rect.visible = false
	else:
		label.text = ""
		label.hide()
		texture_rect.hide()

func set_highlight(highlighted: bool):
	if highlighted:
		modulate = Color.YELLOW
		background.add_theme_stylebox_override("panel", get_parent().highlight_style)
	else:
		modulate = Color.WHITE
		background.add_theme_stylebox_override("panel", get_parent().normal_style)
