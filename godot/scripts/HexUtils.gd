extends Node

# Convert hex_id (like 46 = col4 row6) to display position within the interstellar panel
# Panel display area: 480x680 pixels
# Reference: hex46 (Sol) at approximately (320, 630), hex11 (Korkran) at (80, 128)
# Grid: dx≈80, dy≈91.5, even columns offset down by dy/2

const PANEL_W := 480.0
const PANEL_H := 680.0
const HEX_DX := 80.0
const HEX_DY := 91.5
const BASE_X := 80.0   # x center of column 1
const BASE_Y := 128.0  # y center of hex11 (col1, row1) in panel coords

func hex_to_panel_pos(hex_id: int) -> Vector2:
	var col := hex_id / 10
	var row := hex_id % 10
	var x := BASE_X + (col - 1) * HEX_DX
	var y := BASE_Y + (row - 1) * HEX_DY
	if col % 2 == 0:  # even columns shift down
		y += HEX_DY / 2.0
	return Vector2(x, y)

func panel_pos_to_hex(pos: Vector2, threshold: float = 40.0) -> int:
	# Find nearest hex to a panel position
	var best_hex := -1
	var best_dist := threshold * threshold
	for col in range(1, 5):
		var max_row := 7 if col % 2 == 1 else 6
		for row in range(1, max_row + 1):
			var hx := col * 10 + row
			var hp := hex_to_panel_pos(hx)
			var d := pos.distance_squared_to(hp)
			if d < best_dist:
				best_dist = d
				best_hex = hx
	return best_hex

func hex_color(hex_id: int) -> Color:
	# Color based on content
	var sys_name := GameData.get_planet_for_hex(hex_id)
	if sys_name == "Sol":
		return Color(0.2, 0.5, 1.0)  # blue = home
	elif sys_name != "":
		return Color(1.0, 0.7, 0.1)  # gold = star system
	return Color(0.4, 0.4, 0.5)  # grey = empty hex
