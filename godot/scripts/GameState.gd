extends Node

signal phase_changed(new_phase: String)
signal state_updated
signal paragraph_request(para_num: int)
signal message_posted(msg: String)
signal encounter_started(creature_name: String)
signal encounter_ended
signal combat_resolved(result: String, detail: String)

enum Phase {
	MAIN_MENU,
	SETUP,
	INTERSTELLAR,
	ORBIT,
	EXPEDITION,
	PARAGRAPH,
	GAME_OVER
}

# Tour configuration
var tour_length: int = 20
var tour_set: String = "20"

# Tracking
var tour_months_used: int = 0
var expedition_hours: int = 0
var shuttle_supply: int = 6
var expedition_supply: int = 0
var victory_points: int = 0

# Position
var pandora_hex: int = 46
var current_system: String = "Sol"
var current_planet: String = ""

# State
var current_phase: Phase = Phase.MAIN_MENU
var current_paragraph: int = 0
var awaiting_die_roll: bool = false
var pending_die_purpose: String = ""

# Crew (simplified)
var crew: Dictionary = {
	"CO":   {"name": "Comandante",           "alive": true, "wounded": false},
	"Nav":  {"name": "Navigatore",           "alive": true, "wounded": false},
	"SO":   {"name": "Ufficiale di Sicurezza","alive": true, "wounded": false},
	"GSO":  {"name": "Ufficiale Scienze",    "alive": true, "wounded": false},
	"MedO": {"name": "Ufficiale Medico",     "alive": true, "wounded": false},
	"WO":   {"name": "Ufficiale Armi",       "alive": true, "wounded": false},
	"MntO": {"name": "Ufficiale Manutenzione","alive": true, "wounded": false}
}

var visited_systems: Array = []
var log_entries: Array = []

# Combattimento / incontri
var current_creature: String = ""
var creature_rating: int = 0          # valutazione della creatura per l'esagono (8.4)
var damage_points: int = 0            # danni accumulati dalla spedizione
var captured_creatures: Array = []    # creature catturate vive (PV extra)

# Superficie planetaria (environ) — regola 6.0
const ENVIRON_COLS := 5
const ENVIRON_ROWS := 5
var environ_grid: Dictionary = {}     # hex_id -> {"terrain": String, "explored": bool}
var expedition_pos: int = 0           # esagono attuale della spedizione (0 = non sbarcata)
var landing_hex: int = 0
signal environ_changed

func _ready() -> void:
	pass

func start_new_game(p_tour_length: int) -> void:
	tour_length = p_tour_length
	tour_set = str(tour_length)
	tour_months_used = 0
	expedition_hours = 0
	shuttle_supply = 6
	expedition_supply = 0
	victory_points = 0
	pandora_hex = 46
	current_system = "Sol"
	current_planet = ""
	visited_systems = []
	log_entries = []

	# Set initial VP based on tour length (from rules)
	match tour_length:
		10: victory_points = 10
		20: victory_points = 20
		30: victory_points = 30

	set_phase(Phase.INTERSTELLAR)
	add_log("Nuovo viaggio iniziato. Tour: %d mesi. Pandora in orbita attorno a Sol." % tour_length)

func set_phase(p: Phase) -> void:
	current_phase = p
	phase_changed.emit(phase_name(p))
	state_updated.emit()

func phase_name(p: Phase) -> String:
	match p:
		Phase.MAIN_MENU:   return "main_menu"
		Phase.SETUP:       return "setup"
		Phase.INTERSTELLAR:return "interstellar"
		Phase.ORBIT:       return "orbit"
		Phase.EXPEDITION:  return "expedition"
		Phase.PARAGRAPH:   return "paragraph"
		Phase.GAME_OVER:   return "game_over"
	return "unknown"

func add_log(msg: String) -> void:
	log_entries.append(msg)
	message_posted.emit(msg)

func months_remaining() -> int:
	return tour_length - tour_months_used

func can_move_to(hex_id: int) -> bool:
	if current_phase != Phase.INTERSTELLAR:
		return false
	var dist := GameData.get_hex_distance(pandora_hex, hex_id)
	return dist <= months_remaining()

func move_pandora_to(hex_id: int) -> void:
	if not can_move_to(hex_id):
		add_log("Non abbastanza mesi per raggiungere quel sistema.")
		return
	var cost := GameData.get_hex_distance(pandora_hex, hex_id)
	pandora_hex = hex_id
	tour_months_used += cost

	var sys_name := GameData.get_planet_for_hex(hex_id)
	if sys_name != "":
		current_system = sys_name
		add_log("Pandora arriva a %s. Mesi usati: %d/%d." % [sys_name, tour_months_used, tour_length])
		# Check for interstellar event (rule 4.2)
		pending_die_purpose = "interstellar_event"
		awaiting_die_roll = true
		message_posted.emit("Tira un dado per evento interstellare (regola 4.2).")
	else:
		current_system = ""
		add_log("Pandora si muove all'esagono %d. Mesi usati: %d/%d." % [hex_id, tour_months_used, tour_length])

	state_updated.emit()

	# Check if tour is over
	if months_remaining() <= 0:
		_end_tour()

func resolve_interstellar_event(die: int) -> void:
	var para := GameData.get_interstellar_event_para(die)
	if para > 0:
		add_log("Evento interstellare! (dado: %d) → Paragrafo %03d" % [die, para])
		show_paragraph(para)
	else:
		add_log("Nessun evento interstellare (dado: %d)." % die)
		if current_system != "" and current_system != "Sol":
			set_phase(Phase.ORBIT)

func land_on_planet(die_result: int) -> void:
	if current_phase != Phase.ORBIT:
		return
	var sys := GameData.get_star_system_data(current_system)
	var para_key := str(tour_length)
	var planet_para_str: String = sys.get("planet_para", {}).get(para_key, "")
	if planet_para_str.is_empty():
		add_log("Errore: nessun dato pianeta per questo sistema/tour.")
		return
	var planet_para := planet_para_str.to_int()
	var para_data := GameData.get_paragraph(planet_para)

	# Determine landing hex from planet card
	var planet_info: Dictionary = para_data.get("planet", {})
	var landings: Array = planet_info.get("landing", [])
	var landing_para := 114  # default
	for entry in landings:
		var dice_range: Array = entry.get("die", [])
		if die_result in dice_range:
			landing_para = entry.get("para", "114").to_int()
			break

	current_planet = current_system
	expedition_hours = 0
	expedition_supply = shuttle_supply  # bring supplies from shuttle
	shuttle_supply = 0
	reset_expedition_state()
	generate_environ(landing_para)

	add_log("Atterraggio su %s. Dado: %d → Paragrafo %03d" % [current_system, die_result, landing_para])
	set_phase(Phase.EXPEDITION)
	show_paragraph(landing_para)

func show_paragraph(para_num: int) -> void:
	current_paragraph = para_num
	set_phase(Phase.PARAGRAPH)
	paragraph_request.emit(para_num)
	state_updated.emit()

func return_to_pandora() -> void:
	# Return from expedition to orbit
	if current_phase == Phase.EXPEDITION or current_phase == Phase.PARAGRAPH:
		shuttle_supply += expedition_supply
		expedition_supply = 0
		# Assegna i PV per le creature catturate riportate sulla Pandora (8.0/9.0)
		if captured_creatures.size() > 0:
			for cname in captured_creatures:
				gain_vp(2, "Creatura catturata: %s" % cname)
			captured_creatures = []
		add_log("Ritorno alla Pandora da %s." % current_planet)
		current_planet = ""
		current_creature = ""
		set_phase(Phase.ORBIT)
		# If at Sol, go to game over
		if current_system == "Sol":
			_end_tour()

func _end_tour() -> void:
	add_log("Tour completato! Calcolo Punti Vittoria...")
	show_paragraph(232)
	set_phase(Phase.GAME_OVER)

func gain_vp(amount: int, reason: String) -> void:
	victory_points += amount
	add_log("VP +%d: %s (totale: %d)" % [amount, reason, victory_points])
	state_updated.emit()

func lose_vp(amount: int, reason: String) -> void:
	victory_points -= amount
	add_log("VP -%d: %s (totale: %d)" % [amount, reason, victory_points])
	state_updated.emit()

func add_expedition_hours(h: int) -> void:
	expedition_hours += h
	state_updated.emit()
	if expedition_hours >= 12:
		add_log("ATTENZIONE: 12+ ore di spedizione! Tornare allo shuttle!")

func use_expedition_supply(amount: int) -> bool:
	if expedition_supply >= amount:
		expedition_supply -= amount
		state_updated.emit()
		return true
	add_log("Rifornimenti insufficienti!")
	return false

func reset_expedition_state() -> void:
	current_creature = ""
	creature_rating = 0
	captured_creatures = []
	damage_points = 0
	environ_grid = {}
	expedition_pos = 0
	landing_hex = 0

# --- Superficie planetaria (environ) -----------------------------------------

func environ_hex_id(col: int, row: int) -> int:
	return col * 10 + row

func environ_neighbors(hex_id: int) -> Array:
	# Adiacenza esagonale a colonne sfalsate (come la mappa interstellare)
	var col := hex_id / 10
	var row := hex_id % 10
	var result: Array = []
	var candidates: Array = [[col, row - 1], [col, row + 1]]
	if col % 2 == 1:
		candidates += [[col - 1, row - 1], [col - 1, row], [col + 1, row - 1], [col + 1, row]]
	else:
		candidates += [[col - 1, row], [col - 1, row + 1], [col + 1, row], [col + 1, row + 1]]
	for c in candidates:
		if c[0] >= 1 and c[0] <= ENVIRON_COLS and c[1] >= 1 and c[1] <= ENVIRON_ROWS:
			result.append(environ_hex_id(c[0], c[1]))
	return result

func generate_environ(landing: int) -> void:
	environ_grid = {}
	var terrains: Array = GameData.tables.get("terrain_types", ["Open", "Rough", "Mountain", "Forest", "Desert", "Ice"])
	for col in range(1, ENVIRON_COLS + 1):
		for row in range(1, ENVIRON_ROWS + 1):
			var hid := environ_hex_id(col, row)
			var terrain: String = terrains[randi() % terrains.size()]
			environ_grid[hid] = {"terrain": terrain, "explored": false}
	# L'esagono di atterraggio è al centro, terreno aperto e già esplorato
	landing_hex = environ_hex_id(3, 3)
	environ_grid[landing_hex] = {"terrain": "Open", "explored": true}
	expedition_pos = landing_hex
	environ_changed.emit()

func can_move_expedition(hex_id: int) -> bool:
	if current_phase != Phase.EXPEDITION:
		return false
	if not current_creature.is_empty():
		return false
	return hex_id in environ_neighbors(expedition_pos)

func move_expedition(hex_id: int) -> void:
	if not can_move_expedition(hex_id):
		return
	expedition_pos = hex_id
	add_expedition_hours(1)  # ogni esagono costa 1 ora
	var cell: Dictionary = environ_grid.get(hex_id, {})
	var terrain: String = cell.get("terrain", "Open")
	add_log("La spedizione entra in un esagono %s (esagono %d)." % [_terrain_it(terrain), hex_id])
	environ_changed.emit()
	# Esplora il nuovo esagono se non ancora esplorato
	if not cell.get("explored", false):
		explore_environ_hex(hex_id, terrain)

func explore_environ_hex(hex_id: int, terrain: String) -> void:
	environ_grid[hex_id]["explored"] = true
	environ_changed.emit()
	var die := randi_range(1, 6)
	# Dado alto: incontro con creatura; altrimenti paragrafo di esplorazione
	if die >= 5:
		var names := GameData.get_all_creature_names()
		var creature: String = names[randi() % names.size()]
		add_log("Esplorazione (%s, dado %d): incontro!" % [_terrain_it(terrain), die])
		start_encounter(creature)
	else:
		var para_num := GameData.get_exploration_paragraph(terrain, die)
		add_log("Esplorazione (%s, dado %d) → Paragrafo %03d" % [_terrain_it(terrain), die, para_num])
		show_paragraph(para_num)

func _terrain_it(terrain: String) -> String:
	match terrain:
		"Open":     return "Aperto"
		"Rough":    return "Accidentato"
		"Mountain": return "Montagna"
		"Forest":   return "Foresta"
		"Desert":   return "Deserto"
		"Ice":      return "Ghiaccio"
	return terrain

# --- Combattimento / incontri (regola 8.0) -----------------------------------

func start_encounter(creature_name: String) -> void:
	if not GameData.get_creature(creature_name):
		add_log("Creatura sconosciuta: %s" % creature_name)
		return
	current_creature = creature_name
	# Determina la valutazione della creatura per l'esagono (8.4): 2d6 + Mod. Combattimento
	creature_rating = GameData.roll_creature_combat_rating(creature_name)
	add_log("Incontro con %s! Valutazione di combattimento: %d" % [creature_name, creature_rating])
	encounter_started.emit(creature_name)
	state_updated.emit()

# Risolve un round di combattimento.
# mode: "kill" (uccisione) o "capture" (cattura)
# player_combat: valore di combattimento del personaggio/strumento usato
func resolve_combat(mode: String, player_combat: int) -> void:
	if current_creature.is_empty():
		return
	var player_total := player_combat + randi_range(1, 6)
	var differential := player_total - creature_rating
	var result := GameData.get_combat_result(differential)
	var detail := "%s: %d (val.%d +1d6) vs creatura %d → diff %+d → %s" % [
		mode, player_total, player_combat, creature_rating, differential, result
	]
	add_log(detail)

	match result:
		"AE":  # l'attaccante elimina/cattura il difensore
			if mode == "capture":
				_capture_creature(current_creature)
			else:
				_kill_creature(current_creature)
		"AR":  # l'attaccante ripiega
			add_log("La creatura resiste; la spedizione ripiega di un esagono.")
		"EX":  # scambio: danni a entrambi
			_apply_damage(1)
			add_log("Scambio di colpi: 1 Punto Danno alla spedizione.")
		"DR":  # il difensore (creatura) ripiega/fugge
			add_log("%s fugge." % current_creature)
			_end_encounter()
		"DE":  # il difensore elimina l'attaccante
			_apply_damage(2)
			add_log("La creatura ha la meglio: 2 Punti Danno alla spedizione!")

	combat_resolved.emit(result, detail)
	state_updated.emit()

func _capture_creature(name: String) -> void:
	captured_creatures.append(name)
	add_log("%s catturata viva! (riportala alla Pandora per i PV)" % name)
	_end_encounter()

func _kill_creature(name: String) -> void:
	add_log("%s eliminata." % name)
	_end_encounter()

func _apply_damage(points: int) -> void:
	damage_points += points
	if damage_points >= 6:
		add_log("ATTENZIONE: danni critici alla spedizione (%d)!" % damage_points)

func _end_encounter() -> void:
	current_creature = ""
	creature_rating = 0
	encounter_ended.emit()
	set_phase(Phase.EXPEDITION)

func flee_encounter() -> void:
	if current_creature.is_empty():
		return
	add_log("La spedizione fugge da %s." % current_creature)
	# Fuga: la creatura può infliggere danni se più veloce
	var cdata := GameData.get_creature(current_creature)
	if cdata.get("speed", 0) >= 2 and randi_range(1, 6) <= cdata.get("aggression", 0):
		_apply_damage(1)
		add_log("%s insegue: 1 Punto Danno durante la fuga." % current_creature)
	_end_encounter()
