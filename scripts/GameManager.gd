extends Node2D

var grid_size = Vector2(4, 4)
var tile_size = 100
var tiles = []
var empty_position = Vector2(3, 3)
var tile_scene: PackedScene
var game_won = false
var normal_style: StyleBox
var highlight_style: StyleBox

func _ready():
	tile_scene = preload("res://scenes/Tile.tscn")
	create_styles()
	initialize_grid()
	setup_tiles()

func initialize_grid():
	var numbers = []
	for i in range(1, grid_size.x * grid_size.y):
		numbers.append(i)
	numbers.shuffle()
	
	tiles.clear()
	for y in range(grid_size.y):
		tiles.append([])
		for x in range(grid_size.x):
			tiles[y].append(null)
	
	var index = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if x == empty_position.x and y == empty_position.y:
				tiles[y][x] = 0
			else:
				tiles[y][x] = numbers[index]
				index += 1

func setup_tiles():
	var spacing = 5
	var start_x = 0
	var start_y = 0
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if tiles[y][x] == 0:
				continue
			
			var tile = tile_scene.instantiate()
			tile.position = Vector2(
				start_x + x * (tile_size + spacing),
				start_y + y * (tile_size + spacing)
			)
			tile.grid_position = Vector2(x, y)
			tile.number = tiles[y][x]
			add_child(tile)

func _on_tile_pressed(tile):
	if game_won:
		return
	
	var tile_pos = tile.grid_position
	if can_move(tile_pos):
		swap_with_empty(tile_pos)
		
		var spacing = 5
		var start_x = 0
		var start_y = 0
		
		tile.position = Vector2(
			start_x + empty_position.x * (tile_size + spacing),
			start_y + empty_position.y * (tile_size + spacing)
		)
		tile.grid_position = empty_position
		empty_position = tile_pos
		
		if check_win():
			game_won = true
			print("You won!")

func can_move(position):
	var diff = position - empty_position
	return diff.length_squared() == 1

func swap_with_empty(position):
	var temp = tiles[position.y][position.x]
	tiles[position.y][position.x] = tiles[empty_position.y][empty_position.x]
	tiles[empty_position.y][empty_position.x] = temp

func check_win():
	var expected = 1
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if y == grid_size.y - 1 and x == grid_size.x - 1:
				return tiles[y][x] == 0
			if tiles[y][x] != expected:
				return false
			expected += 1
	return true

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		shuffle_tiles()

func create_styles():
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.BLACK
	
	highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color.DARK_GREEN

func _on_tile_hover(tile: Tile, hovering: bool):
	if hovering:
		highlight_tiles_to_empty(tile)
	else:
		clear_highlights()

func highlight_tiles_to_empty(hovered_tile: Tile):
	var tile_pos = hovered_tile.grid_position
	
	# Check if same row or column as empty
	if tile_pos.x == empty_position.x or tile_pos.y == empty_position.y:
		# Highlight tiles between hovered tile and empty space
		if tile_pos.x == empty_position.x:  # Same column
			var start_y = min(tile_pos.y, empty_position.y)
			var end_y = max(tile_pos.y, empty_position.y)
			for y in range(start_y, end_y + 1):
				highlight_tile_at(Vector2(tile_pos.x, y))
		else:  # Same row
			var start_x = min(tile_pos.x, empty_position.x)
			var end_x = max(tile_pos.x, empty_position.x)
			for x in range(start_x, end_x + 1):
				highlight_tile_at(Vector2(x, tile_pos.y))

func highlight_tile_at(pos: Vector2):
	for child in get_children():
		if child is Tile and child.grid_position == pos:
			child.set_highlight(true)

func clear_highlights():
	for child in get_children():
		if child is Tile:
			child.set_highlight(false)

func shuffle_tiles():
	for child in get_children():
		if child is Tile:
			child.queue_free()
	initialize_grid()
	setup_tiles()
	game_won = false
