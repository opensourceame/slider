extends Node2D

@onready var tile_scene   = preload("res://scenes/Tile.tscn")
@onready var world        = $World
@onready var hud          = $HUD

#var grid_size = Vector2i(4, 6)
var grid_size = Vector2(2,3)
var source_image: ImageTexture
var image_pieces: Array[Texture2D] = []
var tile_size = 150
var tile_gap = 5
var tiles = []
var empty_position : Vector2i
var game_won = false
var normal_style: StyleBox
var highlight_style: StyleBox
var moves : int = 0

func _ready():
	empty_position = Vector2i(grid_size.x - 1, grid_size.y - 1)
	load_and_split_image()
	create_styles()
	initialize_grid()
	#randomize_grid()
	setup_tiles()

	print("READY")
	
func _physics_process(delta: float) -> void:
	pass
	
func load_and_split_image():
	var image = Image.load_from_file("res://images/pepper.jpg")
	if image:
		# Resize image to 400x600 (100x100 tiles in 4x6 grid)
		image.resize(grid_size.x * tile_size, grid_size.y * tile_size, Image.INTERPOLATE_LANCZOS)
		source_image = ImageTexture.create_from_image(image)
		split_image_into_pieces()
	else:
		print("Failed to load pepper.jpg")

func split_image_into_pieces():
	if not source_image:
		return
		
	var image = source_image.get_image()
	var image_size = Vector2(image.get_width(), image.get_height())
	var piece_width = image.get_width() / grid_size.x
	var piece_height = image.get_height() / grid_size.y
	
	image_pieces.clear()
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var piece_rect = Rect2i(x * piece_width, y * piece_height, piece_width, piece_height)
			var piece_image = Image.create(piece_width, piece_height, false, image.get_format())
			piece_image.blit_rect(image, piece_rect, Vector2i.ZERO)
			var piece_texture = ImageTexture.create_from_image(piece_image)
			image_pieces.append(piece_texture)
		
	print("Created ", image_pieces.size(), " image pieces")


func initialize_grid():
	var indices = []
	for i in range(grid_size.x * grid_size.y):
		indices.append(i)
	
	tiles.clear()
	for y in range(grid_size.y):
		tiles.append([])
		for x in range(grid_size.x):
			tiles[y].append(null)
	
	var index = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var t = tile_scene.instantiate()
			t.set_size(Vector2(tile_size, tile_size))
			var piece_index = y * grid_size.x + x
			if x == empty_position.x and y == empty_position.y:
				t.set_number(0)
			else:
				t.set_number(indices[piece_index] + 1)
				if piece_index < image_pieces.size():
					t.set_texture(image_pieces[piece_index])
			tiles[y][x] = t
	
func randomize_grid():
	var all_tiles = []
	
	# Collect all tiles except the empty one
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if not (x == empty_position.x and y == empty_position.y):
				all_tiles.append(tiles[y][x])
	
	# Shuffle the tiles
	all_tiles.shuffle()
	
	# Redistribute tiles randomly
	var tile_index = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if x == empty_position.x and y == empty_position.y:
				continue
			tiles[y][x] = all_tiles[tile_index]
			tile_index += 1

func setup_tiles():
	var spacing = tile_gap
	var start_x = 0
	var start_y = 0
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = tiles[y][x]
			if tiles[y][x].number == 0:
				continue
			
			#var tile = tile_scene.instantiate()
			tile.position = Vector2(
				start_x + x * (tile_size + spacing),
				start_y + y * (tile_size + spacing)
			)
			tile.grid_position = Vector2i(x, y)
			world.add_child(tile)

func _on_tile_pressed(tile):
	if game_won:
		return
	
	print("clicked on ", tile.grid_position)
	print("space at   ", empty_position)
	
	var tile_pos = tile.grid_position
	if in_line_with_empty(tile):
		move_tiles_to_empty(tile)

func check_win():
	var expected = 1
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var t = tiles[y][x]
			#if t.number == 0:
				#continue
			if y == grid_size.y - 1 and x == grid_size.x - 1:
				expected = 0
			print("expected ", expected, " got ", t.number)
			if t.number != expected:
				return false
			expected += 1
	print("COMPLETE")
	return true

func check_win_after_move():
	if check_win():
		game_won = true
		print("You won!")

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
	
	# Early exit if not in line with empty
	if not in_line_with_empty(hovered_tile):
		return
	
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

func highlight_tile_at(pos: Vector2i):
	for child in world.get_children():
		if child is Tile and child.grid_position == pos:
			child.set_highlight(true)

func clear_highlights():
	for child in world.get_children():
		if child is Tile:
			child.set_highlight(false)

func in_line_with_empty(tile: Tile) -> bool:
	var tile_pos = tile.grid_position
	
	# Check if same row as empty
	if tile_pos.y == empty_position.y:
		return true
	
	# Check if same column as empty
	if tile_pos.x == empty_position.x:
		return true
	
	return false

func slide_tile(tile: Tile, x_dir: int, y_dir: int):
	var tile_pos = tile.grid_position
	var target_pos = tile_pos + Vector2i(x_dir, y_dir)
	
	# Check if target position is within bounds
	if target_pos.x < 0 or target_pos.x >= grid_size.x or target_pos.y < 0 or target_pos.y >= grid_size.y:
		return
	
	# Check if target position is the empty space
	if target_pos == empty_position:
		#swap_with_empty(tile_pos)
		
		var spacing = tile_gap
		var start_x = 0
		var start_y = 0
		
		var target_position = Vector2(
			start_x + empty_position.x * (tile_size + spacing),
			start_y + empty_position.y * (tile_size + spacing)
		)
		
		# Create sliding animation
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUART)
		tween.tween_property(tile, "position", target_position, 0.5)
		
		tile.grid_position = empty_position
		empty_position = tile_pos
		tiles[tile_pos.y][tile_pos.x] = Tile.BLANK()
		tiles[empty_position.y][empty_position.x] = tile
		# Check win condition after animation completes
		tween.tween_callback(check_win_after_move)

func move_tiles_to_empty(clicked_tile: Tile):
	var tile_pos = clicked_tile.grid_position
	
	# Early exit if not in line with empty
	if not in_line_with_empty(clicked_tile):
		return
	
	# Move tiles between clicked tile and empty space
	if tile_pos.x == empty_position.x:  # Same column
		var start_y = min(tile_pos.y, empty_position.y)
		var end_y = max(tile_pos.y, empty_position.y)
		# Move in reverse order (closest to empty first)
		if tile_pos.y < empty_position.y:  # Clicked tile is above empty
			for y in range(end_y - 1, start_y - 1, -1):
				var tile_to_move = get_tile_at(Vector2(tile_pos.x, y))
				if tile_to_move:
					slide_tile(tile_to_move, 0, 1)
		else:  # Clicked tile is below empty
			for y in range(start_y + 1, end_y + 1):
				var tile_to_move = get_tile_at(Vector2(tile_pos.x, y))
				if tile_to_move:
					slide_tile(tile_to_move, 0, -1)
	else:  # Same row
		var start_x = min(tile_pos.x, empty_position.x)
		var end_x = max(tile_pos.x, empty_position.x)
		# Move in reverse order (closest to empty first)
		if tile_pos.x < empty_position.x:  # Clicked tile is left of empty
			for x in range(end_x - 1, start_x - 1, -1):
				var tile_to_move = get_tile_at(Vector2(x, tile_pos.y))
				if tile_to_move:
					slide_tile(tile_to_move, 1, 0)
		else:  # Clicked tile is right of empty
			for x in range(start_x + 1, end_x + 1):
				var tile_to_move = get_tile_at(Vector2(x, tile_pos.y))
				if tile_to_move:
					slide_tile(tile_to_move, -1, 0)

	moves += 1
	
	update_hud()
	
func update_hud():
	$MovesLabel.text = str(moves) + " moves played"
	
func get_tile_at(pos: Vector2i) -> Tile:
	for child in world.get_children():
		if child is Tile and child.grid_position == pos:
			return child
	return null

func slide_row(row_index: int, direction: int):
	if row_index < 0 or row_index >= grid_size.y:
		return
	
	# Get all tiles in the row
	var row_tiles = []
	for x in range(grid_size.x):
		var tile = tiles[row_index][x]
		if tile:
			row_tiles.append(tile)
	
	if row_tiles.size() == 0:
		return
	
	# Calculate new positions with wrapping
	for i in range(row_tiles.size()):
		var tile = row_tiles[i]
		var current_x = tile.grid_position.x
		var new_x
		
		if direction > 0:  # Slide right
			new_x = (current_x + 1) % grid_size.x
		else:  # Slide left
			new_x = (current_x - 1 + grid_size.x) % grid_size.x
		
		# Update grid positions
		tile.grid_position = Vector2i(new_x, row_index)
		tiles[row_index][new_x] = tile
	
	# Calculate new visual positions with spacing
	var spacing = 2
	var start_x = 0
	var start_y = 0
	
	for tile in row_tiles:
		var new_pos = Vector2(
			start_x + tile.grid_position.x * (tile_size + spacing),
			start_y + tile.grid_position.y * (tile_size + spacing)
		)
		
		# Create sliding animation
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUART)
		tween.tween_property(tile, "position", new_pos, 0.3)
	
	# Check if empty space moved and update
	for x in range(grid_size.x):
		if tiles[row_index][x].number == 0:
			empty_position = Vector2i(x, row_index)
			break

func shuffle_tiles():
	for child in get_children():
		if child is Tile:
			child.queue_free()
	initialize_grid()
	setup_tiles()
	game_won = false
