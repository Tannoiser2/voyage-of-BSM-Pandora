extends Control

var left_panel: Panel
var center_panel: Panel
var right_panel: Panel
var interstellar_display: Control
var environ_display: Control
var env_scroll: ScrollContainer
var env_canvas: Control
var env_map: TextureRect
var env_loaded_id: int = 0
var paragraph_display: Control
var log_display: RichTextLabel
var status_display: Control
var dice_panel: Control
var current_para_num: int = 0
var _prep_updating: bool = false
var choices_box: VBoxContainer

# Fattore di scala con cui la mappa reale dell'environ viene mostrata nel pannello.
# 1.0 = dimensione nativa del rendering; valori < 1 rimpiccioliscono. La vista è
# scrollabile e si centra automaticamente sulla posizione della spedizione.
const ENVIRON_DISPLAY_SCALE := 0.62

# Overlay della mappa interstellare reale (Voyage Map.jpg)
# Coordinate ricavate per calibrazione dai cerchi dei sistemi stellari sull'originale.
const INTER_REGION := Rect2(34, 1346, 336, 656)
const INTER_SCALE := 1.26
const INTER_OFFSET := Vector2(33, 36)
const GRID_BASE := Vector2(82, 1399)   # centro esagono 11 in pixel mappa
const GRID_DX := 81.0                   # passo orizzontale (calibrato sui dischi-sistema)
const GRID_DY := 92.0
const GRID_EVEN_OFFSET := 45.0

func _ready() -> void:
	_build_ui()
	_build_prep_panel()
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

	# Sfondo: ritaglio reale del Display Interstellare dalla mappa originale
	var inter_bg := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/map/Voyage Map.jpg")
	atlas.region = INTER_REGION
	inter_bg.texture = atlas
	inter_bg.position = INTER_OFFSET
	inter_bg.size = INTER_REGION.size * INTER_SCALE
	inter_bg.stretch_mode = TextureRect.STRETCH_SCALE
	interstellar_display.add_child(inter_bg)

	# LEFT PANEL title
	var left_title := Label.new()
	left_title.text = "Mappa Interstellare"
	left_title.position = Vector2(10, 6)
	left_title.add_theme_font_size_override("font_size", 13)
	left_title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	interstellar_display.add_child(left_title)

	# Draw hex buttons
	_build_hex_buttons()

	# Environ (superficie planetaria) — sovrapposto, nascosto finché non si sbarca
	environ_display = Control.new()
	environ_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	environ_display.visible = false
	left_panel.add_child(environ_display)

	# Vista scrollabile con la mappa reale dell'environ
	env_scroll = ScrollContainer.new()
	env_scroll.name = "EnvScroll"
	env_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	env_scroll.offset_left = 4
	env_scroll.offset_top = 26
	env_scroll.offset_right = -4
	env_scroll.offset_bottom = -4
	environ_display.add_child(env_scroll)

	env_canvas = Control.new()
	env_canvas.name = "EnvCanvas"
	env_scroll.add_child(env_canvas)

	env_map = TextureRect.new()
	env_map.name = "EnvMap"
	env_map.position = Vector2.ZERO
	env_map.stretch_mode = TextureRect.STRETCH_SCALE
	env_canvas.add_child(env_map)

	var env_title := Label.new()
	env_title.name = "EnvironTitle"
	env_title.text = "Superficie Planetaria"
	env_title.position = Vector2(10, 5)
	env_title.add_theme_font_size_override("font_size", 13)
	env_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	env_title.z_index = 10
	environ_display.add_child(env_title)

	# CENTER PANEL - Log + Paragraph
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(center_vbox)

	# Banner di fase/contesto (cosa stai facendo, dove)
	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "Viaggio Interstellare"
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 18)
	phase_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	center_vbox.add_child(phase_label)

	var hint_label := Label.new()
	hint_label.name = "HintLabel"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	center_vbox.add_child(hint_label)

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
	paragraph_display.add_theme_font_size_override("normal_font_size", 16)
	paragraph_display.add_theme_constant_override("line_separation", 4)
	paragraph_display.add_theme_color_override("default_color", Color(0.92, 0.92, 0.88))
	paragraph_display.meta_clicked.connect(_on_meta_clicked)
	scroll.add_child(paragraph_display)

	# Scelte del paragrafo (rimandi ¶NNN resi cliccabili)
	var choices_label := Label.new()
	choices_label.name = "ChoicesLabel"
	choices_label.text = "▶ Cosa fai?"
	choices_label.add_theme_font_size_override("font_size", 13)
	choices_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	choices_label.visible = false
	para_vbox.add_child(choices_label)

	choices_box = VBoxContainer.new()
	choices_box.name = "ChoicesBox"
	choices_box.add_theme_constant_override("separation", 5)
	para_vbox.add_child(choices_box)

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
	btn_land.text = "Prepara spedizione"
	btn_land.visible = false
	btn_land.pressed.connect(_on_land)
	actions_hbox.add_child(btn_land)

	var btn_continue := Button.new()
	btn_continue.name = "BtnContinue"
	btn_continue.text = "Continua"
	btn_continue.visible = false
	btn_continue.pressed.connect(_on_continue)
	actions_hbox.add_child(btn_continue)

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

	var btn_heal := Button.new()
	btn_heal.name = "BtnHeal"
	btn_heal.text = "Cura (Uff. Medico)"
	btn_heal.visible = false
	btn_heal.pressed.connect(_on_heal)
	actions_hbox.add_child(btn_heal)

	var btn_repair := Button.new()
	btn_repair.name = "BtnRepair"
	btn_repair.text = "Ripara (Botkit/Toolkit)"
	btn_repair.visible = false
	btn_repair.pressed.connect(_on_repair)
	actions_hbox.add_child(btn_repair)

	# (Il Registro di Bordo è nel pannello destro, in basso.)

	# RIGHT PANEL - Status + Dice
	right_panel = Panel.new()
	right_panel.custom_minimum_size = Vector2(330, 0)
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

	# Segnalini dell'equipaggio (token originali + Resistenza)
	var crew_title := Label.new()
	crew_title.text = "Equipaggio"
	crew_title.add_theme_font_size_override("font_size", 13)
	crew_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	right_vbox.add_child(crew_title)

	var crew_grid := GridContainer.new()
	crew_grid.name = "CrewCounters"
	crew_grid.columns = 4
	crew_grid.add_theme_constant_override("h_separation", 6)
	crew_grid.add_theme_constant_override("v_separation", 6)
	right_vbox.add_child(crew_grid)
	_build_crew_counters(crew_grid)

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

	var sep4 := HSeparator.new()
	right_vbox.add_child(sep4)

	# Registro di Bordo (in fondo allo stato, occupa lo spazio rimanente)
	var log_title := Label.new()
	log_title.text = "Registro di Bordo"
	log_title.add_theme_font_size_override("font_size", 13)
	log_title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	right_vbox.add_child(log_title)

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(log_scroll)

	log_display = RichTextLabel.new()
	log_display.name = "LogDisplay"
	log_display.bbcode_enabled = true
	log_display.fit_content = false
	log_display.scroll_following = true
	log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_display.add_theme_font_size_override("normal_font_size", 12)
	log_display.add_theme_color_override("default_color", Color(0.8, 0.9, 0.8))
	log_scroll.add_child(log_display)

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

# Segnalini dell'equipaggio: token originale + Resistenza, colorati per stato.
func _build_crew_counters(parent: Control) -> void:
	for key in GameData.get_character_keys():
		var u := GameData.get_character(key)
		var box := VBoxContainer.new()
		box.name = "Crew_%s" % key
		box.add_theme_constant_override("separation", 0)
		box.tooltip_text = u.get("name", key)
		var tex := TextureRect.new()
		tex.name = "Tok"
		var path := "res://assets/characters/%s.png" % u.get("img", "")
		if ResourceLoader.exists(path):
			tex.texture = load(path)
		tex.custom_minimum_size = Vector2(52, 52)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(tex)
		var hp := Label.new()
		hp.name = "HP"
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp.add_theme_font_size_override("font_size", 11)
		box.add_child(hp)
		parent.add_child(box)

func _refresh_crew_counters() -> void:
	var grid := find_child("CrewCounters", true, false)
	if not grid:
		return
	for key in GameData.get_character_keys():
		var box := grid.find_child("Crew_%s" % key, false, false)
		if not box:
			continue
		var c: Dictionary = GameState.crew.get(key, {})
		var alive: bool = c.get("alive", true)
		var e: int = int(c.get("endurance", GameState.MAX_ENDURANCE))
		var onboard: bool = key in GameState.expedition_units
		var tex := box.get_node_or_null("Tok") as TextureRect
		var hp := box.get_node_or_null("HP") as Label
		if tex:
			if not alive:
				tex.modulate = Color(0.35, 0.2, 0.2, 0.6)
			elif e < GameState.MAX_ENDURANCE:
				tex.modulate = Color(1.0, 0.75, 0.55)
			elif onboard:
				tex.modulate = Color(1, 1, 1)
			else:
				tex.modulate = Color(0.7, 0.7, 0.7)
		if hp:
			if not alive:
				hp.text = "✖"
				hp.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
			else:
				hp.text = "%d/%d" % [e, GameState.MAX_ENDURANCE]
				hp.add_theme_color_override("font_color",
					Color(1, 0.7, 0.5) if e < GameState.MAX_ENDURANCE else Color(0.7, 0.9, 0.7))

func _build_hex_buttons() -> void:
	for col in range(1, 5):
		var max_row := 7 if col % 2 == 1 else 6
		for row in range(1, max_row + 1):
			var hex_id := col * 10 + row
			var pos := _hex_to_screen_pos(hex_id)

			var btn := Button.new()
			btn.name = "Hex_%d" % hex_id
			btn.custom_minimum_size = Vector2(70, 70)
			btn.size = Vector2(70, 70)
			btn.position = pos - Vector2(35, 35)
			btn.pressed.connect(_on_hex_clicked.bind(hex_id))
			var sys_name := GameData.get_planet_for_hex(hex_id)
			btn.tooltip_text = sys_name if sys_name != "" else "Esagono %d" % hex_id
			interstellar_display.add_child(btn)

	# Marker originale della Pandora (sopra i pulsanti)
	var marker := TextureRect.new()
	marker.name = "PandoraMarker"
	marker.texture = load("res://assets/markers/Marker_Pandora.png")
	marker.custom_minimum_size = Vector2(44, 38)
	marker.size = Vector2(44, 38)
	marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interstellar_display.add_child(marker)

func _hex_to_screen_pos(hex_id: int) -> Vector2:
	# Centro dell'esagono in coordinate del pannello, allineato alla mappa reale
	var col := hex_id / 10
	var row := hex_id % 10
	var fx := GRID_BASE.x + (col - 1) * GRID_DX
	var fy := GRID_BASE.y + (row - 1) * GRID_DY
	if col % 2 == 0:
		fy += GRID_EVEN_OFFSET
	var px := INTER_OFFSET.x + (fx - INTER_REGION.position.x) * INTER_SCALE
	var py := INTER_OFFSET.y + (fy - INTER_REGION.position.y) * INTER_SCALE
	return Vector2(px, py)

# --- Environ (superficie planetaria) -----------------------------------------

# Costruisce (o ricostruisce) la vista della mappa reale per l'environ corrente.
func _load_environ_view() -> void:
	var eid := GameState.current_environ_id
	var env: Dictionary = GameData.get_environ(eid)
	# Rimuove i vecchi bottoni esagono (mantiene la TextureRect della mappa).
	# Liberazione immediata per evitare collisioni di nome con i nuovi bottoni.
	for child in env_canvas.get_children():
		if child != env_map:
			env_canvas.remove_child(child)
			child.free()
	if env.is_empty():
		env_loaded_id = eid
		return
	var iw: float = float(env.get("w", 1000)) * ENVIRON_DISPLAY_SCALE
	var ih: float = float(env.get("h", 1400)) * ENVIRON_DISPLAY_SCALE
	env_map.texture = load(env.get("img", ""))
	env_map.size = Vector2(iw, ih)
	env_canvas.custom_minimum_size = Vector2(iw, ih)
	env_canvas.size = Vector2(iw, ih)

	var dx: float = float(env.get("dx", 168.0))
	var bsize: float = dx * ENVIRON_DISPLAY_SCALE * 0.92
	for hex_id in GameState.environ_grid:
		var pos := _environ_hex_screen_pos(hex_id)
		var btn := Button.new()
		btn.name = "Env_%d" % hex_id
		btn.custom_minimum_size = Vector2(bsize, bsize)
		btn.size = Vector2(bsize, bsize)
		btn.position = pos - Vector2(bsize, bsize) * 0.5
		btn.pressed.connect(_on_environ_hex_clicked.bind(hex_id))
		env_canvas.add_child(btn)
	env_loaded_id = eid
	_refresh_environ_buttons()
	call_deferred("_center_on_expedition")

func _environ_hex_screen_pos(hex_id: int) -> Vector2:
	var cell: Dictionary = GameState.environ_grid.get(hex_id, {})
	return Vector2(cell.get("x", 0.0), cell.get("y", 0.0)) * ENVIRON_DISPLAY_SCALE

func _refresh_environ_buttons() -> void:
	for hex_id in GameState.environ_grid:
		var btn := env_canvas.find_child("Env_%d" % hex_id, false, false) as Button
		if not btn:
			continue
		var explored: bool = GameState.environ_grid[hex_id].get("explored", false)
		var is_pos: bool = (hex_id == GameState.expedition_pos)
		var reachable: bool = GameState.can_move_expedition(hex_id)

		var fill := Color(0, 0, 0, 0)
		var border := Color(0, 0, 0, 0)
		var bw := 0
		btn.text = ""
		if is_pos:
			fill = Color(0.2, 0.8, 1.0, 0.35)
			border = Color(0.3, 0.9, 1.0, 1.0)
			bw = 4
			btn.text = "◉"
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			btn.add_theme_font_size_override("font_size", 22)
		elif reachable:
			fill = Color(1.0, 1.0, 1.0, 0.16)
			border = Color(1.0, 0.95, 0.5, 0.9)
			bw = 3
		elif explored:
			border = Color(0.4, 1.0, 0.5, 0.5)
			bw = 2

		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = border
		sb.set_border_width_all(bw)
		sb.set_corner_radius_all(int(btn.size.x * 0.5))
		var hover := sb.duplicate() as StyleBoxFlat
		hover.bg_color = Color(fill.r, fill.g, fill.b, min(fill.a + 0.18, 0.6)) if reachable else fill
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)
		btn.add_theme_stylebox_override("disabled", sb)
		btn.disabled = not (reachable or is_pos)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if (reachable or is_pos) else Control.MOUSE_FILTER_IGNORE

func _center_on_expedition() -> void:
	if not env_scroll:
		return
	var pos := _environ_hex_screen_pos(GameState.expedition_pos)
	var vp := env_scroll.size
	env_scroll.scroll_horizontal = int(max(0.0, pos.x - vp.x * 0.5))
	env_scroll.scroll_vertical = int(max(0.0, pos.y - vp.y * 0.5))

func _on_environ_hex_clicked(hex_id: int) -> void:
	if GameState.can_move_expedition(hex_id):
		GameState.move_expedition(hex_id)

func _update_left_panel_mode() -> void:
	var on_surface := GameState.current_phase == GameState.Phase.EXPEDITION \
		or (GameState.current_phase == GameState.Phase.PARAGRAPH and GameState.expedition_pos > 0) \
		or not GameState.current_creature.is_empty()
	if interstellar_display: interstellar_display.visible = not on_surface
	if environ_display:
		environ_display.visible = on_surface
		if on_surface:
			if env_loaded_id != GameState.current_environ_id:
				_load_environ_view()
			else:
				_refresh_environ_buttons()

func _connect_signals() -> void:
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.state_updated.connect(_update_display)
	GameState.paragraph_request.connect(_on_paragraph_request)
	GameState.message_posted.connect(_on_message)
	GameState.encounter_started.connect(_on_encounter_started)
	GameState.encounter_ended.connect(_on_encounter_ended)
	GameState.environ_changed.connect(_on_environ_changed)

func _on_environ_changed() -> void:
	_update_left_panel_mode()
	# La vista segue la spedizione mentre si sposta sulla superficie
	if environ_display and environ_display.visible and env_loaded_id == GameState.current_environ_id:
		call_deferred("_center_on_expedition")

func _on_phase_changed(phase: String) -> void:
	_update_display()
	_update_action_buttons(phase)

func _update_action_buttons(phase: String) -> void:
	var btn_orbit := find_child("BtnOrbit", true, false)
	var btn_land := find_child("BtnLand", true, false)
	var btn_return := find_child("BtnReturn", true, false)
	var btn_explore := find_child("BtnExplore", true, false)
	var btn_continue := find_child("BtnContinue", true, false)
	var btn_kill := find_child("BtnKill", true, false)
	var btn_capture := find_child("BtnCapture", true, false)
	var btn_flee := find_child("BtnFlee", true, false)
	var btn_heal := find_child("BtnHeal", true, false)

	var in_combat := not GameState.current_creature.is_empty()
	var on_surface := GameState.expedition_pos > 0

	if btn_orbit: btn_orbit.visible = (phase == "orbit")
	if btn_land: btn_land.visible = (phase == "orbit")
	if btn_return: btn_return.visible = (phase == "expedition" or phase == "paragraph") and not in_combat
	# "Esplora" appare quando l'esagono occupato non è ancora stato esplorato (es. atterraggio)
	var here_explored: bool = GameState.environ_grid.get(GameState.expedition_pos, {}).get("explored", true)
	var here_unexplored: bool = on_surface and not here_explored
	if btn_explore: btn_explore.visible = (phase == "expedition") and not in_combat and here_unexplored
	if btn_continue: btn_continue.visible = (phase == "paragraph") and not in_combat
	if btn_kill: btn_kill.visible = in_combat
	if btn_capture: btn_capture.visible = in_combat
	if btn_flee: btn_flee.visible = in_combat
	if btn_heal: btn_heal.visible = (phase == "expedition") and not in_combat and GameState.can_heal()
	var btn_repair := find_child("BtnRepair", true, false)
	if btn_repair: btn_repair.visible = (phase == "expedition") and not in_combat and GameState.can_repair()

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

	var phase := GameState.phase_name(GameState.current_phase)
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
		var title: String = phase_it.get(phase, "—")
		if phase == "orbit" or phase == "expedition":
			title += " — " + s.current_system
		lbl_phase.text = title

	var lbl_hint := find_child("HintLabel", true, false) as Label
	if lbl_hint:
		var hint := ""
		if not s.current_creature.is_empty():
			hint = "Incontro in corso: scegli Uccidi, Cattura o Fuggi."
		elif phase == "interstellar":
			hint = "Scegli un sistema raggiungibile sulla mappa per spostare la Pandora."
		elif phase == "orbit":
			hint = "Esamina il pianeta, poi prepara la spedizione."
		elif phase == "expedition":
			hint = "Muoviti sulla mappa o esplora l'esagono; segui i paragrafi."
		elif phase == "paragraph":
			hint = "Leggi e scegli un rimando, oppure premi Continua."
		lbl_hint.text = hint

	# Refresh hex buttons and panel mode
	_refresh_hex_buttons()
	_refresh_crew_counters()
	_update_left_panel_mode()

func _refresh_hex_buttons() -> void:
	for col in range(1, 5):
		var max_row := 7 if col % 2 == 1 else 6
		for row in range(1, max_row + 1):
			var hex_id := col * 10 + row
			var btn := find_child("Hex_%d" % hex_id, true, false) as Button
			if not btn: continue

			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_corner_radius_all(35)
			sb.set_border_width_all(3)
			sb.border_color = Color(1, 1, 1, 0)  # invisibile di default

			if hex_id == GameState.pandora_hex:
				sb.border_color = Color(0.3, 0.9, 1.0)
				sb.bg_color = Color(0.3, 0.9, 1.0, 0.28)
			elif GameData.get_planet_for_hex(hex_id) != "":
				if GameState.can_move_to(hex_id):
					sb.border_color = Color(1.0, 0.85, 0.2)
					sb.bg_color = Color(1.0, 0.85, 0.2, 0.18)
			else:
				if GameState.can_move_to(hex_id):
					sb.border_color = Color(0.85, 0.9, 1.0, 0.7)

			for st in ["normal", "hover", "pressed", "focus"]:
				btn.add_theme_stylebox_override(st, sb)

			btn.disabled = (GameState.current_phase != GameState.Phase.INTERSTELLAR)

	# Posiziona il marker della Pandora sull'esagono attuale
	var marker := find_child("PandoraMarker", true, false) as TextureRect
	if marker:
		var p := _hex_to_screen_pos(GameState.pandora_hex)
		marker.position = p - marker.size / 2.0

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

# --- Pannello di preparazione della spedizione (regola 5.0) ------------------

func _build_prep_panel() -> void:
	var overlay := ColorRect.new()
	overlay.name = "PrepOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(560, 560)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Preparazione della Spedizione"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var info := Label.new()
	info.name = "PrepInfo"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(520, 0)
	vbox.add_child(info)

	# Lista scrollabile di unità imbarcabili: personaggi, robot, strumenti
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 240)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list_scroll)
	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_vbox)

	_add_prep_section(list_vbox, "Personaggi (almeno uno):")
	for k in GameData.get_character_keys():
		var chk := CheckBox.new()
		chk.name = "PrepChk_%s" % k
		chk.add_theme_font_size_override("font_size", 12)
		chk.toggled.connect(_on_prep_unit_toggled.bind(k))
		list_vbox.add_child(chk)

	_add_prep_section(list_vbox, "Robot:")
	for k in GameData.get_bot_keys():
		var bchk := CheckBox.new()
		bchk.name = "PrepGear_%s" % k
		bchk.add_theme_font_size_override("font_size", 12)
		bchk.toggled.connect(_on_prep_gear_toggled.bind(k))
		list_vbox.add_child(bchk)

	_add_prep_section(list_vbox, "Strumenti:")
	for k in GameData.get_tool_keys():
		var tchk := CheckBox.new()
		tchk.name = "PrepGear_%s" % k
		tchk.add_theme_font_size_override("font_size", 12)
		tchk.toggled.connect(_on_prep_gear_toggled.bind(k))
		list_vbox.add_child(tchk)

	var sup_box := HBoxContainer.new()
	sup_box.add_theme_constant_override("separation", 8)
	vbox.add_child(sup_box)
	var sup_lbl := Label.new()
	sup_lbl.text = "Punti Rifornimento:"
	sup_box.add_child(sup_lbl)
	var slider := HSlider.new()
	slider.name = "PrepSupply"
	slider.min_value = 0
	slider.max_value = GameData.max_supply()
	slider.step = 1
	slider.custom_minimum_size = Vector2(260, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_prep_supply_changed)
	sup_box.add_child(slider)
	var sup_val := Label.new()
	sup_val.name = "PrepSupplyVal"
	sup_val.custom_minimum_size = Vector2(28, 0)
	sup_box.add_child(sup_val)

	var load_lbl := Label.new()
	load_lbl.name = "PrepLoad"
	load_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(load_lbl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	vbox.add_child(btns)
	var launch := Button.new()
	launch.name = "PrepLaunch"
	launch.text = "Lancia lo shuttle (tira dado)"
	launch.custom_minimum_size = Vector2(0, 44)
	launch.pressed.connect(_on_prep_launch)
	btns.add_child(launch)
	var cancel := Button.new()
	cancel.name = "PrepCancel"
	cancel.text = "Annulla"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_on_prep_cancel)
	btns.add_child(cancel)

func _add_prep_section(parent: Control, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	parent.add_child(lbl)

func _open_prep_panel() -> void:
	# Inizializza la preparazione se non è ancora stata impostata per questo pianeta
	if GameState.expedition_units.is_empty():
		GameState.setup_orbit_planet()
	var overlay := find_child("PrepOverlay", true, false)
	if overlay:
		overlay.visible = true
		_refresh_prep_panel()

func _refresh_prep_panel() -> void:
	_prep_updating = true
	var info := find_child("PrepInfo", true, false) as Label
	if info:
		var atmo: String = GameState.planet_attrs.get("atmosphere", "Normal")
		var hydro: int = int(GameState.planet_attrs.get("hydro", 0))
		var txt := "Pianeta %s · Gravità %s · Atmosfera %s · Idro %d%% · Capacità shuttle %d" % [
			GameState.current_system, GameData.gravity_it(GameState.planet_gravity),
			GameData.atmosphere_it(atmo), hydro, GameState.shuttle_capacity]
		var note := GameData.atmosphere_note(atmo)
		if note != "":
			txt += "\n⚠ " + note
		info.text = txt
	for k in GameData.get_character_keys():
		var chk := find_child("PrepChk_%s" % k, true, false) as CheckBox
		if not chk:
			continue
		var u := GameData.get_character(k)
		chk.button_pressed = k in GameState.expedition_units
		chk.text = "%s — Catt %d / Ucc %d · Peso %d · Porto %d · Vel %d" % [
			u.get("name", k), u.get("capture", 0), u.get("kill", 0),
			u.get("weight", 0), u.get("port", 0), u.get("speed", 0)]
		chk.disabled = not GameState.crew.get(k, {}).get("alive", true)
	# Robot e strumenti imbarcabili
	for k in GameData.get_bot_keys() + GameData.get_tool_keys():
		var gchk := find_child("PrepGear_%s" % k, true, false) as CheckBox
		if not gchk:
			continue
		var g := GameData.get_unit(k)
		gchk.button_pressed = k in GameState.expedition_gear
		var line := "%s — Peso %d" % [g.get("name", k), int(g.get("weight", 0))]
		if g.get("combat", false) or GameData.get_bot_keys().has(k):
			line += " · Catt %d / Ucc %d" % [int(g.get("capture", 0)), int(g.get("kill", 0))]
		if g.has("desc") and g.get("desc", "") != "":
			line += " · " + str(g.get("desc"))
		gchk.text = line
	var slider := find_child("PrepSupply", true, false) as HSlider
	if slider:
		slider.max_value = max(GameState.max_planned_supply(), GameState.planned_supply)
		slider.value = GameState.planned_supply
	var sup_val := find_child("PrepSupplyVal", true, false) as Label
	if sup_val:
		sup_val.text = "%d" % GameState.planned_supply
	var load_lbl := find_child("PrepLoad", true, false) as Label
	if load_lbl:
		var over := GameState.total_load() > GameState.shuttle_capacity
		load_lbl.text = "Carico: %d / %d   (unità %d + rifornimenti %d)" % [
			GameState.total_load(), GameState.shuttle_capacity,
			GameState.units_weight(), GameState.planned_supply]
		load_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.4, 0.4) if over else Color(0.6, 1.0, 0.6))
	var launch := find_child("PrepLaunch", true, false) as Button
	if launch:
		launch.disabled = not GameState.prep_valid()
	_prep_updating = false

func _on_prep_unit_toggled(_pressed: bool, key: String) -> void:
	if _prep_updating:
		return
	GameState.toggle_expedition_unit(key)
	_refresh_prep_panel()

func _on_prep_gear_toggled(_pressed: bool, key: String) -> void:
	if _prep_updating:
		return
	GameState.toggle_gear_unit(key)
	_refresh_prep_panel()

func _on_prep_supply_changed(value: float) -> void:
	if _prep_updating:
		return
	GameState.planned_supply = clampi(int(value), 0, GameState.max_planned_supply())
	_refresh_prep_panel()

func _on_prep_cancel() -> void:
	var overlay := find_child("PrepOverlay", true, false)
	if overlay:
		overlay.visible = false

func _on_prep_launch() -> void:
	if not GameState.prep_valid():
		return
	var overlay := find_child("PrepOverlay", true, false)
	if overlay:
		overlay.visible = false
	var die := randi_range(1, 6)
	_set_dice_result(die)
	GameState.launch_expedition(die)

func _on_enter_orbit() -> void:
	GameState.set_phase(GameState.Phase.ORBIT)
	GameState.setup_orbit_planet()
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
	_open_prep_panel()

func _on_continue() -> void:
	# Chiude il paragrafo corrente e torna alla fase appropriata
	GameState.current_paragraph = 0
	if GameState.expedition_pos > 0:
		GameState.set_phase(GameState.Phase.EXPEDITION)
		_show_expedition_panel()
	elif GameState.current_system != "" and GameState.current_system != "Sol":
		GameState.set_phase(GameState.Phase.ORBIT)
	else:
		GameState.set_phase(GameState.Phase.INTERSTELLAR)

func _on_return_to_pandora() -> void:
	GameState.return_to_pandora()

func _on_explore() -> void:
	# Esplora l'esagono attualmente occupato (es. quello di atterraggio), con i
	# costi in ore del terreno (Carta 6.6) gestiti da GameState.
	GameState.explore_current_hex()

func _on_combat(mode: String) -> void:
	if GameState.current_creature.is_empty():
		return
	# Miglior valore di combattimento tra i personaggi scelti per la spedizione (5.2/8.0)
	var player_combat := GameState.best_combat(mode)
	GameState.resolve_combat(mode, player_combat)
	# Aggiorna il pannello (l'incontro può essere finito)
	if GameState.current_creature.is_empty():
		_show_expedition_panel()
	else:
		_on_encounter_started(GameState.current_creature)

func _on_flee() -> void:
	GameState.flee_encounter()
	_show_expedition_panel()

func _on_heal() -> void:
	GameState.heal_wounded()
	_show_expedition_panel()

func _on_repair() -> void:
	GameState.repair_gear()
	_show_expedition_panel()

func _on_encounter_started(creature_name: String) -> void:
	_clear_choices()
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
	_clear_choices()
	var title_lbl := find_child("ParaTitle", true, false) as Label
	if title_lbl: title_lbl.text = "— Spedizione su %s —" % GameState.current_planet

	var para_display := find_child("ParagraphText", true, false) as RichTextLabel
	if para_display:
		var cell: Dictionary = GameState.environ_grid.get(GameState.expedition_pos, {})
		var terr_class: String = cell.get("terrain", "Open")
		var bb := "Posizione: esagono [b]%s[/b] · terreno [b]%s[/b] (entrata %d ore, esplorazione %d ore).\n\n" % [
			cell.get("real", "?"), GameData.terrain_it(terr_class),
			GameState.enter_cost_for(terr_class), GameState.explore_cost_for(terr_class)]
		bb += "Ore di spedizione: [b]%d[/b]  ·  Rifornimenti: [b]%d[/b]  ·  Danni: [b]%d[/b]\n\n" % [
			GameState.expedition_hours, GameState.expedition_supply, GameState.damage_points
		]
		# Stato dell'equipaggio imbarcato (Resistenza, regola 8.8)
		var crew_lines: Array = []
		for k in GameState.expedition_units:
			var c: Dictionary = GameState.crew.get(k, {})
			var e: int = int(c.get("endurance", GameState.MAX_ENDURANCE))
			var tag := "%s %d/%d" % [c.get("name", k), e, GameState.MAX_ENDURANCE]
			if e < GameState.MAX_ENDURANCE:
				tag = "[color=#ff8866]" + tag + "[/color]"
			crew_lines.append(tag)
		if crew_lines.size() > 0:
			bb += "Squadra: " + " · ".join(crew_lines) + "\n\n"
		# Equipaggiamento imbarcato (robot/strumenti), danneggiati evidenziati (6.9)
		var gear_lines: Array = []
		for k in GameState.expedition_gear:
			var gname: String = GameData.get_unit(k).get("name", k)
			if k in GameState.damaged_gear:
				gname = "[color=#ff8866]" + gname + " (danneggiato)[/color]"
			gear_lines.append(gname)
		if gear_lines.size() > 0:
			bb += "Equipaggiamento: " + " · ".join(gear_lines) + "\n\n"
		if GameState.captured_creatures.size() > 0:
			bb += "Creature catturate: %s\n\n" % ", ".join(GameState.captured_creatures)
		if not cell.get("explored", true):
			bb += "[i]Premi \"Esplora\" per esplorare questo esagono, "
			bb += "oppure spostati su un esagono adiacente sulla mappa (a sinistra).[/i]"
		else:
			bb += "[i]Sposta la spedizione cliccando un esagono adiacente sulla mappa di superficie "
			bb += "(a sinistra), oppure premi \"Torna alla Pandora\".[/i]"
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

	# Questo paragrafo è l'incontro di una creatura attualmente in corso?
	var creature := GameData.creature_for_paragraph(para_num)
	var is_creature_here := creature != "" and creature == GameState.current_creature

	var para_display := find_child("ParagraphText", true, false) as RichTextLabel
	if para_display:
		var bb := ""
		if is_creature_here:
			# Segnalino originale della creatura + valutazione, sopra al testo
			var cpath := "res://assets/creatures/%s.png" % GameData.get_creature(creature).get("img", "")
			if ResourceLoader.exists(cpath):
				bb += "[center][img=150]" + cpath + "[/img][/center]\n"
			bb += "[center][b]%s[/b] — valutazione di combattimento: [b]%d[/b][/center]\n\n" % [creature, GameState.creature_rating]
		else:
			# Illustrazione narrativa dell'evento (se presente)
			var img_path := GameData.get_event_image_path(para_num)
			if not img_path.is_empty():
				bb += "[center][img=360]" + img_path + "[/img][/center]\n\n"
		bb += "[p]" + _linkify(text) + "[/p]"
		para_display.bbcode_text = bb

	# Durante un incontro i comandi di combattimento sostituiscono le scelte testuali
	if is_creature_here:
		_clear_choices()
	else:
		_build_choices(para_num)
	_update_action_buttons(GameState.phase_name(GameState.current_phase))

# Trasforma i rimandi ¶NNN del testo in link cliccabili.
func _linkify(text: String) -> String:
	var re := RegEx.new()
	re.compile("¶\\s*(\\d{1,3})")
	var out := ""
	var last := 0
	for m in re.search_all(text):
		out += text.substr(last, m.get_start() - last)
		var n := m.get_string(1)
		out += "[url=%s][color=#ffd24d][b]→ ¶%s[/b][/color][/url]" % [n, n]
		last = m.get_end()
	out += text.substr(last)
	return out

# Costruisce i pulsanti-scelta sotto il paragrafo dai rimandi ¶NNN.
func _build_choices(para_num: int) -> void:
	_clear_choices()
	var choices := GameData.get_paragraph_choices(para_num)
	var lbl := find_child("ChoicesLabel", true, false) as Label
	if lbl: lbl.visible = choices.size() > 0
	for ch in choices:
		var b := Button.new()
		var label_text: String = ch.label
		if label_text.length() > 90:
			label_text = label_text.substr(0, 88) + "…"
		b.text = "▶  %s  (¶%03d)" % [label_text, ch.para]
		b.tooltip_text = ch.label
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.28, 0.20)
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(8)
		sb.border_color = Color(0.4, 0.8, 0.5, 0.7)
		sb.set_border_width_all(1)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.bg_color = Color(0.22, 0.40, 0.27)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_stylebox_override("focus", sb)
		b.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
		b.pressed.connect(_on_choice_selected.bind(ch.para))
		choices_box.add_child(b)

func _clear_choices() -> void:
	if not choices_box:
		return
	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.free()
	var lbl := find_child("ChoicesLabel", true, false) as Label
	if lbl: lbl.visible = false

func _on_choice_selected(para: int) -> void:
	GameState.show_paragraph(para)

func _on_meta_clicked(meta) -> void:
	var n := int(str(meta))
	if n > 0:
		GameState.show_paragraph(n)

func _on_message(msg: String) -> void:
	if log_display:
		log_display.append_text("\n[color=#aaffaa]▸[/color] " + msg)

	var hint_lbl := find_child("DiceHint", true, false) as Label
	if hint_lbl and GameState.awaiting_die_roll:
		hint_lbl.text = msg

func _post_message(msg: String) -> void:
	if log_display:
		log_display.append_text("\n[color=#ffaa44]►[/color] " + msg)
