extends Control

var left_panel: Panel
var center_panel: Panel
var right_panel: Panel
var interstellar_display: Control
var paragraph_display: Control
var log_display: RichTextLabel
var status_display: Control
var dice_panel: Control
var current_para_num: int = 0

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_display()
	# Ripristina la visualizzazione corrente al (ri)entro nella scena
	if not GameState.current_creature.is_empty():
		_on_encounter_started(GameState.current_creature)
	elif GameState.current_paragraph > 0 and GameState.current_phase == GameState.Phase.PARAGRAPH:
		_on_paragraph_request(GameState.current_paragraph)
	_update_action_buttons(GameState.phase_name(GameState.current_phase))

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main HBoxContainer
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 4; hbox.offset_top = 4
	hbox.offset_right = -4; hbox.offset_bottom = -4
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	# LEFT PANEL - Interstellar/Expedition Display
	left_panel = Panel.new()
	left_panel.custom_minimum_size = Vector2(490, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_panel)

	interstellar_display = Control.new()
	interstellar_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_panel.add_child(interstellar_display)
	interstellar_display.draw.connect(_draw_interstellar)

	# LEFT PANEL title
	var left_title := Label.new()
	left_title.text = "Mappa Interstellare"
	left_title.position = Vector2(10, 5)
	left_title.add_theme_font_size_override("font_size", 13)
	left_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	interstellar_display.add_child(left_title)

	# Draw hex buttons
	_build_hex_buttons()

	# CENTER PANEL - Log + Paragraph
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(center_vbox)

	# Phase label
	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "Fase: Interstellare"
	phase_label.add_theme_font_size_override("font_size", 12)
	phase_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	center_vbox.add_child(phase_label)

	# Paragraph display
	center_panel = Panel.new()
	center_panel.name = "ParagraphPanel"
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.custom_minimum_size = Vector2(0, 300)
	center_vbox.add_child(center_panel)

	var para_vbox := VBoxContainer.new()
	para_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	para_vbox.offset_left = 8; para_vbox.offset_top = 8
	para_vbox.offset_right = -8; para_vbox.offset_bottom = -8
	para_vbox.add_theme_constant_override("separation", 8)
	center_panel.add_child(para_vbox)

	var para_title := Label.new()
	para_title.name = "ParaTitle"
	para_title.text = "— Benvenuti a bordo della B.S.M. Pandora —"
	para_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	para_title.add_theme_font_size_override("font_size", 14)
	para_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	para_vbox.add_child(para_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	para_vbox.add_child(scroll)

	paragraph_display = RichTextLabel.new()
	paragraph_display.name = "ParagraphText"
	paragraph_display.bbcode_enabled = true
	paragraph_display.fit_content = true
	paragraph_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paragraph_display.text = "[i]Scegli la durata del tour e avvia una nuova partita.[/i]"
	paragraph_display.add_theme_font_size_override("normal_font_size", 15)
	paragraph_display.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	scroll.add_child(paragraph_display)

	# Action buttons row
	var actions_hbox := HBoxContainer.new()
	actions_hbox.name = "ActionsBox"
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 8)
	center_vbox.add_child(actions_hbox)

	var btn_orbit := Button.new()
	btn_orbit.name = "BtnOrbit"
	btn_orbit.text = "Entra in Orbita"
	btn_orbit.visible = false
	btn_orbit.pressed.connect(_on_enter_orbit)
	actions_hbox.add_child(btn_orbit)

	var btn_land := Button.new()
	btn_land.name = "BtnLand"
	btn_land.text = "Atterra (tira dado)"
	btn_land.visible = false
	btn_land.pressed.connect(_on_land)
	actions_hbox.add_child(btn_land)

	var btn_return := Button.new()
	btn_return.name = "BtnReturn"
	btn_return.text = "Torna alla Pandora"
	btn_return.visible = false
	btn_return.pressed.connect(_on_return_to_pandora)
	actions_hbox.add_child(btn_return)

	var btn_explore := Button.new()
	btn_explore.name = "BtnExplore"
	btn_explore.text = "Esplora (tira dado)"
	btn_explore.visible = false
	btn_explore.pressed.connect(_on_explore)
	actions_hbox.add_child(btn_explore)

	# Pulsanti di combattimento (visibili durante un incontro)
	var btn_kill := Button.new()
	btn_kill.name = "BtnKill"
	btn_kill.text = "Uccidi"
	btn_kill.visible = false
	btn_kill.pressed.connect(_on_combat.bind("kill"))
	actions_hbox.add_child(btn_kill)

	var btn_capture := Button.new()
	btn_capture.name = "BtnCapture"
	btn_capture.text = "Cattura"
	btn_capture.visible = false
	btn_capture.pressed.connect(_on_combat.bind("capture"))
	actions_hbox.add_child(btn_capture)

	var btn_flee := Button.new()
	btn_flee.name = "BtnFlee"
	btn_flee.text = "Fuggi"
	btn_flee.visible = false
	btn_flee.pressed.connect(_on_flee)
	actions_hbox.add_child(btn_flee)

	# Event log
	var log_panel := Panel.new()
	log_panel.custom_minimum_size = Vector2(0, 150)
	center_vbox.add_child(log_panel)

	var log_vbox := VBoxContainer.new()
	log_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_vbox.offset_left = 4; log_vbox.offset_top = 4
	log_vbox.offset_right = -4; log_vbox.offset_bottom = -4
	log_panel.add_child(log_vbox)

	var log_title := Label.new()
	log_title.text = "Registro di Bordo"
	log_title.add_theme_font_size_override("font_size", 12)
	log_title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	log_vbox.add_child(log_title)

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_vbox.add_child(log_scroll)

	log_display = RichTextLabel.new()
	log_display.name = "LogDisplay"
	log_display.bbcode_enabled = true
	log_display.fit_content = false
	log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_display.custom_minimum_size = Vector2(0, 100)
	log_display.add_theme_font_size_override("normal_font_size", 12)
	log_display.add_theme_color_override("default_color", Color(0.8, 0.9, 0.8))
	log_scroll.add_child(log_display)

	# RIGHT PANEL - Status + Dice
	right_panel = Panel.new()
	right_panel.custom_minimum_size = Vector2(290, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_vbox.offset_left = 8; right_vbox.offset_top = 8
	right_vbox.offset_right = -8; right_vbox.offset_bottom = -8
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	# Status section
	var status_title := Label.new()
	status_title.text = "Stato della Missione"
	status_title.add_theme_font_size_override("font_size", 14)
	status_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	right_vbox.add_child(status_title)

	status_display = VBoxContainer.new()
	status_display.name = "StatusDisplay"
	right_vbox.add_child(status_display)

	_build_status_rows(status_display)

	var sep2 := HSeparator.new()
	right_vbox.add_child(sep2)

	# Dice section
	var dice_title := Label.new()
	dice_title.text = "Dado (1d6)"
	dice_title.add_theme_font_size_override("font_size", 14)
	dice_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	right_vbox.add_child(dice_title)

	dice_panel = VBoxContainer.new()
	dice_panel.name = "DicePanel"
	right_vbox.add_child(dice_panel)

	var dice_result_label := Label.new()
	dice_result_label.name = "DiceResult"
	dice_result_label.text = "—"
	dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_result_label.add_theme_font_size_override("font_size", 48)
	dice_result_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	dice_panel.add_child(dice_result_label)

	var roll_btn := Button.new()
	roll_btn.name = "RollBtn"
	roll_btn.text = "TIRA DADO"
	roll_btn.custom_minimum_size = Vector2(0, 50)
	roll_btn.pressed.connect(_on_roll_dice)
	dice_panel.add_child(roll_btn)

	var dice_hint := Label.new()
	dice_hint.name = "DiceHint"
	dice_hint.text = ""
	dice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_hint.add_theme_font_size_override("font_size", 12)
	dice_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	dice_panel.add_child(dice_hint)

	var sep3 := HSeparator.new()
	right_vbox.add_child(sep3)

	# VP and tour info
	var info_vbox := VBoxContainer.new()
	right_vbox.add_child(info_vbox)

	var vp_label := Label.new()
	vp_label.name = "VPLabel"
	vp_label.text = "Punti Vittoria: 0"
	vp_label.add_theme_font_size_override("font_size", 16)
	vp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	info_vbox.add_child(vp_label)

	var tour_label2 := Label.new()
	tour_label2.name = "TourLabel"
	tour_label2.text = "Tour: —"
	tour_label2.add_theme_font_size_override("font_size", 13)
	tour_label2.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	info_vbox.add_child(tour_label2)

func _build_status_rows(parent: Control) -> void:
	var rows := [
		["Position", "Sistema: —"],
		["Months",   "Mesi: 0 / 0"],
		["Supply",   "Rifornimenti: 6"],
		["ExpTime",  "Ore spedizione: 0"],
		["Planet",   "Pianeta: —"],
	]
	for row in rows:
		var lbl := Label.new()
		lbl.name = row[0]
		lbl.text = row[1]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		parent.add_child(lbl)

func _build_hex_buttons() -> void:
	for col in range(1, 5):
		var max_row := 7 if col % 2 == 1 else 6
		for row in range(1, max_row + 1):
			var hex_id := col * 10 + row
			var pos := _hex_to_screen_pos(hex_id)

			var btn := Button.new()
			btn.name = "Hex_%d" % hex_id
			btn.custom_minimum_size = Vector2(64, 64)
			btn.position = pos - Vector2(32, 32)
			btn.pressed.connect(_on_hex_clicked.bind(hex_id))

			var sys_name := GameData.get_planet_for_hex(hex_id)
			if sys_name != "" and sys_name != "Sol":
				btn.text = sys_name.substr(0, 3)  # abbreviated name
			elif sys_name == "Sol":
				btn.text = "SOL"
			else:
				btn.text = str(hex_id)

			interstellar_display.add_child(btn)

func _hex_to_screen_pos(hex_id: int) -> Vector2:
	var col := hex_id / 10
	var row := hex_id % 10
	var x := 80.0 + (col - 1) * 95.0
	var y := 80.0 + (row - 1) * 82.0
	if col % 2 == 0:
		y += 41.0  # stagger even columns
	return Vector2(x, y)

func _connect_signals() -> void:
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.state_updated.connect(_update_display)
	GameState.paragraph_request.connect(_on_paragraph_request)
	GameState.message_posted.connect(_on_message)
	GameState.encounter_started.connect(_on_encounter_started)
	GameState.encounter_ended.connect(_on_encounter_ended)

func _on_phase_changed(phase: String) -> void:
	_update_display()
	_update_action_buttons(phase)

func _update_action_buttons(phase: String) -> void:
	var btn_orbit := find_child("BtnOrbit", true, false)
	var btn_land := find_child("BtnLand", true, false)
	var btn_return := find_child("BtnReturn", true, false)
	var btn_explore := find_child("BtnExplore", true, false)
	var btn_kill := find_child("BtnKill", true, false)
	var btn_capture := find_child("BtnCapture", true, false)
	var btn_flee := find_child("BtnFlee", true, false)

	var in_combat := not GameState.current_creature.is_empty()

	if btn_orbit: btn_orbit.visible = (phase == "orbit")
	if btn_land: btn_land.visible = (phase == "orbit")
	if btn_return: btn_return.visible = (phase == "expedition" or phase == "paragraph") and not in_combat
	if btn_explore: btn_explore.visible = (phase == "expedition") and not in_combat
	if btn_kill: btn_kill.visible = in_combat
	if btn_capture: btn_capture.visible = in_combat
	if btn_flee: btn_flee.visible = in_combat

func _update_display() -> void:
	# Update status labels
	var s := GameState

	var lbl_pos := find_child("Position", true, false) as Label
	if lbl_pos: lbl_pos.text = "Sistema: %s" % s.current_system

	var lbl_months := find_child("Months", true, false) as Label
	if lbl_months: lbl_months.text = "Mesi: %d / %d (%d rimanenti)" % [s.tour_months_used, s.tour_length, s.months_remaining()]

	var lbl_supply := find_child("Supply", true, false) as Label
	if lbl_supply: lbl_supply.text = "Rifornimenti shuttle: %d  |  spedizione: %d" % [s.shuttle_supply, s.expedition_supply]

	var lbl_exp := find_child("ExpTime", true, false) as Label
	if lbl_exp: lbl_exp.text = "Ore spedizione: %d" % s.expedition_hours

	var lbl_planet := find_child("Planet", true, false) as Label
	if lbl_planet: lbl_planet.text = "Pianeta: %s" % (s.current_planet if s.current_planet != "" else "—")

	var lbl_vp := find_child("VPLabel", true, false) as Label
	if lbl_vp: lbl_vp.text = "Punti Vittoria: %d" % s.victory_points

	var lbl_tour := find_child("TourLabel", true, false) as Label
	if lbl_tour: lbl_tour.text = "Tour: %d mesi (posizione esagono %d)" % [s.tour_length, s.pandora_hex]

	var lbl_phase := find_child("PhaseLabel", true, false) as Label
	if lbl_phase:
		var phase_it := {
			"main_menu":    "Menu Principale",
			"interstellar": "Viaggio Interstellare",
			"orbit":        "In Orbita",
			"expedition":   "Spedizione Planetaria",
			"paragraph":    "Evento",
			"game_over":    "Fine del Tour"
		}
		lbl_phase.text = "Fase: %s" % phase_it.get(GameState.phase_name(GameState.current_phase), "—")

	# Refresh hex buttons
	_refresh_hex_buttons()

func _refresh_hex_buttons() -> void:
	for col in range(1, 5):
		var max_row := 7 if col % 2 == 1 else 6
		for row in range(1, max_row + 1):
			var hex_id := col * 10 + row
			var btn := find_child("Hex_%d" % hex_id, true, false) as Button
			if not btn: continue

			if hex_id == GameState.pandora_hex:
				btn.modulate = Color(0.3, 0.8, 1.0)
			elif GameData.get_planet_for_hex(hex_id) != "":
				var can_reach := GameState.can_move_to(hex_id)
				btn.modulate = Color(1.0, 0.8, 0.2) if can_reach else Color(0.5, 0.4, 0.1)
			else:
				if GameState.can_move_to(hex_id):
					btn.modulate = Color(0.7, 0.7, 0.8)
				else:
					btn.modulate = Color(0.35, 0.35, 0.4)

			btn.disabled = (GameState.current_phase != GameState.Phase.INTERSTELLAR)

func _draw_interstellar() -> void:
	pass  # hex buttons handle display; could add draw lines between hexes later

func _on_hex_clicked(hex_id: int) -> void:
	if GameState.current_phase != GameState.Phase.INTERSTELLAR:
		return
	var sys_name := GameData.get_planet_for_hex(hex_id)
	var dist := GameData.get_hex_distance(GameState.pandora_hex, hex_id)

	if not GameState.can_move_to(hex_id):
		_post_message("Troppo lontano! Distanza: %d mesi, disponibili: %d" % [dist, GameState.months_remaining()])
		return

	# Confirm and move
	GameState.move_pandora_to(hex_id)

	if sys_name != "" and sys_name != "Sol":
		_update_action_buttons("orbit")

	_update_display()

func _on_enter_orbit() -> void:
	GameState.set_phase(GameState.Phase.ORBIT)
	var sys := GameState.current_system
	var para_key := str(GameState.tour_length)
	var sys_data := GameData.get_star_system_data(sys)
	var planet_para_str: String = sys_data.get("planet_para", {}).get(para_key, "")
	if planet_para_str != "":
		var para_num := planet_para_str.to_int()
		GameState.show_paragraph(para_num)
		_update_action_buttons("orbit")

func _on_land() -> void:
	if GameState.current_phase != GameState.Phase.ORBIT:
		return
	var die := randi_range(1, 6)
	_set_dice_result(die)
	GameState.land_on_planet(die)

func _on_return_to_pandora() -> void:
	GameState.return_to_pandora()

func _on_explore() -> void:
	if GameState.current_phase != GameState.Phase.EXPEDITION:
		return
	if not GameState.current_creature.is_empty():
		return
	# Esplorazione: tira il dado, ogni esplorazione costa 2 ore
	var die := randi_range(1, 6)
	_set_dice_result(die)
	GameState.add_expedition_hours(2)
	# Con dado alto si incontra una creatura (regola 8.0), altrimenti paragrafo evento
	if die >= 5:
		var names := GameData.get_all_creature_names()
		var creature: String = names[randi() % names.size()]
		GameState.add_log("Esplorazione (dado %d): qualcosa si avvicina..." % die)
		GameState.set_phase(GameState.Phase.EXPEDITION)
		GameState.start_encounter(creature)
	else:
		var terrain := "Open"
		var para_num := GameData.get_exploration_paragraph(terrain, die)
		GameState.add_log("Esplorazione: dado %d → Paragrafo %03d" % [die, para_num])
		GameState.show_paragraph(para_num)

func _on_combat(mode: String) -> void:
	if GameState.current_creature.is_empty():
		return
	# Valore di combattimento del personaggio (semplificato per il prototipo): 3
	var player_combat := 3
	GameState.resolve_combat(mode, player_combat)
	# Aggiorna il pannello (l'incontro può essere finito)
	if GameState.current_creature.is_empty():
		_show_expedition_panel()
	else:
		_on_encounter_started(GameState.current_creature)

func _on_flee() -> void:
	GameState.flee_encounter()
	_show_expedition_panel()

func _on_encounter_started(creature_name: String) -> void:
	var cdata := GameData.get_creature(creature_name)
	var title_lbl := find_child("ParaTitle", true, false) as Label
	if title_lbl: title_lbl.text = "Incontro: %s" % creature_name

	var para_display := find_child("ParagraphText", true, false) as RichTextLabel
	if para_display:
		var bb := ""
		var tex_path := "res://assets/creatures/%s.png" % cdata.get("img", "")
		if ResourceLoader.exists(tex_path):
			bb += "[center][img=160]" + tex_path + "[/img][/center]\n\n"
		bb += "[center][b]%s[/b][/center]\n\n" % creature_name
		bb += "Valutazione di combattimento per questo esagono: [b]%d[/b]\n\n" % GameState.creature_rating
		bb += "Modificatori — Intelligenza: %d · Combattimento: %d · Aggressività: %d · Velocità: %d\n\n" % [
			cdata.get("intel", 0), cdata.get("combat", 0), cdata.get("aggression", 0), cdata.get("speed", 0)
		]
		bb += "[i]Scegli: Uccidi, Cattura (per PV extra) o Fuggi.[/i]"
		para_display.bbcode_text = bb

	_update_action_buttons("expedition")

func _on_encounter_ended() -> void:
	_show_expedition_panel()

func _show_expedition_panel() -> void:
	var title_lbl := find_child("ParaTitle", true, false) as Label
	if title_lbl: title_lbl.text = "— Spedizione su %s —" % GameState.current_planet

	var para_display := find_child("ParagraphText", true, false) as RichTextLabel
	if para_display:
		var bb := "Esplora la superficie per trovare creature, artefatti e forme di vita.\n\n"
		bb += "Ore di spedizione: [b]%d[/b]  ·  Rifornimenti: [b]%d[/b]  ·  Danni: [b]%d[/b]\n\n" % [
			GameState.expedition_hours, GameState.expedition_supply, GameState.damage_points
		]
		if GameState.captured_creatures.size() > 0:
			bb += "Creature catturate: %s\n\n" % ", ".join(GameState.captured_creatures)
		bb += "[i]Premi \"Esplora\" per continuare, oppure \"Torna alla Pandora\".[/i]"
		para_display.bbcode_text = bb

	_update_action_buttons("expedition")

func _on_roll_dice() -> void:
	var die := randi_range(1, 6)
	_set_dice_result(die)

	if GameState.awaiting_die_roll:
		GameState.awaiting_die_roll = false
		match GameState.pending_die_purpose:
			"interstellar_event":
				GameState.resolve_interstellar_event(die)
			"landing":
				GameState.land_on_planet(die)

func _set_dice_result(val: int) -> void:
	var lbl := find_child("DiceResult", true, false) as Label
	if lbl: lbl.text = str(val)

func _on_paragraph_request(para_num: int) -> void:
	current_para_num = para_num
	var text := GameData.get_paragraph_text(para_num)

	var title_lbl := find_child("ParaTitle", true, false) as Label
	if title_lbl: title_lbl.text = "Paragrafo %03d" % para_num

	var para_display := find_child("ParagraphText", true, false) as RichTextLabel
	if para_display:
		var bb := ""
		# Illustrazione originale dell'evento (se presente)
		var img_path := GameData.get_event_image_path(para_num)
		if not img_path.is_empty():
			bb += "[center][img=320]" + img_path + "[/img][/center]\n\n"
		bb += "[p]" + text + "[/p]"
		para_display.bbcode_text = bb

	_update_action_buttons(GameState.phase_name(GameState.current_phase))

func _on_message(msg: String) -> void:
	if log_display:
		log_display.append_text("\n[color=#aaffaa]▸[/color] " + msg)

	var hint_lbl := find_child("DiceHint", true, false) as Label
	if hint_lbl and GameState.awaiting_die_roll:
		hint_lbl.text = msg

func _post_message(msg: String) -> void:
	if log_display:
		log_display.append_text("\n[color=#ffaa44]►[/color] " + msg)
