extends Node

signal phase_changed(new_phase: String)
signal state_updated
signal paragraph_request(para_num: int)
signal message_posted(msg: String)
signal encounter_started(creature_name: String)
signal encounter_ended
signal combat_resolved(result: String, detail: String)
signal game_saved

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
# Se false, il sistema tira automaticamente tutti i dadi; se true, è il
# giocatore a tirare (pulsante TIRA DADO) dove la regola lo prevede.
var manual_dice: bool = false
signal die_rolled(value: int, purpose: String)

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
	reset_expedition_state()
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

# --- Salvataggio / caricamento della partita -------------------------------
const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Serializza l'intero stato di gioco su disco (user://). Restituisce true se ok.
# Con silent=true non scrive nel diario né emette il suono (usato per l'autosave).
func save_game(silent := false) -> bool:
	var d := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"tour_length": tour_length, "tour_set": tour_set,
		"tour_months_used": tour_months_used, "expedition_hours": expedition_hours,
		"shuttle_supply": shuttle_supply, "expedition_supply": expedition_supply,
		"victory_points": victory_points,
		"pandora_hex": pandora_hex, "current_system": current_system, "current_planet": current_planet,
		"current_phase": int(current_phase), "current_paragraph": current_paragraph,
		"awaiting_die_roll": awaiting_die_roll, "pending_die_purpose": pending_die_purpose,
		"manual_dice": manual_dice,
		"crew": crew, "visited_systems": visited_systems, "log_entries": log_entries,
		"planet_attrs": planet_attrs, "planet_gravity": planet_gravity,
		"shuttle_capacity": shuttle_capacity, "expedition_units": expedition_units,
		"expedition_gear": expedition_gear, "damaged_gear": damaged_gear,
		"planned_supply": planned_supply,
		"current_creature": current_creature, "creature_rating": creature_rating,
		"damage_points": damage_points, "captured_creatures": captured_creatures,
		"creature_attr_cache": creature_attr_cache,
		"pending_combat_shift": pending_combat_shift, "pending_no_capture": pending_no_capture,
		"pending_kill_as_capture": pending_kill_as_capture,
		"encounter_outcome_text": encounter_outcome_text,
		"environ_grid": environ_grid, "expedition_pos": expedition_pos,
		"landing_hex": landing_hex, "current_environ_id": current_environ_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		add_log("Errore: impossibile salvare la partita.")
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if not silent:
		add_log("Partita salvata.")
		game_saved.emit()
	return true

# Ricarica lo stato dal file di salvataggio. I numeri JSON tornano come float,
# quindi i campi interi sono riconvertiti; le chiavi di environ_grid (id esagono)
# tornano stringa e vanno riportate a intero.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	tour_length = int(d.get("tour_length", 20))
	tour_set = str(d.get("tour_set", "20"))
	tour_months_used = int(d.get("tour_months_used", 0))
	expedition_hours = int(d.get("expedition_hours", 0))
	shuttle_supply = int(d.get("shuttle_supply", 6))
	expedition_supply = int(d.get("expedition_supply", 0))
	victory_points = int(d.get("victory_points", 0))
	pandora_hex = int(d.get("pandora_hex", 46))
	current_system = str(d.get("current_system", "Sol"))
	current_planet = str(d.get("current_planet", ""))
	current_phase = int(d.get("current_phase", Phase.INTERSTELLAR))
	current_paragraph = int(d.get("current_paragraph", 0))
	awaiting_die_roll = bool(d.get("awaiting_die_roll", false))
	pending_die_purpose = str(d.get("pending_die_purpose", ""))
	manual_dice = bool(d.get("manual_dice", false))
	var cr: Variant = d.get("crew", {})
	if typeof(cr) == TYPE_DICTIONARY:
		for k in cr:
			if crew.has(k):
				crew[k]["alive"] = bool(cr[k].get("alive", true))
				crew[k]["endurance"] = int(cr[k].get("endurance", MAX_ENDURANCE))
	visited_systems = d.get("visited_systems", [])
	log_entries = d.get("log_entries", [])
	planet_attrs = d.get("planet_attrs", {})
	planet_gravity = str(d.get("planet_gravity", "Earth like"))
	shuttle_capacity = int(d.get("shuttle_capacity", 80))
	expedition_units = d.get("expedition_units", [])
	expedition_gear = d.get("expedition_gear", [])
	damaged_gear = d.get("damaged_gear", [])
	planned_supply = int(d.get("planned_supply", 6))
	current_creature = str(d.get("current_creature", ""))
	creature_rating = int(d.get("creature_rating", 0))
	damage_points = int(d.get("damage_points", 0))
	captured_creatures = d.get("captured_creatures", [])
	creature_attr_cache = {}
	var cac: Variant = d.get("creature_attr_cache", {})
	if typeof(cac) == TYPE_DICTIONARY:
		for k in cac:
			creature_attr_cache[k] = int(cac[k])
	pending_combat_shift = int(d.get("pending_combat_shift", 0))
	pending_no_capture = bool(d.get("pending_no_capture", false))
	pending_kill_as_capture = bool(d.get("pending_kill_as_capture", false))
	encounter_outcome_text = str(d.get("encounter_outcome_text", ""))
	environ_grid = {}
	var eg: Variant = d.get("environ_grid", {})
	if typeof(eg) == TYPE_DICTIONARY:
		for k in eg:
			environ_grid[int(k)] = eg[k]
	expedition_pos = int(d.get("expedition_pos", 0))
	landing_hex = int(d.get("landing_hex", 0))
	current_environ_id = int(d.get("current_environ_id", 0))
	add_log("Partita caricata.")
	return true

func set_phase(p: Phase) -> void:
	current_phase = p
	phase_changed.emit(phase_name(p))
	state_updated.emit()
	# Salvataggio automatico a ogni transizione di gioco significativa, così il
	# progresso non si perde. Le fasi di menu/setup non vengono salvate.
	if p != Phase.MAIN_MENU and p != Phase.SETUP:
		save_game(true)

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
		# Evento interstellare (4.2): tiro manuale del giocatore o automatico.
		if manual_dice:
			pending_die_purpose = "interstellar_event"
			awaiting_die_roll = true
			message_posted.emit("Tira un dado per evento interstellare (regola 4.2).")
		else:
			var d := randi_range(1, 6)
			die_rolled.emit(d, "interstellar_event")
			resolve_interstellar_event(d)
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
			enter_orbit()

# Ingresso in orbita: prepara gli attributi del pianeta e mostra il paragrafo
# che lo descrive (Tabella Pianeti, 5.0). Il giocatore decide se esplorare.
func enter_orbit() -> void:
	set_phase(Phase.ORBIT)
	setup_orbit_planet()
	var para := GameData.get_planet_paragraph(current_system, tour_length)
	if para > 0:
		show_paragraph(para)

# Il giocatore sceglie di non esplorare: la Pandora lascia l'orbita (5.0).
func leave_orbit() -> void:
	add_log("La Pandora lascia l'orbita di %s senza esplorare." % current_system)
	set_phase(Phase.INTERSTELLAR)

# Vero quando il giocatore è in orbita e deve ancora decidere se esplorare.
func is_orbit_decision() -> bool:
	if expedition_pos != 0 or current_planet != "":
		return false
	if current_system == "" or current_system == "Sol":
		return false
	return current_phase == Phase.ORBIT or current_phase == Phase.PARAGRAPH

func land_on_planet(die_result: int) -> void:
	# Si sbarca solo dalla decisione in orbita (la fase può essere ORBIT o il
	# paragrafo del pianeta), e mai due volte.
	if current_planet != "" or expedition_pos != 0:
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
		var matched := false
		for dval in dice_range:
			if int(dval) == die_result:
				matched = true
				break
		if matched:
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

# Distribuzione degli esiti di combattimento per la modalità scelta (8.5):
# per ciascun risultato del dado (1-6) calcola il differenziale e il risultato
# sulla Tabella, restituendo {codice_risultato: conteggio_su_6}.
func combat_odds(mode: String) -> Dictionary:
	var pc := best_combat(mode)
	var dist := {}
	for die in range(1, 7):
		var diff := pc + die - creature_rating + pending_combat_shift
		var res := GameData.get_combat_result(diff)
		dist[res] = int(dist.get(res, 0)) + 1
	return dist

func show_paragraph(para_num: int) -> void:
	current_paragraph = para_num
	encounter_outcome_text = ""
	# Se il paragrafo è l'incontro di una creatura (retro del segnalino, 2.6) e la
	# spedizione è sulla superficie, prepara l'incontro: i comandi di combattimento
	# compaiono sopra al testo del paragrafo (le meccaniche seguono il libro-gioco).
	if current_creature.is_empty() and expedition_pos > 0:
		var creature := GameData.creature_for_paragraph(para_num)
		if creature != "":
			_begin_creature(creature)
	# Esito d'incontro: se siamo in un incontro e il paragrafo ha rami codificati,
	# il sistema li risolve coi Valori calcolati (8.2/8.5).
	if not current_creature.is_empty() and not GameData.get_paragraph_logic(para_num).is_empty():
		resolve_encounter_outcome(para_num)
	set_phase(Phase.PARAGRAPH)
	paragraph_request.emit(para_num)
	state_updated.emit()

# Valori degli attributi della creatura calcolati nell'incontro corrente (8.4),
# memorizzati come da regola (una volta determinati restano fissi).
var creature_attr_cache: Dictionary = {}
const RATING_TABLE := {2: 1, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5, 8: 6, 9: 7, 10: 8, 11: 9}
# Modificatori di combattimento impostati dai rami dei paragrafi (8.5)
var pending_combat_shift: int = 0      # colonne a sinistra (+) sulla tabella combattimento
var pending_no_capture: bool = false   # cattura non permessa
var pending_kill_as_capture: bool = false  # i risultati di uccisione contano come cattura
var encounter_outcome_text: String = ""    # esito risolto dal sistema, per la UI

# Calcola (e memorizza) il Valore di un attributo della creatura (8.4):
# tabella[2d6 + modificatore]. attr: "intel"|"combat"|"aggression"|"speed".
func creature_attr(attr: String) -> int:
	if current_creature.is_empty():
		return 0
	if creature_attr_cache.has(attr):
		return creature_attr_cache[attr]
	var modn := int(GameData.get_creature(current_creature).get(attr, 0))
	var total := clampi(randi_range(1, 6) + randi_range(1, 6) + modn, 2, 12)
	var rating: int
	if total <= 11:
		rating = int(RATING_TABLE.get(total, 1))
	else:
		var d := randi_range(1, 6)
		rating = 9 if d <= 2 else (10 if d <= 4 else (11 if d == 5 else 12))
	creature_attr_cache[attr] = rating
	return rating

# Velocità più alta / più bassa tra i personaggi imbarcati (per i confronti dei paragrafi).
func expedition_max_speed() -> int:
	var best := 0
	for k in expedition_units:
		best = maxi(best, int(GameData.get_character(k).get("speed", 0)))
	return best

func expedition_min_speed() -> int:
	var worst := 99
	for k in expedition_units:
		worst = mini(worst, int(GameData.get_character(k).get("speed", 99)))
	return worst if worst < 99 else 0

# --- Interprete dei rami dei paragrafi d'incontro (8.2/8.5) -------------------

# Risolve il paragrafo d'incontro coi Valori calcolati: applica gli esiti
# terminali (fuga/cattura/...) o imposta i modificatori di combattimento.
func resolve_encounter_outcome(para: int) -> void:
	encounter_outcome_text = ""
	pending_combat_shift = 0
	pending_no_capture = false
	pending_kill_as_capture = false
	if current_creature.is_empty():
		return
	for rule in GameData.get_paragraph_logic(para):
		if _cond_holds(rule.get("cond", [])):
			_apply_act(rule.get("act", {}))
			return

func _cond_holds(conds: Array) -> bool:
	for c in conds:
		var lhs: int = _attr_or_mod(str(c[0]))
		var rhs: int = _rhs_value(c[2])
		match str(c[1]):
			"<=": if not (lhs <= rhs): return false
			">=": if not (lhs >= rhs): return false
			"<":  if not (lhs < rhs): return false
			">":  if not (lhs > rhs): return false
			"==": if not (lhs == rhs): return false
	return true

func _attr_or_mod(key: String) -> int:
	var c := GameData.get_creature(current_creature)
	match key:
		"aggression", "speed", "intel", "combat": return creature_attr(key)
		"aggr_mod": return int(c.get("aggression", 0))
		"intel_mod": return int(c.get("intel", 0))
		"speed_mod": return int(c.get("speed", 0))
	return 0

func _rhs_value(rhs) -> int:
	if typeof(rhs) == TYPE_STRING:
		match rhs:
			"max_spd": return expedition_max_speed()
			"min_spd": return expedition_min_speed()
			"max_spd_plus1": return expedition_max_speed() + 1
			"min_spd_plus1": return expedition_min_speed() + 1
		return 0
	return int(rhs)

func _apply_act(act: Dictionary) -> void:
	var t: String = str(act.get("type", ""))
	match t:
		"flee":
			var h: int = int(act.get("hours", 0)) if typeof(act.get("hours", 0)) != TYPE_STRING else 0
			if h > 0: add_expedition_hours(h)
			encounter_outcome_text = "La creatura fugge: scegli un'altra azione."
			_clear_encounter_state()
		"leave":
			var h2: int = int(act.get("hours", 0))
			if h2 > 0: add_expedition_hours(h2)
			encounter_outcome_text = "La creatura non vi segue: scegli un'altra azione."
			_clear_encounter_state()
		"capture":
			if str(act.get("hours", "")) == "sum_pos_mods": add_expedition_hours(_sum_pos_mods())
			var nm := current_creature
			captured_creatures.append(nm)
			encounter_outcome_text = "%s catturata! Riportala alla Pandora per i PV." % nm
			_clear_encounter_state()
		"attack_flee":
			var res := int(act.get("resistance", 0))
			encounter_outcome_text = "La creatura attacca: %d Punti Resistenza persi, poi fugge." % res
			_apply_damage(res)
			_clear_encounter_state()
		"release":
			var vp := int(act.get("vp", 0))
			if act.has("vp_holographer") and _gear_has("Holographer"): vp += int(act["vp_holographer"])
			if act.has("vp_gso") and ("GSO" in expedition_units): vp += int(act["vp_gso"])
			var h3: int = int(act.get("hours", 0))
			if h3 > 0: add_expedition_hours(h3)
			gain_vp(vp, "Vita intelligente studiata: %s" % current_creature)
			encounter_outcome_text = "Vita senziente protetta: niente combattimento. +%d PV. Scegli un'azione." % vp
			_clear_encounter_state()
		"combat", "restrategy":
			if act.has("hours_if_co_gso"):
				var inteam: bool = ("CO" in expedition_units) or ("GSO" in expedition_units)
				add_expedition_hours(int(act["hours_if_co_gso"]) if inteam else int(act.get("hours_else", 0)))
			pending_combat_shift = _compute_shift(act)
			pending_no_capture = bool(act.get("no_capture", false))
			pending_kill_as_capture = bool(act.get("kill_as_capture", false))
			var parts: Array = []
			if pending_combat_shift > 0: parts.append("sposta %d col. a sinistra" % pending_combat_shift)
			elif pending_combat_shift < 0: parts.append("sposta %d col. a destra" % (-pending_combat_shift))
			if pending_no_capture: parts.append("nessuna cattura")
			if pending_kill_as_capture: parts.append("uccisione conta come cattura")
			if bool(act.get("resistance_only", false)): parts.append("danni come Resistenza")
			encounter_outcome_text = "Conduci il combattimento" + ("" if parts.is_empty() else " (" + ", ".join(parts) + ")") + "."

func _clear_encounter_state() -> void:
	current_creature = ""
	creature_rating = 0
	creature_attr_cache = {}

func _sum_pos_mods() -> int:
	var c := GameData.get_creature(current_creature)
	var s := 0
	for a in ["intel", "combat", "aggression", "speed"]:
		var v := int(c.get(a, 0))
		if v > 0: s += v
	return s

func _compute_shift(act: Dictionary) -> int:
	if act.has("shift_sum_mods"):
		var c := GameData.get_creature(current_creature)
		var s := int(c.get("intel", 0)) + int(c.get("aggression", 0)) + int(c.get("speed", 0))
		return 2 if s > 0 else (-2 if s < 0 else 0)
	if act.has("shift_right_neg_intel"):
		var im := int(GameData.get_creature(current_creature).get("intel", 0))
		return im if im < 0 else 0
	if act.has("shift_if_intel23"):
		var im2 := int(GameData.get_creature(current_creature).get("intel", 0))
		return int(act["shift_if_intel23"]) if (im2 == 2 or im2 == 3) else 0
	if act.has("shift_left_max_mods"):
		var best := 0
		for k in act["shift_left_max_mods"]:
			best = maxi(best, _attr_or_mod(str(k)))
		return best
	if act.has("shift_if_gso"):
		var has_sci: bool = ("GSO" in expedition_units) or ("Specibot" in expedition_gear)
		return int(act["shift_if_gso"]) if has_sci else int(act.get("shift", 0))
	return int(act.get("shift", 0))

# Prepara lo stato d'incontro senza riscrivere la UI (il testo del paragrafo resta).
func _begin_creature(name: String) -> void:
	if GameData.get_creature(name).is_empty():
		return
	current_creature = name
	creature_attr_cache = {}
	pending_combat_shift = 0
	pending_no_capture = false
	pending_kill_as_capture = false
	encounter_outcome_text = ""
	creature_rating = GameData.roll_creature_combat_rating(name)
	add_log("Incontro con %s! Valutazione di combattimento per l'esagono: %d." % [name, creature_rating])

func return_to_pandora() -> void:
	# Return from expedition to orbit
	if current_phase == Phase.EXPEDITION or current_phase == Phase.PARAGRAPH:
		shuttle_supply += expedition_supply
		expedition_supply = 0
		# Assegna i PV per le creature catturate riportate sulla Pandora (8.0/9.0)
		if captured_creatures.size() > 0:
			for cname in captured_creatures:
				# 1 PV per creatura riportata + eventuali PV extra del segnalino (9.1)
				var vp := 1 + GameData.creature_vp(cname)
				gain_vp(vp, "Creatura riportata viva: %s" % cname)
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

# Movimento affrettato (6.3): si può andare in QUALSIASI esagono dell'area pagando
# la somma delle ore d'ingresso lungo il percorso più economico; poi si consulta
# la Matrice di Esplorazione (6.4).
func can_hasty_move(hex_id: int) -> bool:
	if current_phase != Phase.EXPEDITION or not current_creature.is_empty():
		return false
	return environ_grid.has(hex_id) and hex_id != expedition_pos and not (hex_id in environ_neighbors(expedition_pos))

func hasty_move_to(hex_id: int) -> void:
	if not can_hasty_move(hex_id):
		return
	var cost := _hasty_path_cost(expedition_pos, hex_id)
	var cell: Dictionary = environ_grid.get(hex_id, {})
	var terrain: String = cell.get("terrain", "Open")
	expedition_pos = hex_id
	add_expedition_hours(cost)
	add_log("Movimento affrettato fino a %s — %d ore." % [cell.get("real", str(hex_id)), cost])
	environ_changed.emit()
	# Dopo la mossa si consulta comunque la Matrice di Esplorazione (6.4)
	if not cell.get("explored", false):
		explore_environ_hex(hex_id, terrain)
	else:
		show_paragraph(GameData.get_exploration_2d6(randi_range(1, 6), randi_range(1, 6)))

# Costo minimo (in ore d'ingresso) del percorso fra due esagoni dell'area (Dijkstra).
func _hasty_path_cost(from_hex: int, to_hex: int) -> int:
	var dist := {from_hex: 0}
	var queue := [from_hex]
	while queue.size() > 0:
		# estrai il nodo con costo minimo
		var bi := 0
		for i in range(1, queue.size()):
			if dist[queue[i]] < dist[queue[bi]]:
				bi = i
		var cur: int = queue[bi]
		queue.remove_at(bi)
		if cur == to_hex:
			return dist[cur]
		for nb in environ_neighbors(cur):
			if not environ_grid.has(nb):
				continue
			var nterr: String = environ_grid[nb].get("terrain", "Open")
			var nd: int = dist[cur] + enter_cost_for(nterr)
			if not dist.has(nb) or nd < dist[nb]:
				dist[nb] = nd
				if not (nb in queue):
					queue.append(nb)
	return dist.get(to_hex, 99)

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
	if not environ_grid.has(hex_id):
		return  # nessun esagono valido da esplorare (spedizione non sbarcata)
	environ_grid[hex_id]["explored"] = true
	# Esplorare costa le ore del terreno (Carta 6.6), modificate dall'equipaggiamento
	var explore_cost := explore_cost_for(terrain)
	add_expedition_hours(explore_cost)
	add_log("Esplorazione di %s — %d ore%s." % [
		_terrain_it(terrain), explore_cost, _gear_cost_note(terrain)])
	_consume_supply_for(terrain)
	environ_changed.emit()
	# Esplorazione subordinata al libro-gioco (6.4): Matrice di Esplorazione reale.
	# Si tira il 1° dado (colonna) e il 2° dado (riga) → paragrafo dell'incontro.
	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	var para_num := GameData.get_exploration_2d6(d1, d2)
	add_log("Esplorazione (%s) — Matrice di Esplorazione dadi %d/%d → Paragrafo %03d" % [_terrain_it(terrain), d1, d2, para_num])
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

# Strategia d'Incontro (8.2): il giocatore dichiara la strategia; si tira 1d6
# modificato dai modificatori della creatura e si va al paragrafo esito.
func choose_encounter_strategy(strategy: String) -> void:
	if current_creature.is_empty():
		return
	var c := GameData.get_creature(current_creature)
	var intel := int(c.get("intel", 0))
	var aggr := int(c.get("aggression", 0))
	var modifier := 0
	match strategy:
		"communicate": modifier = intel - abs(aggr)
		"capture_kill": modifier = intel + aggr
		"flee": modifier = aggr
	var roll := randi_range(1, 6)
	var die := roll + modifier
	var para := GameData.encounter_strategy_para(die, strategy)
	var sname: String = {"communicate": "Comunica", "capture_kill": "Cattura/Uccidi", "flee": "Fuggi"}.get(strategy, strategy)
	add_log("Strategia «%s»: dado %d %+d = %d → Paragrafo %03d." % [sname, roll, modifier, die, para])
	if para > 0:
		show_paragraph(para)

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
	# Spostamento di colonne dai rami del paragrafo (8.5): a sinistra = a favore.
	var differential := player_total - creature_rating + pending_combat_shift
	var result := GameData.get_combat_result(differential)
	var shift_txt := (" [%+d col.]" % pending_combat_shift) if pending_combat_shift != 0 else ""
	var detail := "%s: %d (val.%d +1d6) vs creatura %d → diff %+d%s → %s" % [
		mode, player_total, player_combat, creature_rating, differential, shift_txt, result
	]
	add_log(detail)

	match result:
		"AE":  # l'attaccante elimina/cattura il difensore
			if mode == "capture" or pending_kill_as_capture:
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
	creature_attr_cache = {}
	pending_combat_shift = 0
	pending_no_capture = false
	pending_kill_as_capture = false
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
