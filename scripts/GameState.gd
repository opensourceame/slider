extends Node

var grid_size: Vector2i = Vector2i(3, 5)

func set_grid_size(size: Vector2i):
	grid_size = size

func get_grid_size() -> Vector2i:
	return grid_size
