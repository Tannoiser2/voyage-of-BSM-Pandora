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

# Crew — ogni personaggio ha un Valore di Resistenza (Endurance) di 6 (regola 2.5).
# I Punti Danno riducono la Resistenza; a 0 il personaggio è ucciso (8.8).
const MAX_ENDURANCE := 6
var crew: Dictionary = {
	"CO":   {"name": "Comandante",            "alive": true, "endurance": 6},
	"Nav":  {"name": "Navigatore",            "alive": true, "endurance": 6},
	"SO":   {"name": "Ufficiale di Sicurezza","alive": true, "endurance": 6},
	"GSO":  {"name": "Ufficiale Scienze",     "alive": true, "endurance": 6},
	"MedO": {"name": "Ufficiale Medico",      "alive": true, "endurance": 6},
	"WO":   {"name": "Ufficiale Armi",        "alive": true, "endurance": 6},
	"MntO": {"name": "Ufficiale Manutenzione","alive": true, "endurance": 6}
}

var visited_systems: Array = []
var log_entries: Array = []

# Preparazione della spedizione (regola 5.0)
var planet_attrs: Dictionary = {}          # attributi reali del pianeta in orbita
var planet_gravity: String = "Earth like"  # gravità del pianeta in orbita
var shuttle_capacity: int = 80             # capacità di porto dello shuttle (Carta 5.8)
var expedition_units: Array = []           # chiavi dei personaggi scelti per la spedizione
var expedition_gear: Array = []            # chiavi di robot/strumenti imbarcati (5.2)
var damaged_gear: Array = []               # chiavi di robot/strumenti danneggiati (6.9)
var planned_supply: int = 6                # Punti Rifornimento da caricare (0-20, regola 5.3)

# Combattimento / incontri
var current_creature: String = ""
var creature_rating: int = 0          # valutazione della creatura per l'esagono (8.4)
var damage_points: int = 0            # danni accumulati dalla spedizione
var captured_creatures: Array = []    # creature catturate vive (PV extra)

# Superficie planetaria (environ) — regola 6.0
# Ogni environ è una mappa reale di 6 colonne × 7 righe (42 esagoni).
const ENVIRON_COLS := 6
const ENVIRON_ROWS := 7
var environ_grid: Dictionary = {}     # hex_id locale -> {"terrain","explored","real","x","y"}
var expedition_pos: int = 0           # esagono attuale della spedizione (0 = non sbarcata)
var landing_hex: int = 0
var current_environ_id: int = 0       # quale degli 8 environ reali è in uso (0 = nessuno)
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
	expedition_units = []
	expedition_gear = []
	damaged_gear = []
	planned_supply = 6
	planet_attrs = {}
	planet_gravity = "Earth like"
	shuttle_capacity = 80
	for k in crew:
		crew[k]["alive"] = true
		crew[k]["endurance"] = MAX_ENDURANCE

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
	var landing_real := ""   # esagono di atterraggio globale (es. "1502")
	for entry in landings:
		var dice_range: Array = entry.get("die", [])
		if die_result in dice_range:
			landing_para = entry.get("para", "114").to_int()
			landing_real = entry.get("hex", "")
			break

	current_planet = current_system
	expedition_hours = 0
	expedition_supply = shuttle_supply  # bring supplies from shuttle
	shuttle_supply = 0
	reset_expedition_state()
	generate_environ_at(landing_real)

	add_log("Atterraggio su %s. Dado: %d → Paragrafo %03d" % [current_system, die_result, landing_para])
	set_phase(Phase.EXPEDITION)
	show_paragraph(landing_para)

# --- Preparazione della spedizione (regola 5.0) ------------------------------

# Chiamata all'ingresso in orbita: legge gli attributi reali del pianeta,
# imposta gravità, capacità dello shuttle e squadra iniziale.
func setup_orbit_planet() -> void:
	planet_attrs = GameData.get_planet_attributes(current_system, tour_length)
	planet_gravity = planet_attrs.get("gravity", "Earth like")
	shuttle_capacity = GameData.shuttle_capacity_for(planet_gravity)
	expedition_units = default_team()
	expedition_gear = []
	damaged_gear = []
	planned_supply = clampi(6, 0, max_planned_supply())
	add_log("In orbita su %s — gravità %s, atmosfera %s, capacità shuttle %d." % [
		current_system, GameData.gravity_it(planet_gravity),
		GameData.atmosphere_it(planet_attrs.get("atmosphere", "Normal")), shuttle_capacity])

# Squadra di default: tutti i personaggi vivi che rientrano nella capacità.
func default_team() -> Array:
	var team: Array = []
	var w := 0
	for k in GameData.get_character_keys():
		if not crew.get(k, {}).get("alive", true):
			continue
		var uw: int = int(GameData.get_character(k).get("weight", 6))
		if w + uw <= shuttle_capacity:
			team.append(k)
			w += uw
	if team.is_empty():
		var keys := GameData.get_character_keys()
		if keys.size() > 0:
			team.append(keys[0])
	return team

func toggle_expedition_unit(key: String) -> void:
	if key in expedition_units:
		expedition_units.erase(key)
	else:
		expedition_units.append(key)
	planned_supply = clampi(planned_supply, 0, max_planned_supply())

# Imbarca/rimuove un robot o strumento (5.2)
func toggle_gear_unit(key: String) -> void:
	if key in expedition_gear:
		expedition_gear.erase(key)
	else:
		expedition_gear.append(key)
	planned_supply = clampi(planned_supply, 0, max_planned_supply())

func units_weight() -> int:
	var w := 0
	for k in expedition_units:
		w += int(GameData.get_character(k).get("weight", 6))
	for k in expedition_gear:
		w += int(GameData.get_unit(k).get("weight", 0))
	return w

func total_load() -> int:
	return units_weight() + planned_supply

func max_planned_supply() -> int:
	return clampi(shuttle_capacity - units_weight(), 0, GameData.max_supply())

func has_character_selected() -> bool:
	return expedition_units.size() > 0

# La preparazione è valida se c'è almeno un personaggio e il carico sta nella capacità (5.2).
func prep_valid() -> bool:
	return has_character_selected() and total_load() <= shuttle_capacity

# Lancia lo shuttle con la squadra e i rifornimenti scelti.
func launch_expedition(die_result: int) -> void:
	if not prep_valid():
		add_log("Preparazione non valida: serve almeno un personaggio entro la capacità.")
		return
	shuttle_supply = planned_supply
	var names: Array = []
	for k in expedition_units:
		names.append(GameData.get_character(k).get("name", k))
	var gear_names: Array = []
	for k in expedition_gear:
		gear_names.append(GameData.get_unit(k).get("name", k))
	var gear_txt := "" if gear_names.is_empty() else " · Equip.: %s" % ", ".join(gear_names)
	add_log("Shuttle lanciato: %s · Rifornimenti %d%s." % [", ".join(names), planned_supply, gear_txt])
	land_on_planet(die_result)

# Miglior valore di combattimento tra personaggi, robot e armi imbarcate (8.0).
# Le armi (Netgun/Stunbomb/Turbolaser) sostituiscono i valori del personaggio (2.5).
func best_combat(mode: String) -> int:
	var best := 0
	for k in expedition_units:
		var u := GameData.get_character(k)
		var v: int = int(u.get("capture", 0)) if mode == "capture" else int(u.get("kill", 0))
		best = maxi(best, v)
	for k in expedition_gear:
		if k in damaged_gear:
			continue  # robot/arma danneggiati non utilizzabili (6.9)
		var g := GameData.get_unit(k)
		if g.get("combat", false) or GameData.get_bot_keys().has(k):
			var gv: int = int(g.get("capture", 0)) if mode == "capture" else int(g.get("kill", 0))
			best = maxi(best, gv)
	return best if best > 0 else 3

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
	# Regola 9.2: 1 PV perso per ogni Punto Resistenza perso dai personaggi sopravvissuti.
	var lost := 0
	for k in crew:
		if crew[k].get("alive", false):
			lost += MAX_ENDURANCE - int(crew[k].get("endurance", MAX_ENDURANCE))
	if lost > 0:
		lose_vp(lost, "Ferite dei sopravvissuti a fine tour (%d Resistenza)" % lost)
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
	damaged_gear = []
	environ_grid = {}
	expedition_pos = 0
	landing_hex = 0
	current_environ_id = 0

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

# Genera l'environ a partire dall'esagono di atterraggio reale della carta pianeta
# (es. "1502"), scegliendo l'environ corretto e l'esagono d'atterraggio corretto.
func generate_environ_at(landing_real: String) -> void:
	environ_grid = {}
	var place := GameData.find_environ_hex(landing_real) if landing_real != "" else {}
	if place.is_empty():
		# Fallback: environ deterministico per sistema, atterraggio al centro.
		current_environ_id = _pick_environ_id()
	else:
		current_environ_id = place.get("env", 0)
	var env: Dictionary = GameData.get_environ(current_environ_id)
	var hexes: Dictionary = env.get("hexes", {})
	if hexes.is_empty():
		_generate_environ_fallback()
		return
	for key in hexes:
		var h: Dictionary = hexes[key]
		var hid := int(str(key))
		environ_grid[hid] = {
			"terrain": h.get("terrain", "Open"),
			"explored": false,
			"real": h.get("real", ""),
			"x": h.get("x", 0.0),
			"y": h.get("y", 0.0),
		}
	# Esagono di atterraggio: quello indicato dalla carta, o il più vicino al centro.
	landing_hex = place.get("local", _central_environ_hex()) if not place.is_empty() else _central_environ_hex()
	if not environ_grid.has(landing_hex):
		landing_hex = _central_environ_hex()
	# L'esagono di atterraggio non è ancora esplorato: la spedizione può esplorarlo.
	expedition_pos = landing_hex
	environ_changed.emit()

# Esplora l'esagono attualmente occupato dalla spedizione (es. l'atterraggio).
func explore_current_hex() -> void:
	if current_phase != Phase.EXPEDITION or not current_creature.is_empty():
		return
	var cell: Dictionary = environ_grid.get(expedition_pos, {})
	if cell.get("explored", false):
		add_log("Questo esagono è già stato esplorato.")
		return
	explore_environ_hex(expedition_pos, cell.get("terrain", "Open"))

# Versione legacy (atterraggio al centro) mantenuta per compatibilità.
func generate_environ(_landing: int) -> void:
	generate_environ_at("")

func _pick_environ_id() -> int:
	var n := GameData.environ_count()
	if n <= 0:
		return 0
	if current_system != "" and current_system != "Sol":
		return abs(current_system.hash()) % n + 1
	return randi_range(1, n)

func _central_environ_hex() -> int:
	# Esagono con (col,row) più vicino al centro 3.5 / 4
	var best := -1
	var best_d := 1e9
	for hid in environ_grid:
		var col: int = hid / 10
		var row: int = hid % 10
		var d: float = pow(col - 3.5, 2) + pow(row - 4.0, 2)
		if d < best_d:
			best_d = d
			best = hid
	return best if best > 0 else environ_hex_id(3, 4)

func _generate_environ_fallback() -> void:
	var terrains: Array = GameData.tables.get("terrain_types", ["Open", "Rough", "Mountain", "Forest", "Desert", "Ice"])
	for col in range(1, ENVIRON_COLS + 1):
		for row in range(1, ENVIRON_ROWS + 1):
			var hid := environ_hex_id(col, row)
			environ_grid[hid] = {"terrain": terrains[randi() % terrains.size()], "explored": false}
	landing_hex = environ_hex_id(3, 4)
	environ_grid[landing_hex]["explored"] = true
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
	var cell: Dictionary = environ_grid.get(hex_id, {})
	var terrain: String = cell.get("terrain", "Open")
	var real_id: String = cell.get("real", str(hex_id))
	# Entrare in un esagono costa le ore del terreno (Carta 6.6), modificate dall'equipaggiamento
	var enter_cost := enter_cost_for(terrain)
	expedition_pos = hex_id
	add_expedition_hours(enter_cost)
	add_log("La spedizione entra in %s (esagono %s) — %d ore%s." % [
		_terrain_it(terrain), real_id, enter_cost, _gear_cost_note(terrain)])
	environ_changed.emit()
	# Esplora il nuovo esagono se non ancora esplorato
	if not cell.get("explored", false):
		explore_environ_hex(hex_id, terrain)

func explore_environ_hex(hex_id: int, terrain: String) -> void:
	environ_grid[hex_id]["explored"] = true
	# Esplorare costa le ore del terreno (Carta 6.6), modificate dall'equipaggiamento
	var explore_cost := explore_cost_for(terrain)
	add_expedition_hours(explore_cost)
	add_log("Esplorazione di %s — %d ore%s." % [
		_terrain_it(terrain), explore_cost, _gear_cost_note(terrain)])
	_consume_supply_for(terrain)
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
	return GameData.terrain_it(terrain)

# --- Effetti dell'equipaggiamento sui costi del terreno (2.5) -----------------

func _gear_has(key: String) -> bool:
	return key in expedition_gear

# Il Climbkit dimezza (per eccesso) le ore in montagna e dirupi.
func _climbkit_applies(terrain: String) -> bool:
	var real := GameData.terrain_real(terrain)
	return _gear_has("Climbkit") and (real == "Mountain" or real == "Cliffs")

func enter_cost_for(terrain: String) -> int:
	var c := GameData.terrain_enter_cost(terrain)
	# Rover: usa il costo d'ingresso con veicolo dove il terreno è percorribile
	if _gear_has("Rover"):
		var rc := int(GameData.terrain_effect(terrain).get("enter_rover", c))
		if rc > 0:
			c = rc
	if _climbkit_applies(terrain):
		c = maxi(1, int(ceil(c / 2.0)))
	return c

func explore_cost_for(terrain: String) -> int:
	var c := GameData.terrain_explore_cost(terrain)
	if _climbkit_applies(terrain):
		c = maxi(1, int(ceil(c / 2.0)))
	return c

# Nota da appendere al log quando l'equipaggiamento riduce il costo.
func _gear_cost_note(terrain: String) -> String:
	var parts: Array = []
	if _climbkit_applies(terrain):
		parts.append("Climbkit")
	if _gear_has("Rover") and int(GameData.terrain_effect(terrain).get("enter_rover", 0)) > 0:
		parts.append("Rover")
	return "" if parts.is_empty() else " (" + ", ".join(parts) + ")"

# --- Controllo dei rifornimenti (regola 7.2) ---------------------------------

# Esplorare un esagono consuma (o, su terreni fertili, fornisce) Rifornimenti.
func _consume_supply_for(terrain: String) -> void:
	var cost := int(GameData.terrain_effect(terrain).get("supply", 0))
	if cost < 0:
		# Terreno fertile: rifornimento, fino al massimo trasportabile
		expedition_supply = mini(expedition_supply - cost, GameData.max_supply())
		add_log("Il terreno fornisce %d Rifornimenti (totale %d)." % [-cost, expedition_supply])
	elif cost > 0:
		if expedition_supply >= cost:
			expedition_supply -= cost
			add_log("Consumo di %d Rifornimenti (rimasti %d)." % [cost, expedition_supply])
		else:
			var short := cost - expedition_supply
			expedition_supply = 0
			add_log("Rifornimenti esauriti (7.2): %d Punti Danno per gli stenti." % short)
			_apply_damage(short)
	state_updated.emit()

# --- Equipaggiamento danneggiato e riparazioni (regola 6.9) ------------------

func _gear_is_bot(key: String) -> bool:
	return GameData.get_bot_keys().has(key)

func _gear_active(key: String) -> bool:
	return key in expedition_gear and not (key in damaged_gear)

# Robot imbarcati e funzionanti, disponibili a fare da scudo all'equipaggio.
func _functioning_bots() -> Array:
	var out: Array = []
	for k in expedition_gear:
		if _gear_is_bot(k) and not (k in damaged_gear):
			out.append(k)
	return out

# Riparazione in spedizione: il Botkit ripara i robot, il Toolkit gli strumenti (6.9).
func can_repair() -> bool:
	if current_phase != Phase.EXPEDITION or not current_creature.is_empty():
		return false
	return _next_repairable() != ""

func _next_repairable() -> String:
	for k in damaged_gear:
		if _gear_is_bot(k) and _gear_active("Botkit"):
			return k
		if not _gear_is_bot(k) and _gear_active("Toolkit"):
			return k
	return ""

func repair_gear() -> void:
	var key := _next_repairable()
	if key == "":
		return
	damaged_gear.erase(key)
	add_expedition_hours(1)
	var kit := "Botkit" if _gear_is_bot(key) else "Toolkit"
	add_log("%s ripara %s." % [kit, GameData.get_unit(key).get("name", key)])
	state_updated.emit()

# --- Combattimento / incontri (regola 8.0) -----------------------------------

func start_encounter(creature_name: String) -> void:
	if not GameData.get_creature(creature_name):
		add_log("Creatura sconosciuta: %s" % creature_name)
		return
	current_creature = creature_name
	# Determina la valutazione della creatura per l'esagono (8.4): 2d6 + Mod. Combattimento
	creature_rating = GameData.roll_creature_combat_rating(creature_name)
	add_log("Incontro con %s! Valutazione di combattimento: %d" % [creature_name, creature_rating])
	# Sorpresa (8.1): la creatura può colpire per prima. Lo Scanner riduce la probabilità.
	var threshold := 1 if _gear_has("Scanner") else 2
	var sroll := randi_range(1, 6)
	if sroll <= threshold:
		add_log("Sorpresa (8.1)! %s colpisce per prima (tiro %d): 1 Punto Danno." % [creature_name, sroll])
		_apply_damage(1)
	elif _gear_has("Scanner") and sroll == 2:
		add_log("Lo Scanner ha sventato un attacco a sorpresa (tiro %d)." % sroll)
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

# I Punti Danno riducono la Resistenza dei personaggi imbarcati (8.8).
# I robot funzionanti fanno da scudo: assorbono un colpo ciascuno danneggiandosi (6.9).
func _apply_damage(points: int) -> void:
	damage_points += points
	for _i in range(points):
		var bots := _functioning_bots()
		if bots.size() > 0:
			var bot: String = bots[0]
			damaged_gear.append(bot)
			add_log("%s incassa il colpo al posto dell'equipaggio: danneggiato (6.9)." % GameData.get_unit(bot).get("name", bot))
			continue
		var target := _pick_wound_target()
		if target == "":
			add_log("Nessun personaggio può assorbire altri danni!")
			break
		crew[target]["endurance"] = maxi(0, int(crew[target].get("endurance", MAX_ENDURANCE)) - 1)
		add_log("%s subisce 1 Punto Danno (Resistenza %d/%d)." % [
			crew[target]["name"], crew[target]["endurance"], MAX_ENDURANCE])
		if crew[target]["endurance"] <= 0:
			_kill_character(target)
	state_updated.emit()

# Sceglie il personaggio imbarcato con più Resistenza, per distribuire i danni.
func _pick_wound_target() -> String:
	var best := ""
	var best_e := 0
	for k in expedition_units:
		if not crew.get(k, {}).get("alive", false):
			continue
		var e: int = int(crew[k].get("endurance", 0))
		if e > best_e:
			best_e = e
			best = k
	return best

func _kill_character(key: String) -> void:
	crew[key]["alive"] = false
	expedition_units.erase(key)
	lose_vp(10, "Personaggio ucciso: %s" % crew[key]["name"])
	add_log("%s è caduto in missione." % crew[key]["name"])
	# Spedizione senza personaggi: distrutta (regola 5.7)
	if not has_character_selected():
		add_log("La spedizione non ha più personaggi: è considerata distrutta. Rientro forzato.")
		_end_encounter()
		return_to_pandora()

# Cura: l'Ufficiale Medico o un Medkit imbarcato ripristinano la Resistenza del più ferito (2.5).
func _can_treat() -> bool:
	if "MedO" in expedition_units and crew.get("MedO", {}).get("alive", false):
		return true
	return _gear_active("Medkit")

func can_heal() -> bool:
	if current_phase != Phase.EXPEDITION or not current_creature.is_empty():
		return false
	if not _can_treat():
		return false
	return _most_wounded() != ""

func heal_wounded() -> void:
	if not can_heal():
		return
	var target := _most_wounded()
	if target == "":
		return
	crew[target]["endurance"] = MAX_ENDURANCE
	add_expedition_hours(1)
	var healer := "L'Ufficiale Medico" if ("MedO" in expedition_units and crew.get("MedO", {}).get("alive", false)) else "Il Medkit"
	add_log("%s cura %s (Resistenza %d/%d)." % [
		healer, crew[target]["name"], crew[target]["endurance"], MAX_ENDURANCE])
	state_updated.emit()

func _most_wounded() -> String:
	var worst := ""
	var worst_e := MAX_ENDURANCE
	for k in expedition_units:
		if not crew.get(k, {}).get("alive", false):
			continue
		var e: int = int(crew[k].get("endurance", MAX_ENDURANCE))
		if e < worst_e:
			worst_e = e
			worst = k
	return worst

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
