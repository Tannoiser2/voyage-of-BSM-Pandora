extends Node

# Tabella di Valutazione (Carta 8.4): 2 dadi +/- modificatore -> valore d'attributo.
# Il totale 12 ("*") si risolve con un ulteriore tiro di dado (gestito a parte).
const CREATURE_RATING_TABLE := {2: 1, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 8: 6, 9: 7, 10: 8, 11: 9}

var paragraphs: Dictionary = {}
var interstellar: Dictionary = {}
var tables: Dictionary = {}
var creatures: Dictionary = {}
var environ_maps: Dictionary = {}
var units: Dictionary = {}
var terrain: Dictionary = {}
var paragraph_logic: Dictionary = {}
var paragraph_choices_override: Dictionary = {}
var expedition_encounters: Dictionary = {}
var artifacts: Dictionary = {}
var intel_checks: Dictionary = {}

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	paragraphs = _load_json("res://data/paragrafi_it.json")
	interstellar = _load_json("res://data/interstellar.json")
	tables = _load_json("res://data/tables.json")
	creatures = _load_json("res://data/creatures.json")
	environ_maps = _load_json("res://data/environ_maps.json")
	units = _load_json("res://data/units.json")
	terrain = _load_json("res://data/terrain.json")
	paragraph_logic = _load_json("res://data/paragraph_logic.json")
	paragraph_choices_override = _load_json("res://data/paragraph_choices.json")
	expedition_encounters = _load_json("res://data/expedition_encounters.json")
	artifacts = _load_json("res://data/artifacts.json")
	intel_checks = _load_json("res://data/intel_checks.json")

# Procedura di check Intelligenza (3.3) per un paragrafo. {} se assente.
func get_intel_check(para: int) -> Dictionary:
	return intel_checks.get("%03d" % para, {})

func has_intel_check(para: int) -> bool:
	return intel_checks.has("%03d" % para)

# Regole degli snodi «Incontro di spedizione» (regola 6.5). [] se l'id non è uno snodo.
func get_expedition_encounter(para: int) -> Array:
	return expedition_encounters.get("%03d" % para, [])

# Dati di un artefatto per paragrafo di acquisizione (regole 2.6/9.1). {} se non lo è.
func get_artifact(para: int) -> Dictionary:
	return artifacts.get("%03d" % para, {})

func is_artifact_paragraph(para: int) -> bool:
	return artifacts.has("%03d" % para)

# Regole di ramo codificate per un paragrafo d'incontro (8.2/8.5). [] se assenti.
func get_paragraph_logic(para: int) -> Array:
	return paragraph_logic.get("%03d" % para, [])

# Mappa una classe di terreno campionata (Open/Rough/...) al tipo reale (Flat/Hill/...)
func terrain_real(terrain_class: String) -> String:
	return terrain.get("class_map", {}).get(terrain_class, "Flat")

# Effetti del terreno (Carta 6.6) per una classe campionata.
func terrain_effect(terrain_class: String) -> Dictionary:
	var real := terrain_real(terrain_class)
	return terrain.get("effects", {}).get(real, {"enter_foot": 1, "explore": 2, "supply": 0, "prohibited": false})

func terrain_enter_cost(terrain_class: String) -> int:
	return int(terrain_effect(terrain_class).get("enter_foot", 1))

func terrain_explore_cost(terrain_class: String) -> int:
	return int(terrain_effect(terrain_class).get("explore", 2))

func terrain_it(terrain_class: String) -> String:
	return terrain.get("terrain_it", {}).get(terrain_real(terrain_class), terrain_real(terrain_class))

# Statistiche di un personaggio della Pandora (regola 2.5 / 5.2)
func get_character(key: String) -> Dictionary:
	return units.get("characters", {}).get(key, {})

func get_character_keys() -> Array:
	return units.get("characters", {}).keys()

func get_bot_keys() -> Array:
	return units.get("bots", {}).keys()

func get_tool_keys() -> Array:
	return units.get("tools", {}).keys()

# Restituisce i dati di un'unità qualsiasi (personaggio, robot o strumento).
func get_unit(key: String) -> Dictionary:
	var u: Dictionary = units.get("characters", {}).get(key, {})
	if u.is_empty():
		u = units.get("bots", {}).get(key, {})
	if u.is_empty():
		u = units.get("tools", {}).get(key, {})
	return u

# Capacità di porto dello shuttle in base alla gravità del pianeta (Carta 5.8)
func shuttle_capacity_for(gravity: String) -> int:
	return int(units.get("shuttle_capacity", {}).get(gravity, 80))

# Capacità di Porto del Rover per gravità (5.8). 0 = il rover non è utilizzabile
# (gravità opprimente, nota 2 della Carta Capacità di Porto).
func rover_capacity_for(gravity: String) -> int:
	return int(units.get("rover_capacity", {}).get(gravity, 30))

# Modificatore di gravità al Valore di Porto di personaggi/bot/strumenti (5.8):
# Quasi assenza peso ×2 · Leggera +2 · Tipo Terra = P · Pesante −2 · Opprimente ½P.
func port_for_gravity(base: int, gravity: String) -> int:
	match gravity:
		"Near weightless":
			return base * 2
		"Light":
			return base + 2
		"Heavy":
			return base - 2
		"Oppressive":
			return int(floor(base / 2.0))
		_:
			return base   # "Earth like" e default: P invariato

func gravity_it(gravity: String) -> String:
	return units.get("gravity_it", {}).get(gravity, gravity)

func atmosphere_it(atmosphere: String) -> String:
	return units.get("atmosphere_it", {}).get(atmosphere, atmosphere)

func atmosphere_note(atmosphere: String) -> String:
	return units.get("atmosphere_note", {}).get(atmosphere, "")

func gravity_list() -> Array:
	return units.get("gravity_it", {}).keys()

func max_supply() -> int:
	return int(units.get("max_supply", 20))

# Attributi del pianeta in orbita (gravità, atmosfera, idro, geologia, lsv, atterraggi)
func get_planet_attributes(system: String, tour_length: int) -> Dictionary:
	var sys := get_star_system_data(system)
	var para_str: String = sys.get("planet_para", {}).get(str(tour_length), "")
	if para_str.is_empty():
		return {}
	return get_paragraph(para_str.to_int()).get("planet", {})

# Mappa un esagono globale (es. "1502") all'environ e all'esagono locale che lo contengono.
func find_environ_hex(real_id: String) -> Dictionary:
	for env_id in environ_maps:
		var hexes: Dictionary = environ_maps[env_id].get("hexes", {})
		for local_id in hexes:
			if hexes[local_id].get("real", "") == real_id:
				return {"env": int(env_id), "local": int(local_id)}
	return {}

# Dati della mappa di un environ (1..8): immagine reale + geometria esagoni
func get_environ(env_id: int) -> Dictionary:
	return environ_maps.get(str(env_id), {})

func environ_count() -> int:
	return environ_maps.size()

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

# Clima dell'area dichiarato nel testo del paragrafo (5.1): «Il clima è X».
# Restituisce "artico"|"temperato"|"tropicale"|"sahariano" oppure "" se assente.
func paragraph_climate(num: int) -> String:
	var re := RegEx.new()
	re.compile("(?i)clima.{1,6}?(artico|temperato|tropicale|sahariano)")
	var m := re.search(get_paragraph_text(num))
	return m.get_string(1).to_lower() if m else ""

# Nebbia nell'environ dichiarata dal paragrafo d'atterraggio (Carta 6.6, nota):
# «Una (fitta/vaporosa) nebbia copre/avvolge la zona» → ogni esagono costa 1 ora in
# più per entrare e 2 in più per esplorare (¶136/¶139/¶141).
func paragraph_has_fog(num: int) -> bool:
	var re := RegEx.new()
	re.compile("(?i)nebbia")
	return re.search(get_paragraph_text(num)) != null

# Variazione del Valore di Supporto Vitale dichiarata nel testo di un paragrafo
# d'atterraggio (5.1): «Aggiungi uno/due … al Valore di Supporto Vitale» (o «Sottrai»).
func paragraph_lsv_delta(num: int) -> int:
	var t := get_paragraph_text(num)
	var re := RegEx.new()
	re.compile("(?i)(Aggiungi|Sottrai)\\s+(uno|due|tre|\\d+)\\s+al Valore di Supporto Vitale")
	var m := re.search(t)
	if m == null:
		return 0
	var words := {"uno": 1, "due": 2, "tre": 3}
	var n: int = words.get(m.get_string(2).to_lower(), m.get_string(2).to_int())
	return -n if m.get_string(1).to_lower() == "sottrai" else n

# Estrae le scelte/rimandi di un paragrafo (libro-gioco). Ogni rimando ¶NNN nel
# testo diventa una scelta cliccabile; l'etichetta è la frase/riga che lo contiene.
func get_paragraph_choices(num: int) -> Array:
	# Override esplicito (scelte con tiro/condizione): vedi paragraph_choices.json.
	var key := "%03d" % num
	if paragraph_choices_override.has(key):
		return paragraph_choices_override[key]
	var text := get_paragraph_text(num)
	var choices: Array = []
	var seen := {}
	# Spezza il testo in segmenti su a-capo e punti elenco, così ogni condizione
	# con un rimando diventa una scelta distinta.
	var segments := text.replace("•", "\n").split("\n", false)
	for seg in segments:
		var s: String = seg.strip_edges()
		if s.is_empty():
			continue
		var re := RegEx.new()
		re.compile("¶\\s*(\\d{1,3})")
		var matches := re.search_all(s)
		if matches.is_empty():
			continue
		# Etichetta = segmento ripulito dal marcatore e dai rimandi
		var label := s
		label = label.lstrip("* ").strip_edges()
		var cleaner := RegEx.new()
		cleaner.compile("¶\\s*\\d{1,3}")
		label = cleaner.sub(label, "", true).strip_edges()
		label = label.rstrip(":.,; ").strip_edges()
		for m in matches:
			var target := int(m.get_string(1))
			if seen.has(target):
				continue
			seen[target] = true
			var lbl := label
			if lbl.is_empty():
				lbl = "Vai al paragrafo %03d" % target
			choices.append({"para": target, "label": lbl})
	return choices

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

# Matrice di Esplorazione reale (6.4): 1° dado = colonna, 2° dado = riga → paragrafo.
func get_exploration_2d6(first_die: int, second_die: int) -> int:
	var m: Array = tables.get("exploration_2d6", [])
	var r := clampi(second_die, 1, 6) - 1
	var c := clampi(first_die, 1, 6) - 1
	if r < m.size() and c < m[r].size():
		return int(m[r][c])
	return 146

# Indice di colonna (0..8) sulla Tabella dei Risultati di Combattimento (8.6) a
# partire dal differenziale (Valore di Combattimento spedizione - creatura).
func combat_column_index(differential: int) -> int:
	if differential <= -4: return 0
	if differential <= -2: return 1   # -3, -2
	if differential == -1: return 2
	if differential == 0:  return 3
	if differential == 1:  return 4
	if differential <= 3:  return 5   # +2, +3
	if differential <= 6:  return 6   # +4..+6
	if differential <= 10: return 7   # +7..+10
	return 8                          # >= +11

# Risultato in lettere (A-E) della Tabella dei Risultati di Combattimento (8.6):
# il differenziale (più gli spostamenti di colonna del paragrafo) individua la
# colonna, il tiro di 1 dado (1-6) individua la riga. `col_shift` è in colonne a
# SINISTRA, come il linguaggio del regolamento: positivo = verso E (sfavorevole
# alla spedizione, es. sorpresa), negativo = verso A (a favore). Gli spostamenti
# oltre i bordi della tabella sono ignorati.
func combat_result(differential: int, die: int, col_shift: int = 0) -> String:
	var col := clampi(combat_column_index(differential) - col_shift, 0, 8)
	var rows: Dictionary = tables.get("combat_results", {}).get("rows", {})
	var row: Array = rows.get(str(clampi(die, 1, 6)), [])
	if col < row.size():
		return str(row[col])
	return "E"

func get_interstellar_event_para(die: int) -> int:
	var events: Dictionary = tables.get("interstellar_events", {})
	var val = events.get(str(die), null)
	if val == null or val == "":
		return 0
	return str(val).to_int()

# --- Immagini evento ---------------------------------------------------------

func get_event_image_path(para_num: int) -> String:
	# Restituisce il percorso dell'illustrazione originale del paragrafo, se esiste
	var path := "res://assets/events/Event_%03d.jpg" % para_num
	if ResourceLoader.exists(path):
		return path
	return ""

func load_event_texture(para_num: int) -> Texture2D:
	var path := get_event_image_path(para_num)
	if path.is_empty():
		return null
	return load(path) as Texture2D

# --- Creature ----------------------------------------------------------------

func get_creature(name: String) -> Dictionary:
	return creatures.get("creatures", {}).get(name, {})

func get_all_creature_names() -> Array:
	return creatures.get("creatures", {}).keys()

# Creatura il cui paragrafo d'incontro (retro del segnalino, 2.6) è dato. "" se nessuna.
func creature_for_paragraph(para: int) -> String:
	for name in creatures.get("creatures", {}):
		if int(creatures["creatures"][name].get("para", -1)) == para:
			return name
	return ""

# Valore in Punti Vittoria extra di una creatura catturata (9.1).
func creature_vp(name: String) -> int:
	return int(get_creature(name).get("vp", 0))

# Tabella di Strategia d'Incontro (8.2): dado modificato + strategia -> paragrafo esito.
func encounter_strategy_para(die: int, strategy: String) -> int:
	var d := clampi(die, -1, 8)
	var row: Dictionary = tables.get("encounter_strategy_table", {}).get(str(d), {})
	return int(row.get(strategy, 0))

func get_creature_texture(name: String) -> Texture2D:
	var data := get_creature(name)
	var img_name: String = data.get("img", "")
	if img_name.is_empty():
		return null
	var path := "res://assets/creatures/%s.png" % img_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# Valutazione di combattimento della creatura per un esagono (regola 8.4):
# 2 dadi + Modificatore di Combattimento, mappati con la Tabella di Valutazione
# (Carta 8.4) — non la somma grezza. Con totale 12 si ritira un dado.
func roll_creature_combat_rating(name: String) -> int:
	return roll_creature_combat_rating_mod(int(get_creature(name).get("combat", 0)))

# Come roll_creature_combat_rating ma con un Modificatore di Combattimento esplicito
# (es. ¶217: il Glassman vale +3 invece del +1 stampato sul segnalino).
func roll_creature_combat_rating_mod(modifier: int) -> int:
	var total := clampi(randi_range(1, 6) + randi_range(1, 6) + modifier, 2, 12)
	if total <= 11:
		return int(CREATURE_RATING_TABLE.get(total, 1))
	var d := randi_range(1, 6)
	return 9 if d <= 2 else (10 if d <= 4 else (11 if d == 5 else 12))
