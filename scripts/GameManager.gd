extends Node2D

@onready var tile_scene   = preload("res://scenes/Tile.tscn")
@onready var world        = $World
@onready var board        = $World/Board
@onready var buttons      = $World/Board/Buttons
@onready var hud          = $HUD

enum State { PLAYING, WON }
const BOARD_MARGIN=40 # pixels
 
var grid_size = Vector2i(4, 6)
#var grid_size = Vector2i(2,3)
var source_image: ImageTexture
var image_pieces: Array[Texture2D] = []
var tile_size = 120
var tile_gap = 3
var base_tile_size = 120
var calculated_tile_size = 120
var tiles = []
var empty_position : Vector2i
var game_won = false
var normal_style: StyleBox
var highlight_style: StyleBox
var moves : int = 0
var column_buttons = []
var row_buttons    = []
var current_state : int = State.PLAYING

func _ready():
	empty_position = Vector2i(grid_size.x - 1, grid_size.y - 1)
	
	# Calculate tile size to fit viewport
	calculate_tile_size()
	
	# Connect viewport resize signal
	get_viewport().size_changed.connect(_on_viewport_resized)
	
	# Test resource loading
	print("Testing resource paths:")
	print("Image exists: ", FileAccess.file_exists("res://images/pepper.jpg"))
	print("Image import exists: ", FileAccess.file_exists("res://images/pepper.jpg.import"))
	print("Calculated tile size: ", calculated_tile_size)
	
	load_and_split_image()
	create_styles()
	initialize_grid()
	#randomize_grid()
	setup_tiles()

	print("READY")

func _on_viewport_resized():
	print("Viewport resized, recalculating tile size...")
	calculate_tile_size()
	
	# Reload and split image with new size
	load_and_split_image()
	
	# Reinitialize grid with new tile sizes
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = tiles[y][x]
			if tile:
				tile.set_size(Vector2(calculated_tile_size, calculated_tile_size))
				var piece_index = y * grid_size.x + x
				if piece_index < image_pieces.size():
					tile.set_texture(image_pieces[piece_index])
	
	# Reposition all tiles
	setup_tiles()
	
func calculate_tile_size():
	# Get viewport dimensions
	var viewport_size = get_viewport().get_visible_rect().size
	print("Viewport size: ", viewport_size)
	
	# Calculate available space (leave some margin for buttons and UI)
	var margin = BOARD_MARGIN  # pixels margin on each side
	var available_width = viewport_size.x - (margin * 2)
	var available_height = viewport_size.y - (margin * 2)
	
	# Calculate tile size based on grid
	var tile_width  = available_width / (grid_size.x + 2)
	var tile_height = tile_width
	#var tile_height = available_height / grid_size.y
	
	# Use the smaller dimension to ensure tiles fit
	var max_tile_size = min(tile_width, tile_height)
	
	# Ensure minimum size for usability
	max_tile_size = max(max_tile_size, 60)
	
	# Apply calculated size
	calculated_tile_size = int(max_tile_size)
	tile_size = calculated_tile_size
	
	print("Available space: ", available_width, "x", available_height)
	print("Tile dimensions calculated: ", tile_width, "x", tile_height)
	print("Final tile size: ", tile_size)
	
func _physics_process(delta: float) -> void:
	pass
	
func load_and_split_image():
	print("Attempting to load image from: res://images/pepper.jpg")
	
	# Check if file exists
	if not FileAccess.file_exists("res://images/pepper.jpg"):
		print("ERROR: Image file does not exist at res://images/pepper.jpg")
		return
	
	# Try multiple methods for export compatibility
	var image_path = "res://images/pepper.jpg"
	var image: Image = null
	
	# Method 1: Direct Image.load_from_file (most reliable)
	print("Method 1: Loading image directly from: ", image_path)
	image = Image.load_from_file(image_path)
	if image:
		print("✓ Image loaded directly, size: ", image.get_size())
	else:
		print("✗ Direct load failed, trying preload method...")
		
		# Method 2: Preload and convert
		var preloaded = load(image_path)
		if preloaded:
			print("✓ Image preloaded as: ", typeof(preloaded), " content: ", preloaded)
			# Try to get Image from any texture type
			if preloaded is ImageTexture:
				print("✓ Got ImageTexture, extracting image...")
				image = preloaded.get_image()
			elif preloaded is CompressedTexture2D:
				print("✓ Got CompressedTexture2D, converting...")
				# For compressed textures, try to extract via buffer
				image = Image.new()
				if not image.load_jpg_from_buffer(preloaded.get_data()):
					print("✗ Buffer conversion failed, trying direct file access...")
					image = Image.load_from_file("res://images/pepper.jpg")
			else:
				print("✗ Unknown texture type, trying direct file...")
				image = Image.load_from_file("res://images/pepper.jpg")
		else:
			print("✗ Preload failed, trying direct file access...")
			image = Image.load_from_file("res://images/pepper.jpg")
	
	# Method 3: Try Resources directory path for macOS exports
	if not image:
		print("✗ All methods failed, trying Resources directory path...")
		var resources_path = "res://pepper.jpg"  # In exports, images might be in Resources root
		image = Image.load_from_file(resources_path)
		if image:
			print("✓ Image loaded from Resources path, size: ", image.get_size())
	
	if not image:
		print("ERROR: Could not load image with any method")
		return
	
	# Resize image to match grid dimensions with calculated tile size
	var target_width = grid_size.x * calculated_tile_size
	var target_height = grid_size.y * calculated_tile_size
	print("Original size: ", image.get_size(), "-> Resizing to: ", target_width, "x", target_height)
	image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	print("After resize: ", image.get_size())
	
	# Create source texture
	source_image = ImageTexture.create_from_image(image)
	print("✓ Source image texture created, size: ", source_image.get_size())
	split_image_into_pieces()

func split_image_into_pieces():
	if not source_image:
		print("ERROR: No source image available, creating fallback colored tiles")
		create_fallback_tiles()
		return
		
	var image = source_image.get_image()
	if not image:
		print("ERROR: Could not get image from texture, creating fallback colored tiles")
		create_fallback_tiles()
		return
		
	var image_size = Vector2(image.get_width(), image.get_height())
	print("Source image size: ", image_size)
	var piece_width = image.get_width() / grid_size.x
	var piece_height = image.get_height() / grid_size.y
	print("Piece dimensions: ", piece_width, "x", piece_height)
	
	image_pieces.clear()
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var piece_rect = Rect2i(x * piece_width, y * piece_height, piece_width, piece_height)
			var piece_image = Image.create(piece_width, piece_height, false, image.get_format())
			piece_image.blit_rect(image, piece_rect, Vector2i.ZERO)
			var piece_texture = ImageTexture.create_from_image(piece_image)
			image_pieces.append(piece_texture)
			print("Created piece [", y, ",", x, "] texture: ", piece_texture.get_size())
		
	print("Created ", image_pieces.size(), " image pieces")

func create_fallback_tiles():
	print("Creating colored fallback tiles...")
	image_pieces.clear()
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var piece_texture = ImageTexture.new()
			var piece_image = Image.create(calculated_tile_size, calculated_tile_size, false, Image.FORMAT_RGB8)
			
			# Create different colors for visual variety
			var hue = (y * grid_size.x + x) * 360.0 / (grid_size.x * grid_size.y)
			var color = Color.from_hsv(hue, 0.7, 0.8)
			piece_image.fill(color)
			
			piece_texture.set_image(piece_image)
			image_pieces.append(piece_texture)
			print("Created fallback tile [", y, ",", x, "] with color: ", color)
	
	print("Created ", image_pieces.size(), " fallback tiles")


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
			t.set_size(Vector2(calculated_tile_size, calculated_tile_size))
			var piece_index = y * grid_size.x + x
			if x == empty_position.x and y == empty_position.y:
				t.set_number(0)
			else:
				t.set_number(indices[piece_index] + 1)
				if piece_index < image_pieces.size():
					t.set_texture(image_pieces[piece_index])
			tiles[y][x] = t
	
func randomize_grid():	
	# Create a list of all non-empty tiles for shuffling
	var all_tiles = []
	for row in tiles:
		for tile in row:
			#if tile.is_blank():
				#continue
			all_tiles.append(tile)
	
	# Shuffle the tiles to get new random positions
	all_tiles.shuffle()
	
	tiles = []
	
	for y in range(grid_size.y):
		var row = []
		for x in range(grid_size.x):
			var tile = all_tiles.pop_front()
			if not tile:
				continue
			row.append(tile)
			tile.grid_position = Vector2i(x, y)
			if tile.is_blank():
				empty_position = tile.grid_position
			animate_tile_move(tile)
		tiles.append(row)
	
	
	print("tiles randomized")		

func get_grid_offset() -> Vector2:
	var button_size = tile_size
	var button_spacing = 10
	return Vector2(button_size + button_spacing, 0)

func create_row_buttons():
	var spacing = tile_gap
	var button_size = calculated_tile_size
	var button_spacing = 10
	var grid_offset = get_grid_offset()
	var start_x = grid_offset.x
	var start_y = 0
	
	for y in range(grid_size.y):
		# Create left arrow button at start of each row
		var left_button = Button.new()
		left_button.text = "←"
		left_button.custom_minimum_size = Vector2(button_size, button_size)
		left_button.add_theme_font_size_override("font_size", 40)
		
		# Position left button at the start (uses absolute position, not start_x)
		var left_button_x = 0  # Position at screen left edge
		var left_button_y = start_y + y * (tile_size + spacing) + (tile_size - button_size) / 2
		
		left_button.position = Vector2(left_button_x, left_button_y)
		
		# Connect left button press to slide_row function (direction -1 for left)
		left_button.pressed.connect(func(): slide_row(y, -1))
		
		# Add left button to world
		buttons.add_child(left_button)
		
		# Create right arrow button at end of each row
		var right_button = Button.new()
		right_button.text = "→"
		right_button.custom_minimum_size = Vector2(button_size, button_size)
		right_button.add_theme_font_size_override("font_size", 40)
		
		# Position right button at end of row
		var right_button_x = start_x + grid_size.x * (tile_size + spacing) + button_spacing
		var right_button_y = start_y + y * (tile_size + spacing) + (tile_size - button_size) / 2
		
		right_button.position = Vector2(right_button_x, right_button_y)
		
		# Connect right button press to slide_row function (direction 1 for right)
		right_button.pressed.connect(func(): slide_row(y, 1))
		
		# Add right button to world
		buttons.add_child(right_button)

func create_column_buttons():
	var spacing = tile_gap
	var button_size = calculated_tile_size
	var button_spacing = 10
	var grid_offset = get_grid_offset()
	var start_x = grid_offset.x
	var start_y = 0
	
	for x in range(grid_size.x):
		# Create up arrow button above each column
		var up_button = Button.new()
		up_button.text = "↑"
		up_button.custom_minimum_size = Vector2(button_size, button_size)
		up_button.add_theme_font_size_override("font_size", 40)
		
		# Position up button above the column
		var up_button_x = start_x + x * (tile_size + spacing)
		var up_button_y = -button_size - button_spacing  # Position above grid
		
		up_button.position = Vector2(up_button_x, up_button_y)
		
		# Connect up button press to slide_column function (direction -1 for up)
		up_button.pressed.connect(func(): slide_column(x, -1))
		
		# Add up button to world
		buttons.add_child(up_button)
		
		# Create down arrow button below each column
		var down_button = Button.new()
		down_button.text = "↓"
		down_button.custom_minimum_size = Vector2(button_size, button_size)
		down_button.add_theme_font_size_override("font_size", 40)
		
		# Position down button below the column
		var down_button_x = start_x + x * (tile_size + spacing)
		var down_button_y = start_y + grid_size.y * (tile_size + spacing) + button_spacing
		
		down_button.position = Vector2(down_button_x, down_button_y)
		
		# Connect down button press to slide_column function (direction 1 for down)
		down_button.pressed.connect(func(): slide_column(x, 1))
		
		# Add down button to world
		buttons.add_child(down_button)

func setup_tiles():
	# Clean up existing tiles and buttons first
	for child in board.get_children():
		if child is Tile or child is Button:
			child.queue_free()
	
	var spacing = tile_gap
	var grid_offset = get_grid_offset()
	var start_x = grid_offset.x
	var start_y = 0
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var tile = tiles[y][x]
			if tiles[y][x].is_blank():
				continue
			
			#var tile = tile_scene.instantiate()
			tile.position = Vector2(
				start_x + x * (tile_size + spacing),
				start_y + y * (tile_size + spacing)
			)
			tile.grid_position = Vector2i(x, y)
			board.add_child(tile)
	
	# Create row and column buttons after tiles
	create_row_buttons()
	create_column_buttons()

func _on_tile_pressed(tile):
	if game_won:
		return
	
	print("clicked on ", tile.grid_position)
	print("space at   ", empty_position)
	
	var tile_pos = tile.grid_position
	if in_line_with_empty(tile):
		move_tiles_to_empty(tile)

func check_win():
	#return
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
	
	for button in buttons.get_children():
		button.queue_free()
	
	current_state = State.WON
		
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
	if current_state == State.WON:
		return 
		
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
		var end_x   = max(tile_pos.x, empty_position.x)
		for x in range(start_x, end_x + 1):
			highlight_tile_at(Vector2(x, tile_pos.y))

func highlight_tile_at(pos: Vector2i):
	for child in board.get_children():
		if child is Tile and child.grid_position == pos:
			child.set_highlight(true)

func clear_highlights():
	for child in board.get_children():
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
	var tile_pos   = tile.grid_position
	var target_pos = tile_pos + Vector2i(x_dir, y_dir)
	
	# Check if target position is within bounds
	if target_pos.x < 0 or target_pos.x >= grid_size.x or target_pos.y < 0 or target_pos.y >= grid_size.y:
		return
	
	assert(target_pos == empty_position)
	
	tile.grid_position = empty_position
	empty_position = tile_pos
	tiles[tile_pos.y][tile_pos.x] = Tile.BLANK()
	tiles[tile.grid_position.y][tile.grid_position.x] = tile

	animate_tile_move(tile)
	
	
func animate_tile_move(tile):
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.tween_property(tile, "position", tile_position(tile), 0.5)

	tween.tween_callback(check_win_after_move)

	#$Click.play(0.1)
	
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
					await get_tree().create_timer(0.1).timeout

		else:  # Clicked tile is below empty
			for y in range(start_y + 1, end_y + 1):
				var tile_to_move = get_tile_at(Vector2(tile_pos.x, y))
				if tile_to_move:
					slide_tile(tile_to_move, 0, -1)
					await get_tree().create_timer(0.1).timeout

	else:  # Same row
		var start_x = min(tile_pos.x, empty_position.x)
		var end_x = max(tile_pos.x, empty_position.x)
		# Move in reverse order (closest to empty first)
		if tile_pos.x < empty_position.x:  # Clicked tile is left of empty
			for x in range(end_x - 1, start_x - 1, -1):
				var tile_to_move = get_tile_at(Vector2(x, tile_pos.y))
				if tile_to_move:
					await get_tree().create_timer(0.1).timeout

					slide_tile(tile_to_move, 1, 0)
		else:  # Clicked tile is right of empty
			for x in range(start_x + 1, end_x + 1):
				var tile_to_move = get_tile_at(Vector2(x, tile_pos.y))
				if tile_to_move:
					await get_tree().create_timer(0.1).timeout

					slide_tile(tile_to_move, -1, 0)
					

	update_moves()
	
func update_moves():
	moves += 1
	
	$MovesLabel.text = str(moves) + " moves played"
	
	check_win()
	
func get_tile_at(pos: Vector2i) -> Tile:
	for child in board.get_children():
		if child is Tile and child.grid_position == pos:
			return child
	return null

func tile_position(tile):
	var grid_offset = get_grid_offset()
	return Vector2(
		grid_offset.x + tile.grid_position.x * (tile_size + tile_gap),
		grid_offset.y + tile.grid_position.y * (tile_size + tile_gap),

	)
func slide_row(row_index: int, direction: int):
	assert(row_index >= 0 and row_index <= grid_size.y)
	
	update_moves()

	var row_tiles = tiles[row_index]
	
	assert(row_tiles.size() > 0)

	print(row_tiles)	
	if direction > 0:
		var t = row_tiles.pop_back()
		row_tiles.push_front(t)
	else:
		var t = row_tiles.pop_front()
		row_tiles.push_back(t)
	print(row_tiles)
	
	for i in range(row_tiles.size()):
		var tile = row_tiles[i]
		tile.grid_position = Vector2i(i, row_index)
		if tile.number == 0:
			empty_position = tile.grid_position
	
		animate_tile_move(tile)	

func slide_column(col_index: int, direction: int):
	assert(col_index >= 0 and col_index <= grid_size.x)
	
	update_moves()

	# Get all tiles in the column
	var column_tiles = []
	for y in range(grid_size.y):
		var tile = tiles[y][col_index]
		if tile:
			column_tiles.append(tile)
	
	assert(column_tiles.size() > 0)
	
	print("Column ", col_index, " before slide: ", column_tiles)
	
	# Slide tiles in column with wrapping
	if direction > 0:  # Slide down
		var t = column_tiles.pop_back()  # Remove from bottom
		column_tiles.push_front(t)  # Add to top
	else:  # Slide up
		var t = column_tiles.pop_front()  # Remove from top
		column_tiles.push_back(t)  # Add to bottom
	
	print("Column ", col_index, " after slide: ", column_tiles)
	
	for y in range(grid_size.y):
		var tile = column_tiles.pop_front()
		tiles[y][col_index] = tile
		tile.grid_position = Vector2i(col_index, y)
		if tile.number == 0:
			empty_position = tile.grid_position
		
		animate_tile_move(tile)
	# Update grid positions and animate tiles
	#for i in range(column_tiles.size()):
		#var tile = column_tiles[i]
		#tile.grid_position = Vector2i(col_index, i)
		#if tile.number == 0:
			#empty_position = tile.grid_position
		#
		

func shuffle_tiles():
	# Clean up tiles and buttons
	for child in board.get_children():
		if child is Tile or child is Button:
			child.queue_free()
	initialize_grid()
	setup_tiles()
	game_won = false
