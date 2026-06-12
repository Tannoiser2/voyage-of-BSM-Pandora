extends Node

var paragraphs: Dictionary = {}
var interstellar: Dictionary = {}
var tables: Dictionary = {}

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	paragraphs = _load_json("res://data/paragrafi_it.json")
	interstellar = _load_json("res://data/interstellar.json")
	tables = _load_json("res://data/tables.json")

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open: " + path)
		return {}
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result is Dictionary:
		return result
	push_error("JSON parse failed: " + path)
	return {}

func get_paragraph(num: int) -> Dictionary:
	var key := "%03d" % num
	return paragraphs.get(key, {"it": "[Paragrafo %s non trovato]" % key, "en": ""})

func get_paragraph_text(num: int) -> String:
	return get_paragraph(num).get("it", "")

func get_planet_paragraph(planet_name: String, tour_length: int) -> int:
	var systems: Dictionary = interstellar.get("star_systems", {})
	for sys_name in systems:
		if sys_name == planet_name:
			var sys: Dictionary = systems[sys_name]
			var tour_key := str(tour_length)
			var para_str: String = sys.get("planet_para", {}).get(tour_key, "")
			if para_str.is_empty():
				return 0
			return para_str.to_int()
	return 0

func get_star_system_data(sys_name: String) -> Dictionary:
	return interstellar.get("star_systems", {}).get(sys_name, {})

func get_adjacency(hex_id: int) -> Array:
	var adj: Dictionary = interstellar.get("adjacency", {})
	return adj.get(str(hex_id), [])

func get_hex_distance(from_hex: int, to_hex: int) -> int:
	# BFS
	var visited := {from_hex: 0}
	var queue := [from_hex]
	while queue.size() > 0:
		var current: int = queue.pop_front()
		if current == to_hex:
			return visited[current]
		for nb in get_adjacency(current):
			var nb_int: int = nb if nb is int else int(nb)
			if nb_int not in visited:
				visited[nb_int] = visited[current] + 1
				queue.append(nb_int)
	return 99  # not reachable

func get_planet_for_hex(hex_id: int) -> String:
	var systems: Dictionary = interstellar.get("star_systems", {})
	for sys_name in systems:
		if systems[sys_name].get("hex", -1) == hex_id:
			return sys_name
	return ""

func get_exploration_paragraph(terrain: String, die: int) -> int:
	var matrix: Dictionary = tables.get("exploration_matrix", {})
	var row: Array = matrix.get(terrain, [])
	if row.size() >= die:
		return row[die - 1].to_int()
	return 146

func get_combat_result(differential: int) -> String:
	var clamped := clampi(differential, -7, 7)
	var results: Dictionary = tables.get("combat_results", {})
	return results.get(str(clamped), "EX")

func get_interstellar_event_para(die: int) -> int:
	var events: Dictionary = tables.get("interstellar_events", {})
	var val = events.get(str(die), null)
	if val == null or val == "":
		return 0
	return str(val).to_int()
