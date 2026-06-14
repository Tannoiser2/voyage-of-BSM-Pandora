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

# Crew — ogni personaggio ha un Valore di Resistenza (Endurance) di 5 (regola 2.5).
# I Punti Danno riducono la Resistenza; a 0 il personaggio è ucciso (8.8).
const MAX_ENDURANCE := 5
var crew: Dictionary = {
	"CO":   {"name": "Comandante",            "alive": true, "endurance": 5, "intelligence": 0},
	"Nav":  {"name": "Navigatore",            "alive": true, "endurance": 5, "intelligence": 0},
	"SO":   {"name": "Ufficiale di Sicurezza","alive": true, "endurance": 5, "intelligence": 0},
	"GSO":  {"name": "Ufficiale Scienze",     "alive": true, "endurance": 5, "intelligence": 0},
	"MedO": {"name": "Ufficiale Medico",      "alive": true, "endurance": 5, "intelligence": 0},
	"WO":   {"name": "Ufficiale Armi",        "alive": true, "endurance": 5, "intelligence": 0},
	"MntO": {"name": "Ufficiale Manutenzione","alive": true, "endurance": 5, "intelligence": 0}
}

var visited_systems: Array = []
# Numero di superfici planetarie su cui si è già sbarcati (regola 6.0). Serve alla
# condizione del ¶058 («oppure non è ancora stata visitata alcuna superficie planetaria»).
var surfaces_visited: int = 0
var log_entries: Array = []
var vp_ledger: Array = []   # storico delle variazioni di PV {amount, reason} per il riepilogo finale

# Preparazione della spedizione (regola 5.0)
var planet_attrs: Dictionary = {}          # attributi reali del pianeta in orbita
var planet_gravity: String = "Earth like"  # gravità del pianeta in orbita
var shuttle_capacity: int = 80             # capacità di porto dello shuttle (Carta 5.8)
var expedition_units: Array = []           # chiavi dei personaggi scelti per la spedizione
var expedition_gear: Array = []            # chiavi di robot/strumenti imbarcati (5.2)
var damaged_gear: Array = []               # chiavi di robot/strumenti danneggiati (6.9)
var planned_supply: int = 6                # Punti Rifornimento da caricare (0-20, regola 5.3)

# Traccia Tempo e Rifornimento (6.8 / 7.0): la posizione avanza con le ore di
# spedizione spese; quando raggiunge/supera lo «spazio di controllo» della gravità
# si esegue un Controllo del Rifornimento (7.1/7.2) e la posizione si azzera.
var supply_track_pos: int = 0
# Spazio del Controllo del Rifornimento per gravità (regola 6.8, valori dei componenti).
const SUPPLY_CHECK_SPACE := {
	"Oppressive": 6,
	"Heavy": 12,
	"Earth like": 16,
	"Light": 22,
	"Near weightless": 30
}
# Controlli del rifornimento ancora da risolvere quando i tiri sono manuali: ogni
# elemento è un singolo controllo in attesa del dado del giocatore (vedi 7.2).
var pending_supply_checks: int = 0

# Combattimento / incontri
var current_creature: String = ""
var creature_rating: int = 0          # valutazione della creatura per l'esagono (8.4)
var damage_points: int = 0            # danni accumulati dalla spedizione
var captured_creatures: Array = []    # creature catturate vive (PV extra)
var acquired_artifacts: Array = []    # paragrafi degli artefatti acquisiti (registro permanente: anti-doppione + arma aliena)
var pending_artifact_vp: Array = []   # artefatti raccolti ma non ancora riportati sulla Pandora (PV assegnati al rientro, 2.6/9.1)
var weapon_usable: bool = false       # l'Arma aliena (¶006) è usabile in combattimento solo dopo averla compresa (¶006/¶175)
var intel_checks_done: Array = []     # paragrafi con check Intelligenza (3.3) già risolti (¶006/¶175/...)
var recorded_creatures: Array = []    # tipi di creatura registrati sul Registro Attributi (PV per attributi a zero, 9.1)
var explored_planets: Array = []      # sistemi i cui pianeti sono stati esplorati (1 PV ciascuno, 9.1)

# Superficie planetaria (environ) — regola 6.0
# Ogni environ è una mappa reale di 6 colonne × 7 righe (42 esagoni).
const ENVIRON_COLS := 6
const ENVIRON_ROWS := 7
var environ_grid: Dictionary = {}     # hex_id locale -> {"terrain","explored","real","x","y"}
var expedition_pos: int = 0           # esagono attuale della spedizione (0 = non sbarcata)
var landing_hex: int = 0
var current_environ_id: int = 0       # quale degli 8 environ reali è in uso (0 = nessuno)
# Terreni (reali, es. "Mountain") attraversati durante l'ULTIMO movimento affrettato
# (6.3): servono a valutare la variante «oppure vi si è entrati durante il movimento
# affrettato» degli snodi «Incontro di spedizione» (6.5).
var hasty_path_terrains: Array = []
# Guardia anti-ricorsione per i ri-tiri della Matrice di Esplorazione negli snodi (6.5).
var _expedition_reroll_depth: int = 0
const MAX_EXPEDITION_REROLLS := 8
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
	surfaces_visited = 0
	jump_origin_hex = 46
	jump_dest_hex = 46
	pending_event_para = 0
	log_entries = []
	vp_ledger = []
	expedition_units = []
	expedition_gear = []
	damaged_gear = []
	planned_supply = 6
	planet_attrs = {}
	planet_gravity = "Earth like"
	shuttle_capacity = 80
	captured_creatures = []
	acquired_artifacts = []
	pending_artifact_vp = []
	weapon_usable = false
	intel_checks_done = []
	recorded_creatures = []
	explored_planets = []
	supply_track_pos = 0
	pending_supply_checks = 0
	reset_expedition_state()
	for k in crew:
		crew[k]["alive"] = true
		crew[k]["endurance"] = MAX_ENDURANCE
		# Valore di Intelligenza determinato a inizio gioco (3.3), fisso per la partita.
		crew[k]["intelligence"] = _roll_intelligence()

	# Set initial VP based on tour length (from rules)
	match tour_length:
		10: victory_points = 10
		20: victory_points = 20
		30: victory_points = 30
	vp_ledger.append({"amount": victory_points, "reason": "Punti Vittoria iniziali (tour %d mesi)" % tour_length})

	set_phase(Phase.INTERSTELLAR)
	add_log("Nuovo viaggio iniziato. Tour: %d mesi. Pandora in orbita attorno a Sol." % tour_length)

# Valore di Intelligenza di un personaggio (3.3): un dado -> 1:6, 2-3:7, 4-5:8, 6:9.
func _roll_intelligence() -> int:
	var d := randi_range(1, 6)
	return 6 if d == 1 else (7 if d <= 3 else (8 if d <= 5 else 9))

# Valore di Intelligenza corrente del personaggio (0 se non determinato).
func character_intelligence(key: String) -> int:
	return int(crew.get(key, {}).get("intelligence", 0))

# Valore di Intelligenza più alto tra i personaggi indicati ancora vivi (per i
# paragrafi che fanno riferimento "all'ufficiale con Intelligenza più alta").
func highest_intelligence(keys: Array) -> int:
	var best := 0
	for k in keys:
		var c: Dictionary = crew.get(k, {})
		if c.get("alive", false):
			best = maxi(best, int(c.get("intelligence", 0)))
	return best

# Chiave del personaggio imbarcato vivo con Intelligenza più alta ("" se nessuno):
# per i paragrafi in cui «si sceglie un personaggio» (gioco ottimale) e l'effetto
# ricade su chi investiga (es. ¶030).
func highest_intelligence_unit() -> String:
	var best := -1
	var who := ""
	for k in expedition_units:
		var c: Dictionary = crew.get(k, {})
		if c.get("alive", false) and int(c.get("intelligence", 0)) > best:
			best = int(c.get("intelligence", 0))
			who = k
	return who

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
		"pending_event_threshold": pending_event_threshold,
		"jump_origin_hex": jump_origin_hex, "jump_dest_hex": jump_dest_hex,
		"pending_event_para": pending_event_para, "surfaces_visited": surfaces_visited,
		"manual_dice": manual_dice,
		"crew": crew, "visited_systems": visited_systems, "log_entries": log_entries,
		"vp_ledger": vp_ledger,
		"planet_attrs": planet_attrs, "planet_gravity": planet_gravity,
		"shuttle_capacity": shuttle_capacity, "expedition_units": expedition_units,
		"expedition_gear": expedition_gear, "damaged_gear": damaged_gear,
		"planned_supply": planned_supply,
		"supply_track_pos": supply_track_pos, "pending_supply_checks": pending_supply_checks,
		"current_creature": current_creature, "creature_rating": creature_rating,
		"damage_points": damage_points, "captured_creatures": captured_creatures,
		"acquired_artifacts": acquired_artifacts,
		"weapon_usable": weapon_usable, "intel_checks_done": intel_checks_done,
		"pending_artifact_vp": pending_artifact_vp,
		"recorded_creatures": recorded_creatures,
		"explored_planets": explored_planets,
		"creature_attr_cache": creature_attr_cache,
		"pending_combat_shift": pending_combat_shift, "pending_no_capture": pending_no_capture,
		"pending_kill_as_capture": pending_kill_as_capture,
		"surprise_active": surprise_active, "chosen_strategy": chosen_strategy,
		"encounter_outcome_text": encounter_outcome_text,
		"environ_grid": environ_grid, "expedition_pos": expedition_pos,
		"landing_hex": landing_hex, "current_environ_id": current_environ_id,
		"hasty_path_terrains": hasty_path_terrains,
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
	pending_event_threshold = int(d.get("pending_event_threshold", 0))
	jump_origin_hex = int(d.get("jump_origin_hex", 46))
	jump_dest_hex = int(d.get("jump_dest_hex", 46))
	pending_event_para = int(d.get("pending_event_para", 0))
	surfaces_visited = int(d.get("surfaces_visited", 0))
	manual_dice = bool(d.get("manual_dice", false))
	var cr: Variant = d.get("crew", {})
	if typeof(cr) == TYPE_DICTIONARY:
		for k in cr:
			if crew.has(k):
				crew[k]["alive"] = bool(cr[k].get("alive", true))
				crew[k]["endurance"] = int(cr[k].get("endurance", MAX_ENDURANCE))
				crew[k]["intelligence"] = int(cr[k].get("intelligence", 0))
	visited_systems = d.get("visited_systems", [])
	log_entries = d.get("log_entries", [])
	vp_ledger = d.get("vp_ledger", [])
	planet_attrs = d.get("planet_attrs", {})
	planet_gravity = str(d.get("planet_gravity", "Earth like"))
	shuttle_capacity = int(d.get("shuttle_capacity", 80))
	expedition_units = d.get("expedition_units", [])
	expedition_gear = d.get("expedition_gear", [])
	damaged_gear = d.get("damaged_gear", [])
	planned_supply = int(d.get("planned_supply", 6))
	supply_track_pos = int(d.get("supply_track_pos", 0))
	pending_supply_checks = int(d.get("pending_supply_checks", 0))
	current_creature = str(d.get("current_creature", ""))
	creature_rating = int(d.get("creature_rating", 0))
	damage_points = int(d.get("damage_points", 0))
	captured_creatures = d.get("captured_creatures", [])
	acquired_artifacts = d.get("acquired_artifacts", [])
	weapon_usable = bool(d.get("weapon_usable", false))
	intel_checks_done = d.get("intel_checks_done", [])
	pending_artifact_vp = d.get("pending_artifact_vp", [])
	recorded_creatures = d.get("recorded_creatures", [])
	explored_planets = d.get("explored_planets", [])
	creature_attr_cache = {}
	var cac: Variant = d.get("creature_attr_cache", {})
	if typeof(cac) == TYPE_DICTIONARY:
		for k in cac:
			creature_attr_cache[k] = int(cac[k])
	pending_combat_shift = int(d.get("pending_combat_shift", 0))
	pending_no_capture = bool(d.get("pending_no_capture", false))
	pending_kill_as_capture = bool(d.get("pending_kill_as_capture", false))
	surprise_active = bool(d.get("surprise_active", false))
	chosen_strategy = str(d.get("chosen_strategy", ""))
	encounter_outcome_text = str(d.get("encounter_outcome_text", ""))
	environ_grid = {}
	var eg: Variant = d.get("environ_grid", {})
	if typeof(eg) == TYPE_DICTIONARY:
		for k in eg:
			environ_grid[int(k)] = eg[k]
	expedition_pos = int(d.get("expedition_pos", 0))
	landing_hex = int(d.get("landing_hex", 0))
	current_environ_id = int(d.get("current_environ_id", 0))
	hasty_path_terrains = d.get("hasty_path_terrains", [])
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
	# Memorizza l'origine e la destinazione del salto interstellare attuale: servono
	# ai paragrafi-evento (4.2) che ragionano sulla ROTTA percorsa (es. ¶064 e la
	# vicinanza all'esagono 14).
	jump_origin_hex = pandora_hex
	jump_dest_hex = hex_id
	pandora_hex = hex_id
	tour_months_used += cost

	var sys_name := GameData.get_planet_for_hex(hex_id)
	if sys_name != "":
		current_system = sys_name
		add_log("Pandora arriva a %s. Mesi usati: %d/%d." % [sys_name, tour_months_used, tour_length])
		# Determinazione dell'evento (4.0, Procedura): si tirano DUE dadi; se il
		# risultato è <= agli esagoni percorsi contando l'origine (cioè cost+1)
		# si verifica un Evento Interstellare, altrimenti si va alla Tabella Pianeti.
		pending_event_threshold = cost + 1
		if manual_dice:
			pending_die_purpose = "interstellar_check"
			awaiting_die_roll = true
			message_posted.emit("Tira due dadi per verificare se avviene un evento interstellare (regola 4.0).")
		else:
			var d := randi_range(1, 6) + randi_range(1, 6)
			die_rolled.emit(d, "interstellar_check")
			resolve_interstellar_check(d)
	else:
		current_system = ""
		add_log("Pandora si muove all'esagono %d. Mesi usati: %d/%d." % [hex_id, tour_months_used, tour_length])

	state_updated.emit()

	# Check if tour is over
	if months_remaining() <= 0:
		_end_tour()

# Soglia (cost+1) per la determinazione dell'evento interstellare (4.0).
var pending_event_threshold: int = 0
# Origine e destinazione del salto interstellare attuale (per gli eventi 4.2 che
# valutano la rotta percorsa, es. ¶064). Aggiornati a ogni move_pandora_to.
var jump_origin_hex: int = 46
var jump_dest_hex: int = 46
# Paragrafo-evento interstellare (4.2) in attesa di un tiro manuale del giocatore:
# i suoi effetti meccanici si risolvono quando arriva il dado (vedi resolve_event_die).
var pending_event_para: int = 0

# Determinazione 4.0: due dadi <= esagoni percorsi (origine inclusa) -> evento.
func resolve_interstellar_check(die: int) -> void:
	if die <= pending_event_threshold:
		add_log("Controllo evento interstellare (4.0): %d ≤ %d → si verifica un evento." % [die, pending_event_threshold])
		# L'evento è determinato dalla Tabella 4.2 con un secondo tiro di due dadi.
		if manual_dice:
			pending_die_purpose = "interstellar_event"
			awaiting_die_roll = true
			message_posted.emit("Tira due dadi per l'evento interstellare (regola 4.2).")
		else:
			var d := randi_range(1, 6) + randi_range(1, 6)
			die_rolled.emit(d, "interstellar_event")
			resolve_interstellar_event(d)
	else:
		add_log("Controllo evento interstellare (4.0): %d > %d → nessun evento, si va in orbita." % [die, pending_event_threshold])
		if current_system != "" and current_system != "Sol":
			enter_orbit()

func resolve_interstellar_event(die: int) -> void:
	var para := GameData.get_interstellar_event_para(die)
	if para > 0:
		add_log("Evento interstellare! (2 dadi: %d) → Paragrafo %03d" % [die, para])
		show_paragraph(para)
		# Applica gli effetti meccanici interni del paragrafo-evento (4.2).
		_apply_interstellar_event_effect(para)
	else:
		# Con la Tabella 4.2 corretta (2-12) ogni risultato ha un paragrafo;
		# questo ramo è una salvaguardia: in assenza di voce si va in orbita.
		add_log("Nessuna voce in Tabella Eventi per il risultato %d." % die)
		if current_system != "" and current_system != "Sol":
			enter_orbit()

# --- Interprete degli effetti dei paragrafi-evento interstellari (regola 4.2) ---
#
# Ogni evento della Tabella 4.2 (080, 061, 055, 049, 046, 001, 044, 047, 052, 058,
# 064) ha effetti meccanici descritti nel suo paragrafo: mesi di Tour extra, morti
# casuali, controlli di Intelligenza, morte di creature catturate, salti ad altri
# paragrafi. Questo metodo li applica DOPO che il testo è stato mostrato.
#
# Gli eventi che richiedono un tiro del giocatore vengono messi in coda
# (pending_event_para) se manual_dice è attivo e risolti in resolve_event_die quando
# arriva il dado; altrimenti il dado è tirato automaticamente qui.
func _apply_interstellar_event_effect(para: int) -> void:
	match para:
		1:   _event_001()
		44:  _event_044()
		46:  _event_046()
		47:  _event_047()
		49:  _event_049()
		52:  _event_052()
		55:  _event_055()
		58:  _event_058()
		61:  _event_061()
		64:  _event_064()
		80:  _event_080()
		_:
			# Nessun effetto meccanico noto per questo paragrafo: resta narrativo.
			pass

# Spende mesi di Tour extra (4.2/4.6); se così facendo il Tour si esaurisce, lo chiude.
func _spend_tour_months(n: int, reason: String) -> void:
	if n <= 0:
		return
	tour_months_used += n
	add_log("%s: +%d Mese/i di Tour (rimangono %d)." % [reason, n, months_remaining()])
	state_updated.emit()
	if months_remaining() <= 0:
		_end_tour()

# Vero se il personaggio (chiave ufficiale) è vivo e a bordo della Pandora.
# In fase interstellare/orbita l'intero equipaggio vivo è considerato a bordo.
func _officer_aboard(key: String) -> bool:
	return crew.get(key, {}).get("alive", false)

# Determina il Valore (8.4) di un attributo per una creatura catturata a bordo:
# 2d6 + modificatore della scheda, mappato con la RATING_TABLE (come creature_attr).
func _aboard_creature_rating(name: String, attr: String) -> int:
	var modn := int(GameData.get_creature(name).get(attr, 0))
	var total := clampi(randi_range(1, 6) + randi_range(1, 6) + modn, 2, 12)
	if total <= 11:
		return int(RATING_TABLE.get(total, 1))
	var d := randi_range(1, 6)
	return 9 if d <= 2 else (10 if d <= 4 else (11 if d == 5 else 12))

# ¶001 — errore di navigazione: se il salto attuale è ≥3 esagoni (origine inclusa)
# si spende un Mese di Tour extra; altrimenti nessun evento.
func _event_001() -> void:
	var dist := GameData.get_hex_distance(jump_origin_hex, jump_dest_hex) + 1  # +1: origine inclusa
	if dist >= 3:
		_spend_tour_months(1, "¶001 errore di navigazione (salto di %d esagoni)" % dist)
	else:
		add_log("¶001: salto di %d esagoni (≤2) → nessun effetto." % dist)

# ¶044 — sforzo sui sistemi FTL. Con l'ufficiale alla manutenzione a bordo si tirano
# due dadi contro la sua Intelligenza; altrimenti 4 mesi fissi.
func _event_044() -> void:
	if not _officer_aboard("MntO"):
		_spend_tour_months(4, "¶044 sforzo FTL (manutenzione assente)")
		return
	if manual_dice:
		pending_event_para = 44
		pending_die_purpose = "event_044"
		awaiting_die_roll = true
		message_posted.emit("¶044: tira due dadi contro l'Intelligenza dell'Ufficiale Manutenzione.")
	else:
		_resolve_044(randi_range(1, 6) + randi_range(1, 6))

func _resolve_044(roll: int) -> void:
	var intel := character_intelligence("MntO")
	if roll <= intel:
		_spend_tour_months(1, "¶044 riparazione FTL (%d ≤ Int %d)" % [roll, intel])
	else:
		var months := mini(roll - intel, 4)
		_spend_tour_months(months, "¶044 danno FTL (%d > Int %d)" % [roll, intel])

# ¶046 — brillamenti stellari: un Mese di Tour extra.
func _event_046() -> void:
	_spend_tour_months(1, "¶046 brillamenti stellari")

# ¶047 — avaria del Processore Fuji: 9 − (Int più alta tra scienze/manutenzione).
# L'ufficiale al rilevamento terrestre coincide con l'Ufficiale Scienze (GSO).
func _event_047() -> void:
	var best := highest_intelligence(["GSO", "MntO"])
	_spend_tour_months(maxi(0, 9 - best), "¶047 avaria Processore Fuji (9 − Int %d)" % best)

# ¶049 — tempesta di asteroidi: 9 − (Int più alta tra comandante/navigatore/manutenzione).
func _event_049() -> void:
	var best := highest_intelligence(["CO", "Nav", "MntO"])
	_spend_tour_months(maxi(0, 9 - best), "¶049 tempesta di asteroidi (9 − Int %d)" % best)

# ¶052 — supporto vitale: una creatura catturata a bordo (a caso) muore, perdendo i suoi PV.
func _event_052() -> void:
	if captured_creatures.is_empty():
		add_log("¶052: nessuna creatura a bordo, nessun effetto.")
		return
	var idx := randi_range(0, captured_creatures.size() - 1)
	var name: String = captured_creatures[idx]
	captured_creatures.remove_at(idx)
	add_log("¶052: la creatura %s muore per esigenze di supporto vitale." % name)
	var vp := GameData.creature_vp(name)
	if vp > 0:
		lose_vp(vp, "¶052 creatura %s deceduta" % name)
	state_updated.emit()

# ¶055 — danno cerebrale permanente a un membro dell'equipaggio (a caso). Tutti i
# Valori −1 (qui modelliamo solo l'Intelligenza), e l'Intelligenza −1d6; se l'Int
# scende a 2 o meno si perdono 4 PV e l'ufficio non esiste più.
func _event_055() -> void:
	if manual_dice:
		pending_event_para = 55
		pending_die_purpose = "event_055"
		awaiting_die_roll = true
		message_posted.emit("¶055: tira un dado per il danno all'Intelligenza.")
	else:
		_resolve_055(randi_range(1, 6))

func _resolve_055(roll: int) -> void:
	var living: Array = []
	for k in crew.keys():
		if crew[k].get("alive", false):
			living.append(k)
	if living.is_empty():
		return
	var key: String = living[randi_range(0, living.size() - 1)]
	var old_int := character_intelligence(key)
	var new_int := maxi(0, old_int - roll)
	crew[key]["intelligence"] = new_int
	add_log("¶055: danno cerebrale a %s — Intelligenza %d → %d (−%d)." % [
		crew[key]["name"], old_int, new_int, roll])
	# NB: gli altri Valori (Combattimento/Velocità/Porto) non sono memorizzati per
	# personaggio, quindi il «tutti i Valori −1» resta narrativo per quei valori.
	if new_int <= 2:
		lose_vp(4, "¶055 ufficio perso (%s)" % crew[key]["name"])
		add_log("¶055: %s non è più in grado di svolgere i suoi compiti (Int ≤ 2)." % crew[key]["name"])
	state_updated.emit()

# ¶058 — ceppi virali: follia dell'Ufficiale Scienze (GSO). Ignora se GSO assente o
# nessuna superficie ancora visitata. Altrimenti: 1 dado sottratto all'Int del GSO →
# tanti Punti Resistenza persi dagli altri; poi un altro dado instrada a 067/073/144.
func _event_058() -> void:
	if not _officer_aboard("GSO") or surfaces_visited <= 0:
		add_log("¶058: Ufficiale Scienze assente o nessuna superficie visitata → ignorato.")
		return
	if manual_dice:
		pending_event_para = 58
		pending_die_purpose = "event_058"
		awaiting_die_roll = true
		message_posted.emit("¶058: tira un dado (sottratto all'Intelligenza dell'Ufficiale Scienze).")
	else:
		_resolve_058(randi_range(1, 6))

func _resolve_058(roll: int) -> void:
	var intel := character_intelligence("GSO")
	var loss := maxi(0, intel - roll)
	add_log("¶058: dado %d, Int Scienze %d → %d Punti Resistenza persi dagli altri." % [roll, intel, loss])
	# Distribuisce la perdita di Resistenza tra gli ALTRI personaggi imbarcati (8.8).
	for _i in range(loss):
		var target := ""
		var best_e := 0
		for k in crew.keys():
			if k == "GSO" or not crew[k].get("alive", false):
				continue
			var e: int = int(crew[k].get("endurance", 0))
			if e > best_e:
				best_e = e
				target = k
		if target == "":
			break
		crew[target]["endurance"] = maxi(0, int(crew[target]["endurance"]) - 1)
		add_log("¶058: %s perde 1 Punto Resistenza (%d/%d)." % [
			crew[target]["name"], crew[target]["endurance"], MAX_ENDURANCE])
		if crew[target]["endurance"] <= 0 and crew[target].get("alive", false):
			crew[target]["alive"] = false
			lose_vp(10, "Personaggio ucciso: %s" % crew[target]["name"])
			add_log("%s muore per la follia dell'Ufficiale Scienze." % crew[target]["name"])
	state_updated.emit()
	# Secondo dado: instrada al paragrafo di esito (la sua meccanica segue il libro-gioco).
	var d2 := randi_range(1, 6)
	var dest := 67 if d2 <= 3 else (73 if d2 <= 5 else 144)
	add_log("¶058: secondo dado %d → ¶%03d." % [d2, dest])
	show_paragraph(dest)

# ¶061 — mercanti rinnegati: con l'Ufficiale Armi a bordo, due dadi contro la sua
# Intelligenza. Se < Int → 1 Mese extra e fuga; altrimenti (o se assente) → ¶169.
func _event_061() -> void:
	if not _officer_aboard("WO"):
		add_log("¶061: Ufficiale Armi assente → ¶169.")
		show_paragraph(169)
		return
	if manual_dice:
		pending_event_para = 61
		pending_die_purpose = "event_061"
		awaiting_die_roll = true
		message_posted.emit("¶061: tira due dadi contro l'Intelligenza dell'Ufficiale Armi.")
	else:
		_resolve_061(randi_range(1, 6) + randi_range(1, 6))

func _resolve_061(roll: int) -> void:
	var intel := character_intelligence("WO")
	if roll < intel:
		_spend_tour_months(1, "¶061 fuga dai mercanti (%d < Int %d)" % [roll, intel])
	else:
		add_log("¶061: %d ≥ Int %d → ¶169." % [roll, intel])
		show_paragraph(169)

# ¶064 — vicinanza a Opoplo (esagono 14). Se la rotta del salto attuale entra nel 14
# o in un esagono adiacente, la Pandora deve deviare verso Opoplo (¶076). Modelliamo
# il rilevamento e il dirottamento; lo schieramento di superficie segue il libro-gioco.
func _event_064() -> void:
	if not _jump_near_opoplo():
		add_log("¶064: la rotta non passa entro un esagono da Opoplo → nessun effetto.")
		return
	add_log("¶064: trasmissioni da Opoplo! La Pandora devia verso l'esagono 14.")
	# Spesa di Tempo di Tour per adattare la rotta fino a Opoplo (5.0).
	var extra := GameData.get_hex_distance(jump_dest_hex, 14)
	if extra > 0:
		_spend_tour_months(extra, "¶064 deviazione verso Opoplo")
		if current_phase == Phase.GAME_OVER:
			return
	pandora_hex = 14
	jump_dest_hex = 14
	current_system = "Opoplo"
	# La spedizione è piazzata nell'esagono 0817 e si procede al ¶076 (vedi paragrafo).
	add_log("¶064: arrivati a Opoplo (esagono 14). Organizza la spedizione (¶076).")
	enter_orbit()

# Vero se la rotta del salto attuale (origine o destinazione) è l'esagono 14 (Opoplo)
# o un esagono adiacente al 14.
func _jump_near_opoplo() -> bool:
	var near := [14]
	for h in GameData.get_adjacency(14):
		near.append(int(h) if not (h is int) else h)
	return jump_dest_hex in near or jump_origin_hex in near

# ¶080 — una creatura a bordo (a caso) si evolve. In base ai suoi Valori di
# Intelligenza/Combattimento si dirama a 081/082/083/084.
func _event_080() -> void:
	if captured_creatures.is_empty():
		add_log("¶080: nessuna creatura a bordo, nessun effetto.")
		return
	var idx := randi_range(0, captured_creatures.size() - 1)
	var name: String = captured_creatures[idx]
	var intel := _aboard_creature_rating(name, "intel")
	var combat := _aboard_creature_rating(name, "combat")
	add_log("¶080: la creatura %s si evolve (Int %d, Combat %d)." % [name, intel, combat])
	if intel > 6:
		show_paragraph(81)
		_event_081()
	elif combat > 7 and intel < 6:
		show_paragraph(82)
		_event_082()
	elif (combat == 6 or combat == 7) and intel < 6:
		show_paragraph(83)
		_event_083(name)
	else:
		show_paragraph(84)
		_event_084(name, intel, combat)

# ¶081 — la creatura uccide tutti e prende la Pandora: fine del gioco.
func _event_081() -> void:
	add_log("¶081: la creatura prende il controllo della Pandora. Il gioco è finito.")
	for k in crew.keys():
		crew[k]["alive"] = false
	set_phase(Phase.GAME_OVER)

# ¶082 — la creatura distrugge la Pandora, uccidendo tutti: fine del gioco.
func _event_082() -> void:
	add_log("¶082: la Pandora è distrutta. Il gioco è finito.")
	for k in crew.keys():
		crew[k]["alive"] = false
	set_phase(Phase.GAME_OVER)

# ¶083 — la creatura e un terzo delle creature a bordo (a caso) sono distrutte.
func _event_083(trigger: String) -> void:
	captured_creatures.erase(trigger)
	add_log("¶083: la creatura %s viene distrutta." % trigger)
	var to_kill := captured_creatures.size() / 3  # divisione intera: un terzo
	for _i in range(to_kill):
		if captured_creatures.is_empty():
			break
		var j := randi_range(0, captured_creatures.size() - 1)
		var dead: String = captured_creatures[j]
		captured_creatures.remove_at(j)
		add_log("¶083: anche %s viene distrutta." % dead)
		var vp := GameData.creature_vp(dead)
		if vp > 0:
			lose_vp(vp, "¶083 creatura %s distrutta" % dead)
	state_updated.emit()

# ¶084 — la creatura vaga in cerca di carne umana. Due dadi vs max(Combat, Int):
# ≥ valore → distrutta senza danni; < valore → la differenza è il numero di
# personaggi (a caso) uccisi prima che venga distrutta.
func _event_084(trigger: String, intel: int, combat: int) -> void:
	captured_creatures.erase(trigger)
	if manual_dice:
		pending_event_para = 84
		pending_die_purpose = "event_084"
		# Memorizza il valore di confronto nel campo creature_rating (riutilizzato).
		creature_rating = maxi(combat, intel)
		awaiting_die_roll = true
		message_posted.emit("¶084: tira due dadi contro il Valore %d della creatura." % creature_rating)
	else:
		_resolve_084(randi_range(1, 6) + randi_range(1, 6), maxi(combat, intel))

func _resolve_084(roll: int, value: int) -> void:
	if roll >= value:
		add_log("¶084: %d ≥ %d → la creatura è distrutta senza fare danni." % [roll, value])
		return
	var kills := value - roll
	add_log("¶084: %d < %d → %d personaggio/i ucciso/i." % [roll, value, kills])
	for _i in range(kills):
		var living: Array = []
		for k in crew.keys():
			if crew[k].get("alive", false):
				living.append(k)
		if living.is_empty():
			break
		var victim: String = living[randi_range(0, living.size() - 1)]
		crew[victim]["alive"] = false
		crew[victim]["endurance"] = 0
		lose_vp(10, "Personaggio ucciso: %s" % crew[victim]["name"])
		add_log("¶084: %s viene ucciso dalla creatura." % crew[victim]["name"])
	state_updated.emit()

# Risolve il tiro manuale in attesa per un paragrafo-evento interstellare (4.2).
func resolve_event_die(die: int) -> void:
	var para := pending_event_para
	pending_event_para = 0
	pending_die_purpose = ""
	match para:
		44: _resolve_044(die)
		55: _resolve_055(die)
		58: _resolve_058(die)
		61: _resolve_061(die)
		84: _resolve_084(die, creature_rating)
		_:  pass

# Ingresso in orbita: prepara gli attributi del pianeta e mostra il paragrafo
# che lo descrive (Tabella Pianeti, 5.0). Il giocatore decide se esplorare.
func enter_orbit() -> void:
	# Se il Tour è già finito (es. evento interstellare che esaurisce i mesi o
	# stermina l'equipaggio), non si rientra in orbita: la partita è conclusa.
	if current_phase == Phase.GAME_OVER:
		return
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
	# 1 PV per ogni pianeta esplorato, a prescindere da cosa vi si trovi (9.1).
	if current_system not in explored_planets:
		explored_planets.append(current_system)
		gain_vp(1, "Pianeta esplorato: %s (9.1)" % current_system)
	surfaces_visited += 1  # una nuova superficie planetaria è stata visitata (per ¶058)
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

# --- Equipaggiamento d'atmosfera (regola 5.2) --------------------------------

# Statistica EFFICACE di un personaggio (weight/speed/port) coi modificatori
# dell'equipaggiamento d'atmosfera del pianeta in orbita (5.2):
#  - Thin (rarefatta): respiratore → Porto −1.
#  - Poison (velenosa): enviorig → Peso +4, Velocità −1 (uniforme, dai segnalini).
#  - Corrosive (corrosiva): armorig → Peso +4, Porto −1 (richiesto; si assume indossato).
# Normal/None: nessun modificatore (None trattato come Normal: nessuna regola lo
# distingue qui).
func effective_char_stat(key: String, stat: String) -> int:
	var c := GameData.get_character(key)
	var base := int(c.get(stat, 0))
	var atmo := str(planet_attrs.get("atmosphere", "Normal"))
	match atmo:
		"Thin":
			if stat == "port":
				base -= 1
		"Poison":
			if stat == "weight":
				base += 4
			elif stat == "speed":
				base -= 1
		"Corrosive":
			if stat == "weight":
				base += 4
			elif stat == "port":
				base -= 1
	return base

func units_weight() -> int:
	var w := 0
	for k in expedition_units:
		w += effective_char_stat(k, "weight")  # peso efficace coi rig d'atmosfera (5.2)
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
	# Armi-artefatto acquisite (es. Arma aliena ¶006, Cattura/Uccisione 9): una volta
	# acquisite vengono portate dalla spedizione e usate come strumento (2.6), ma se
	# danneggiate (registrate in damaged_gear) non sono utilizzabili (6.9).
	for akey in acquired_artifacts:
		if akey in damaged_gear:
			continue
		# L'Arma aliena (¶006) è utilizzabile solo dopo essere stata compresa (¶006/¶175).
		if akey == "006" and not weapon_usable:
			continue
		var art := GameData.get_artifact(akey.to_int())
		var av: int = int(art.get("capture", 0)) if mode == "capture" else int(art.get("kill", 0))
		best = maxi(best, av)
	return best if best > 0 else 3

# Acquisizione di un artefatto (2.6/9.1): si raccoglie ora, ma i PV indicati sul
# retro del segnalino (linea Additional VP's) si guadagnano solo riportandolo sulla
# Pandora (vedi return_to_pandora). Se la spedizione va perduta, niente PV.
func acquire_artifact(para: int) -> bool:
	var key := "%03d" % para
	if key in acquired_artifacts:
		return false
	var a := GameData.get_artifact(para)
	if a.is_empty():
		return false
	acquired_artifacts.append(key)
	pending_artifact_vp.append(key)
	var vp := int(a.get("vp", 0))
	add_log("Artefatto raccolto: %s (¶%s). Riportalo sulla Pandora per +%d PV." % [a.get("name", key), key, vp])
	state_updated.emit()
	return true

func is_artifact_acquired(para: int) -> bool:
	return ("%03d" % para) in acquired_artifacts

# Un paragrafo offre un check Intelligenza (3.3) ancora da risolvere?
func intel_check_available(para: int) -> bool:
	return GameData.has_intel_check(para) and not (para in intel_checks_done)

# Risolve un check Intelligenza (3.3) data-driven (vedi data/intel_checks.json).
# Confronta 2d6 col Valore di Intelligenza e applica gli effetti della banda:
# acquisizione artefatto, usabilità arma, ore spese, danni.
func resolve_intel_check(para: int) -> void:
	var cfg := GameData.get_intel_check(para)
	if cfg.is_empty() or (para in intel_checks_done):
		return
	# Rimando se un'unità specifica è presente (es. ¶006 con l'Ufficiale Armi → ¶175).
	if cfg.has("if_unit_goto"):
		var ug: Dictionary = cfg["if_unit_goto"]
		if str(ug.get("unit", "")) in expedition_units:
			add_log("¶%03d: l'%s esamina l'oggetto → ¶%03d." % [para, GameData.get_character(str(ug.get("unit"))).get("name", ug.get("unit")), int(ug.get("para", 0))])
			show_paragraph(int(ug.get("para", 0)))
			return
	var v := highest_intelligence(expedition_units)
	var roll := randi_range(1, 6) + randi_range(1, 6)
	var band := "near"
	if roll < v - 1:
		band = "well_below"
	elif roll > v + 1:
		band = "well_above"
	var bands: Dictionary = cfg.get("bands", {})
	var b: Dictionary = bands.get(band, {})
	# Banda condizionata a un equipaggiamento (es. ¶030 well_below richiede la
	# E-cage): se manca, si applica la banda indicata da else_band.
	if b.has("require_gear") and not _gear_has(str(b["require_gear"])):
		band = str(b.get("else_band", band))
		b = bands.get(band, {})
	# Personaggio che «investiga» (gioco ottimale: Intelligenza più alta): alcuni
	# effetti ricadono su di lui (¶030).
	var investigator := highest_intelligence_unit() if bool(cfg.get("investigator", false)) else ""
	intel_checks_done.append(para)
	var extra: Array = []
	if b.has("hours"):
		var hv := (randi_range(1, 6) if str(b["hours"]) == "d6" else int(b["hours"]))
		if hv > 0:
			add_expedition_hours(hv)
			extra.append("%d ore" % hv)
	if b.has("damage"):
		var dv := (randi_range(1, 6) + randi_range(1, 6) if str(b["damage"]) == "2d6" else int(b["damage"]))
		if dv > 0:
			_apply_damage(dv)
			extra.append("%d Punti Danno" % dv)
	# Danno mirato all'investigatore, eventualmente annullato da un equipaggiamento
	# (es. armorig protegge dagli schizzi acidi del globo).
	if b.has("damage_investigator") and investigator != "":
		if b.has("negated_by") and _gear_has(str(b["negated_by"])):
			extra.append("%s protegge: nessun danno" % b["negated_by"])
		else:
			_damage_character(investigator, int(b["damage_investigator"]))
	# Morte dell'investigatore, ridotta a un danno se indossa un certo equipaggiamento.
	if bool(b.get("kill_investigator", false)) and investigator != "":
		if b.has("armorig_reduces_to") and _gear_has("Armorig"):
			extra.append("Armorig danneggiato")
			_damage_character(investigator, int(b["armorig_reduces_to"]))
		else:
			_kill_character(investigator)
	if bool(b.get("weapon_usable", false)):
		weapon_usable = true
	if b.has("acquire"):
		acquire_artifact(int(b["acquire"]))
	var msg := str(b.get("text", ""))
	if not extra.is_empty():
		msg += " (" + ", ".join(extra) + ")"
	add_log("¶%03d esame (Intelligenza %d, 2 dadi = %d): %s" % [para, v, roll, msg])
	message_posted.emit(msg)
	state_updated.emit()

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

# --- Interprete degli snodi «Incontro di spedizione» (regola 6.5) ------------

# Valuta le regole di uno snodo nell'ordine dato e salta al primo goto la cui
# condizione è vera. Se nessuna è vera, ri-tira la Matrice di Esplorazione (6.4)
# per ottenere un altro snodo; con una guardia anti-ricorsione, oltre il limite si
# mostra comunque il testo dello snodo corrente (fallback prudente).
func _route_expedition_encounter(snodo: int, rules: Array) -> void:
	for r in rules:
		if _exp_cond_holds(r.get("cond", {})):
			var dest := int(r.get("goto", 0))
			add_log("Incontro di spedizione ¶%03d (6.5) → condizione soddisfatta → ¶%03d." % [snodo, dest])
			show_paragraph(dest)
			return
	# Nessuna condizione vera: si ri-tira la Matrice di Esplorazione (6.5).
	if _expedition_reroll_depth >= MAX_EXPEDITION_REROLLS:
		add_log("Incontro di spedizione ¶%03d (6.5): nessuna condizione e troppi ri-tiri; mostro lo snodo." % snodo)
		_expedition_reroll_depth = 0
		_show_snodo_text(snodo)
		return
	_expedition_reroll_depth += 1
	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	var other := GameData.get_exploration_2d6(d1, d2)
	add_log("Incontro di spedizione ¶%03d (6.5): nessuna condizione vera; ri-tiro Matrice %d/%d → ¶%03d." % [snodo, d1, d2, other])
	show_paragraph(other)

# Mostra il testo grezzo di uno snodo (fallback quando si esauriscono i ri-tiri).
func _show_snodo_text(para_num: int) -> void:
	current_paragraph = para_num
	encounter_outcome_text = ""
	pending_goto = 0
	set_phase(Phase.PARAGRAPH)
	paragraph_request.emit(para_num)
	state_updated.emit()

# Vero se il terreno reale dell'esagono attualmente esplorato/occupato è `real`.
func _current_terrain_is(real: String) -> bool:
	var cell: Dictionary = environ_grid.get(expedition_pos, {})
	return GameData.terrain_real(cell.get("terrain", "Open")) == real

# Vero se `real` è stato attraversato durante l'ultimo movimento affrettato (6.3).
func _hasty_has(real: String) -> bool:
	return real in hasty_path_terrains

# L'esagono attuale ha vegetazione (terreno rado o fitto).
func _current_has_vegetation() -> bool:
	return _current_terrain_is("Light Vegetation") or _current_terrain_is("Heavy Vegetation")

# Esiste un esagono Alien City non esplorato nell'area (6.5).
func _unexplored_alien_city_in_area() -> bool:
	for hid in environ_grid:
		var cell: Dictionary = environ_grid[hid]
		if GameData.terrain_real(cell.get("terrain", "Open")) == "Alien City" and not cell.get("explored", false):
			return true
	return false

# Valuta una condizione di snodo. Il dizionario contiene UNA chiave (o "all" per
# combinare in AND). Le sotto-feature non modellate e il clima → FALSE (prudenza).
func _exp_cond_holds(cond: Dictionary) -> bool:
	if cond.has("all"):
		for c in cond["all"]:
			if not _exp_cond_holds(c):
				return false
		return true
	if cond.has("terrain"):
		return _current_terrain_is(str(cond["terrain"]))
	if cond.has("terrain_or_hasty"):
		var t := str(cond["terrain_or_hasty"])
		return _current_terrain_is(t) or _hasty_has(t)
	if cond.has("terrain_in"):
		for t2 in cond["terrain_in"]:
			if _current_terrain_is(str(t2)):
				return true
		return false
	if cond.has("terrain_or_hasty_in"):
		for t3 in cond["terrain_or_hasty_in"]:
			if _current_terrain_is(str(t3)) or _hasty_has(str(t3)):
				return true
		return false
	if cond.has("gravity"):
		return str(planet_attrs.get("gravity", planet_gravity)) in cond["gravity"]
	if cond.has("atmosphere"):
		return str(planet_attrs.get("atmosphere", "Normal")) in cond["atmosphere"]
	if cond.has("geology"):
		return str(planet_attrs.get("geology", "Quiet")) == str(cond["geology"])
	if cond.has("hydro"):
		var h := int(planet_attrs.get("hydro", 0))
		for hv in cond["hydro"]:
			if int(hv) == h:
				return true
		return false
	if cond.has("vegetation"):
		return _current_has_vegetation()
	if cond.has("vegetation_or_hasty"):
		return _current_has_vegetation() or _hasty_has("Light Vegetation") or _hasty_has("Heavy Vegetation")
	if cond.has("no_vegetation"):
		return not _current_has_vegetation()
	if cond.has("landing_hex"):
		return expedition_pos == landing_hex
	if cond.has("robot_in_expedition"):
		for k in expedition_gear:
			if GameData.get_bot_keys().has(k):
				return true
		return false
	if cond.has("not_immersion_underground"):
		# La spedizione non è mai in immersione né sottoterra nel modello attuale: vero.
		return true
	if cond.has("unexplored_alien_city_in_area"):
		return _unexplored_alien_city_in_area()
	# climate / climate_not / inert / _subfeature / lava_in_area: non valutabili → FALSE (6.5).
	return false

func show_paragraph(para_num: int) -> void:
	# Snodi «Incontro di spedizione» (regola 6.5): se il paragrafo è uno snodo della
	# Matrice di Esplorazione, non lo si mostra. Si valutano le sue condizioni in ordine
	# e si salta al primo goto vero; se nessuna è vera si ri-tira la Matrice (con guardia
	# anti-ricorsione). Vale solo durante una spedizione sulla superficie.
	if expedition_pos > 0:
		var rules := GameData.get_expedition_encounter(para_num)
		if not rules.is_empty():
			_route_expedition_encounter(para_num, rules)
			return
	current_paragraph = para_num
	encounter_outcome_text = ""
	pending_goto = 0
	# Una volta arrivati a un paragrafo di destinazione la catena di snodi è conclusa:
	# si azzera il contatore dei ri-tiri per la prossima esplorazione.
	_expedition_reroll_depth = 0
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
		# Un ramo «goto» rimanda subito a un altro paragrafo (rimando narrativo).
		if pending_goto > 0:
			var dest := pending_goto
			pending_goto = 0
			show_paragraph(dest)
			return
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
# Paragrafo di destinazione impostato da un ramo «goto» (rimando narrativo).
var pending_goto: int = 0
# Sorpresa (8.1) determinata all'inizio dell'incontro e leggibile dai rami dei paragrafi.
var surprise_active: bool = false
# Strategia d'incontro dichiarata dal giocatore (8.2): "communicate"|"capture_kill"|"flee".
var chosen_strategy: String = ""

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
		best = maxi(best, effective_char_stat(k, "speed"))  # velocità efficace (5.2)
	return best

func expedition_min_speed() -> int:
	var worst := 99
	for k in expedition_units:
		worst = mini(worst, effective_char_stat(k, "speed"))  # velocità efficace (5.2)
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
		var key := str(c[0])
		# Condizioni non numeriche (sorpresa 8.1 / strategia dichiarata 8.2 / equipaggiamento).
		if key == "surprised" or key == "strategy" or key == "has_gear":
			if not _cond_holds_special(key, str(c[1]), c[2]): return false
			continue
		var lhs: int = _attr_or_mod(key)
		var rhs: int = _rhs_value(c[2])
		match str(c[1]):
			"<=": if not (lhs <= rhs): return false
			">=": if not (lhs >= rhs): return false
			"<":  if not (lhs < rhs): return false
			">":  if not (lhs > rhs): return false
			"==": if not (lhs == rhs): return false
	return true

# Confronto di condizioni non numeriche dei rami (sorpresa, strategia scelta).
func _cond_holds_special(key: String, op: String, rhs) -> bool:
	if key == "surprised":
		var want := bool(rhs)
		return surprise_active == want if op == "==" else surprise_active != want
	if key == "strategy":
		var want_s := str(rhs)
		return chosen_strategy == want_s if op == "==" else chosen_strategy != want_s
	if key == "has_gear":
		# Presenza di uno strumento/robot nella spedizione (es. Neuroscan, Turbolaser).
		var present := _gear_has(str(rhs))
		return present if op == "==" else not present
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
		"goto":
			# Salto a un altro paragrafo (es. arrivo di un predatore o rimando narrativo).
			# Si memorizza la destinazione: show_paragraph la esegue dopo aver risolto
			# il paragrafo corrente, evitando ricorsione e sovrascritture della UI.
			var h0: int = int(act.get("hours", 0))
			if h0 > 0: add_expedition_hours(h0)
			# Se il salto introduce una creatura diversa (la precedente fugge), si azzera
			# lo stato d'incontro così che il paragrafo di destinazione la prepari da capo.
			if bool(act.get("new_creature", false)):
				_clear_encounter_state()
				encounter_outcome_text = ""
			pending_goto = int(act.get("para", 0))
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
			elif int(act.get("hours", 0)) > 0: add_expedition_hours(int(act["hours"]))  # ore fisse (es. E-cage ¶019)
			var nm := current_creature
			captured_creatures.append(nm)
			_record_creature_attributes(nm)
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
			_record_creature_attributes(current_creature)
			encounter_outcome_text = "Vita senziente protetta: niente combattimento. +%d PV. Scegli un'azione." % vp
			_clear_encounter_state()
		"combat", "restrategy":
			if act.has("hours_if_co_gso"):
				var inteam: bool = ("CO" in expedition_units) or ("GSO" in expedition_units)
				add_expedition_hours(int(act["hours_if_co_gso"]) if inteam else int(act.get("hours_else", 0)))
			if act.has("hours"):
				add_expedition_hours(int(act["hours"]))  # ore fisse (es. allestimento E-cage, ¶019)
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
	chosen_strategy = ""
	creature_rating = GameData.roll_creature_combat_rating(name)
	add_log("Incontro con %s! Valutazione di combattimento per l'esagono: %d." % [name, creature_rating])
	# Sorpresa (8.1): la creatura può colpire per prima. Lo Scanner riduce la probabilità.
	# Il flag resta leggibile dai rami dei paragrafi (cond lhs "surprised").
	var threshold := 1 if _gear_has("Scanner") else 2
	var sroll := randi_range(1, 6)
	surprise_active = sroll <= threshold
	if surprise_active:
		add_log("Sorpresa (8.1)! %s coglie la spedizione di sorpresa (tiro %d)." % [name, sroll])

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
		# Assegna i PV degli artefatti riportati sulla Pandora (2.6/9.1)
		if pending_artifact_vp.size() > 0:
			for akey in pending_artifact_vp:
				var av := int(GameData.get_artifact(akey.to_int()).get("vp", 0))
				if av > 0:
					gain_vp(av, "Artefatto riportato: ¶%s" % akey)
			pending_artifact_vp = []
		add_log("Ritorno alla Pandora da %s." % current_planet)
		current_planet = ""
		current_creature = ""
		creature_rating = 0
		# Termina la spedizione: azzera lo stato di superficie, altrimenti
		# expedition_pos != 0 tiene is_orbit_decision() falso e la mappa
		# strategica resta bloccata (niente «Riparti», esagoni disabilitati).
		expedition_pos = 0
		landing_hex = 0
		current_environ_id = 0
		environ_grid = {}
		set_phase(Phase.ORBIT)
		environ_changed.emit()
		# If at Sol, go to game over
		if current_system == "Sol":
			_end_tour()
		else:
			# Rimostra il pianeta in orbita: il giocatore può esplorare di nuovo
			# (altra spedizione) oppure ripartire (come al primo ingresso, 5.0).
			var para := GameData.get_planet_paragraph(current_system, tour_length)
			if para > 0:
				show_paragraph(para)

func _end_tour() -> void:
	# Guardia di rientro: un evento interstellare auto-risolto può chiamare _end_tour
	# (via _spend_tour_months) e poi far ricadere il controllo su move_pandora_to, che
	# richiamerebbe _end_tour applicando due volte le penalità di fine tour.
	if current_phase == Phase.GAME_OVER:
		return
	add_log("Tour completato! Calcolo Punti Vittoria...")
	# Regola 9.2: 1 PV perso per ogni Punto Resistenza perso dai personaggi sopravvissuti.
	var lost := 0
	for k in crew:
		if crew[k].get("alive", false):
			lost += MAX_ENDURANCE - int(crew[k].get("endurance", MAX_ENDURANCE))
	if lost > 0:
		lose_vp(lost, "Ferite dei sopravvissuti a fine tour (%d Resistenza)" % lost)
	# Regola 9.2: 5 PV persi per ogni mese oltre il Tour di Servizio scelto.
	var over := tour_months_used - tour_length
	if over > 0:
		lose_vp(over * 5, "%d mese/i oltre il Tour (9.2)" % over)
	show_paragraph(232)
	set_phase(Phase.GAME_OVER)

func gain_vp(amount: int, reason: String) -> void:
	victory_points += amount
	vp_ledger.append({"amount": amount, "reason": reason})
	add_log("VP +%d: %s (totale: %d)" % [amount, reason, victory_points])
	state_updated.emit()

func lose_vp(amount: int, reason: String) -> void:
	victory_points -= amount
	vp_ledger.append({"amount": -amount, "reason": reason})
	add_log("VP -%d: %s (totale: %d)" % [amount, reason, victory_points])
	state_updated.emit()

func add_expedition_hours(h: int) -> void:
	expedition_hours += h
	# Traccia Tempo e Rifornimento (6.8): la posizione avanza delle ore spese; ogni
	# volta che raggiunge/supera lo spazio di controllo si esegue un Controllo del
	# Rifornimento (7.0) e la posizione si azzera, continuando con le ore residue.
	# Una grande spesa può innescare più controlli (in particolare con gravità
	# opprimente): si ripete finché tutte le ore sono collocate.
	if h > 0 and expedition_pos > 0:
		_advance_supply_track(h)
	state_updated.emit()
	if expedition_hours >= 12:
		add_log("ATTENZIONE: 12+ ore di spedizione! Tornare allo shuttle!")

# --- Traccia Tempo e Rifornimento (6.8 / 7.0) --------------------------------

# Spazio del Controllo del Rifornimento per la gravità del pianeta in orbita (6.8).
func supply_check_space() -> int:
	var g := str(planet_attrs.get("gravity", planet_gravity))
	return int(SUPPLY_CHECK_SPACE.get(g, 16))

# Fa avanzare la posizione sulla Traccia delle ore indicate, innescando un Controllo
# del Rifornimento ogni volta che si raggiunge/supera lo spazio di controllo (6.8).
func _advance_supply_track(h: int) -> void:
	var space := supply_check_space()
	supply_track_pos += h
	# Ciclo: ogni volta che la posizione raggiunge/supera lo spazio si esegue un
	# controllo e si azzera la posizione, conservando le ore residue (loop multiplo).
	while supply_track_pos >= space:
		supply_track_pos -= space
		_request_supply_check()

# Avvia un Controllo del Rifornimento (7.2): col dado automatico lo risolve subito,
# coi tiri manuali lo mette in coda e attende il dado del giocatore (GameScreen).
func _request_supply_check() -> void:
	if manual_dice:
		pending_supply_checks += 1
		# Se non c'è già un altro tiro in attesa, chiede al giocatore di tirare.
		if not awaiting_die_roll:
			pending_die_purpose = "supply_check"
			awaiting_die_roll = true
			message_posted.emit("Controllo del Rifornimento (7.2): tira un dado.")
	else:
		resolve_supply_check(randi_range(1, 6))

# Risolve un Controllo del Rifornimento in coda col dado del giocatore (tiri manuali):
# scala la coda e, se restano altri controlli, ri-arma la richiesta del dado (6.8).
func resolve_pending_supply_check(die: int) -> void:
	if pending_supply_checks > 0:
		pending_supply_checks -= 1
	resolve_supply_check(die)
	if pending_supply_checks > 0:
		pending_die_purpose = "supply_check"
		awaiting_die_roll = true
		message_posted.emit("Controllo del Rifornimento (7.2): tira un dado.")
	else:
		pending_die_purpose = ""

# Controllo del Rifornimento (regola 7.2): un unico dado applicato a due calcoli.
# 1) floor(Totale Utenti / dado) Punti Rifornimento spesi — al massimo 4.
# 2) somma = Valore Supporto Vitale (lsv) + Modificatori di Rifornimento del terreno
#    dell'esagono occupato; se > 0, floor(somma / dado) Punti aggiuntivi — al massimo 4.
# Il totale viene speso dai Rifornimenti; l'eventuale ammanco è pagato in Resistenza (7.3).
func resolve_supply_check(die: int) -> void:
	if die <= 0:
		die = 1
	var users := supply_user_total()
	var calc1 := mini(int(users / die), 4)
	var lsv := int(planet_attrs.get("lsv", 0))
	var cell: Dictionary = environ_grid.get(expedition_pos, {})
	var terr_supply := int(GameData.terrain_effect(cell.get("terrain", "Open")).get("supply", 0))
	var summ := lsv + terr_supply
	var calc2 := mini(int(summ / die), 4) if summ > 0 else 0
	var total := calc1 + calc2
	add_log("Controllo Rifornimento (7.2): dado %d · Utenti %d → %d · (LSV %d + terreno %d = %d) → %d · totale %d." % [
		die, users, calc1, lsv, terr_supply, summ, calc2, total])
	_expend_supply(total)
	state_updated.emit()

# Totale degli Utenti di Rifornimento della spedizione (regola 7.1):
# ogni personaggio conta DUE volte; ogni robot in spedizione (non sullo shuttle)
# UNA volta; ogni strumento con simbolo di rifornimento UNA volta; il Rover conta
# DOPPIO se la spedizione lo usa. Robot/strumenti danneggiati e creature catturate
# non contano.
# NB: i dati non hanno un flag «simbolo di rifornimento» per strumento, quindi si
# contano una volta tutti gli strumenti non danneggiati (assunzione documentata).
func supply_user_total() -> int:
	var total := 0
	for k in expedition_units:
		if crew.get(k, {}).get("alive", false):
			total += 2  # personaggio: doppio (7.1)
	for k in expedition_gear:
		if k in damaged_gear:
			continue  # danneggiati non contano (7.1)
		if k == "Rover":
			total += 2  # il Rover conta doppio se in uso (7.1)
		elif _gear_is_bot(k):
			total += 1  # robot in spedizione: singolo (7.1)
		else:
			total += 1  # strumento (assunzione: tutti col simbolo di rifornimento)
	return total

# Spende i Punti Rifornimento del Controllo; l'eventuale ammanco diventa Punti
# Resistenza tramite il consueto percorso di danno (7.3 / 8.8): 1 Punto = 1 Resistenza.
func _expend_supply(points: int) -> void:
	if points <= 0:
		return
	if expedition_supply >= points:
		expedition_supply -= points
		add_log("Spesi %d Punti Rifornimento (rimasti %d)." % [points, expedition_supply])
	else:
		var short := points - expedition_supply
		if expedition_supply > 0:
			add_log("Spesi %d Punti Rifornimento: rifornimenti esauriti." % expedition_supply)
		expedition_supply = 0
		add_log("Rifornimenti insufficienti (7.3): %d Punti pagati in Resistenza." % short)
		_apply_damage(short)

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
	hasty_path_terrains = []
	_expedition_reroll_depth = 0
	# La Traccia Tempo e Rifornimento (6.8) riparte da capo a ogni nuova spedizione.
	supply_track_pos = 0
	pending_supply_checks = 0

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
	# Esplorazione dell'esagono occupato: nuova azione, niente percorso affrettato (6.5).
	hasty_path_terrains = []
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
	# Memorizza i terreni reali attraversati lungo il percorso più economico: servono
	# alla variante «oppure vi si è entrati durante il movimento affrettato» (6.5).
	hasty_path_terrains = _hasty_path_terrains(expedition_pos, hex_id)
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

# Ricostruisce i terreni reali (es. "Mountain") attraversati lungo il percorso più
# economico di un movimento affrettato (escluso l'esagono di partenza, incluso l'arrivo).
# Usa lo stesso costo d'ingresso di _hasty_path_cost (Dijkstra con predecessori).
func _hasty_path_terrains(from_hex: int, to_hex: int) -> Array:
	var dist := {from_hex: 0}
	var prev := {}
	var queue := [from_hex]
	while queue.size() > 0:
		var bi := 0
		for i in range(1, queue.size()):
			if dist[queue[i]] < dist[queue[bi]]:
				bi = i
		var cur: int = queue[bi]
		queue.remove_at(bi)
		if cur == to_hex:
			break
		for nb in environ_neighbors(cur):
			if not environ_grid.has(nb):
				continue
			var nterr: String = environ_grid[nb].get("terrain", "Open")
			var nd: int = dist[cur] + enter_cost_for(nterr)
			if not dist.has(nb) or nd < dist[nb]:
				dist[nb] = nd
				prev[nb] = cur
				if not (nb in queue):
					queue.append(nb)
	# Risali la catena dei predecessori fino alla partenza, raccogliendo i terreni reali.
	var terrains: Array = []
	if not prev.has(to_hex) and to_hex != from_hex:
		return terrains
	var node: int = to_hex
	while node != from_hex and prev.has(node):
		var t: String = environ_grid.get(node, {}).get("terrain", "Open")
		var real := GameData.terrain_real(t)
		if not (real in terrains):
			terrains.append(real)
		node = prev[node]
	return terrains

func move_expedition(hex_id: int) -> void:
	if not can_move_expedition(hex_id):
		return
	# Un movimento normale azzera la traccia del movimento affrettato (nuova azione, 6.5).
	hasty_path_terrains = []
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
	# Il consumo di rifornimenti non è più legato direttamente al terreno: avviene
	# tramite il Controllo del Rifornimento (7.0), innescato dalle ore sulla Traccia
	# Tempo (6.8) in add_expedition_hours; il Modificatore di Rifornimento del terreno
	# alimenta il calcolo 2 del controllo (7.2), non aggiunge/toglie scorte direttamente.
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
	chosen_strategy = strategy
	var sname0: String = {"communicate": "Comunica", "capture_kill": "Cattura/Uccidi", "flee": "Fuggi"}.get(strategy, strategy)
	# Alcuni paragrafi d'incontro intro (es. ¶009 «tartaruga») descrivono un esito
	# specifico per una certa strategia: se il paragrafo corrente ha rami che
	# combaciano con la strategia scelta, si risolvono direttamente, scavalcando
	# la Tabella di Strategia d'Incontro.
	if not GameData.get_paragraph_logic(current_paragraph).is_empty():
		resolve_encounter_outcome(current_paragraph)
		if pending_goto > 0:
			var dest := pending_goto
			pending_goto = 0
			add_log("Strategia «%s»: il paragrafo %03d rimanda al ¶%03d." % [sname0, current_paragraph, dest])
			show_paragraph(dest)
			return
		if encounter_outcome_text != "":
			add_log("Strategia «%s»: esito specifico del paragrafo %03d." % [sname0, current_paragraph])
			state_updated.emit()
			return
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
	add_log("Strategia «%s»: dado %d %+d = %d → Paragrafo %03d." % [sname0, roll, modifier, die, para])
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
	_record_creature_attributes(name)
	add_log("%s catturata viva! (riportala alla Pandora per i PV)" % name)
	_end_encounter()

func _kill_creature(name: String) -> void:
	_record_creature_attributes(name)
	add_log("%s eliminata." % name)
	_end_encounter()

# Registra un tipo di creatura sul Registro degli Attributi (9.1): la prima volta
# che la si studia (uccisione/cattura/studio) si guadagna 1 PV per ogni modificatore
# di attributo pari a zero (il «*» del segnalino: Intelligenza/Combattimento/Aggressività/Velocità).
func _record_creature_attributes(name: String) -> void:
	if name.is_empty() or name in recorded_creatures:
		return
	recorded_creatures.append(name)
	var c := GameData.get_creature(name)
	var zeros := 0
	for a in ["intel", "combat", "aggression", "speed"]:
		if int(c.get(a, -1)) == 0:
			zeros += 1
	if zeros > 0:
		gain_vp(zeros, "Attributi a zero registrati: %s (%d × «*», 9.1)" % [name, zeros])

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

# Danno mirato a uno specifico personaggio (es. ¶030: chi investiga il globo):
# perde `points` Punti Resistenza; se arriva a zero viene ucciso.
func _damage_character(key: String, points: int) -> void:
	if not crew.get(key, {}).get("alive", false):
		return
	damage_points += points
	crew[key]["endurance"] = maxi(0, int(crew[key].get("endurance", MAX_ENDURANCE)) - points)
	add_log("%s subisce %d Punti Danno (Resistenza %d/%d)." % [
		crew[key]["name"], points, crew[key]["endurance"], MAX_ENDURANCE])
	if crew[key]["endurance"] <= 0:
		_kill_character(key)
	state_updated.emit()

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
