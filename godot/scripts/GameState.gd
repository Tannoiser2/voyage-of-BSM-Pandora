extends Node

signal phase_changed(new_phase: String)
signal state_updated
signal paragraph_request(para_num: int)
signal message_posted(msg: String)

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
		add_log("Ritorno alla Pandora da %s." % current_planet)
		current_planet = ""
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
