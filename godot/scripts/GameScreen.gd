extends Control

var left_panel: Panel
var center_panel: Panel
var right_panel: Panel
var interstellar_display: Control
var environ_display: Control
var prep_display: Control
var _prep_open: bool = false
var env_canvas: Control
var env_map: TextureRect
var env_loaded_id: int = 0
var env_scale: float = 0.45   # scala per far stare l'intera mappa nel pannello
var paragraph_display: Control
var log_display: RichTextLabel
var status_display: Control
var dice_panel: Control
var current_para_num: int = 0
var _prep_updating: bool = false
var _show_full_trail: bool = false
var choices_box: VBoxContainer

# Audio: effetti brevi caricati all'avvio (feedback sugli eventi chiave)
var sfx: AudioStreamPlayer
var _sounds: Dictionary = {}

# Overlay del riferimento regole (tabelle originali del gioco)
var charts_overlay: Control
const CHARTS := [
	["Chart_8-6 Combat Results.jpg", "8.6 Risultati Combattimento"],
	["Chart_8-3 Creature Rating.jpg", "8.3 Valutazione Creatura"],
	["Chart_8-2 Encounter Strategy.jpg", "8.2 Strategia d'Incontro"],
	["Chart_6-6 Terrain Effects.jpg", "6.6 Effetti del Terreno"],
	["Chart_6-4 Exploration Matrix.jpg", "6.4 Matrice d'Esplorazione"],
	["Chart_5-8 Port Capacity.jpg", "5.8 Capacità di Porto"],
	["Chart_4-3 Planet Table.jpg", "4.3 Tabella Pianeti"],
	["Chart_4-2 Interstellar Event.jpg", "4.2 Evento Interstellare"],
]

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
	_init_audio()
	_connect_signals()
	_render_full_log()
	_update_display()
	# Ripristina la visualizzazione corrente al (ri)entro nella scena
	if not GameState.current_creature.is_empty():
		_on_encounter_started(GameState.current_creature)
	elif GameState.current_paragraph > 0 and GameState.current_phase == GameState.Phase.PARAGRAPH:
		_on_paragraph_request(GameState.current_paragraph)
	_update_action_buttons(GameState.phase_name(GameState.current_phase))

func _build_ui() -> void:
	# Tema visivo condiviso + sfondo a gradiente (blu notte, accenti ciano/ambra).
	theme = UITheme.make_theme()
	add_child(UITheme.make_background())

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
	_style_map_title(left_title)
	interstellar_display.add_child(left_title)

	# Draw hex buttons
	_build_hex_buttons()

	# Environ (superficie planetaria) — sovrapposto, nascosto finché non si sbarca
	environ_display = Control.new()
	environ_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	environ_display.visible = false
	left_panel.add_child(environ_display)

	# Mappa intera (niente scroll): env_canvas viene dimensionato per stare nel pannello
	env_canvas = Control.new()
	env_canvas.name = "EnvCanvas"
	env_canvas.position = Vector2(6, 28)
	environ_display.add_child(env_canvas)

	env_map = TextureRect.new()
	env_map.name = "EnvMap"
	env_map.position = Vector2.ZERO
	env_map.stretch_mode = TextureRect.STRETCH_SCALE
	# IGNORE_SIZE: la TextureRect rispetta la .size impostata (scala) invece di
	# usare la dimensione nativa della texture — così mappa e bottoni combaciano.
	env_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	env_canvas.add_child(env_map)

	# Pannello caratteristiche del pianeta, sotto la mappa
	var planet_panel := PanelContainer.new()
	planet_panel.name = "PlanetPanel"
	planet_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	planet_panel.offset_left = 6
	planet_panel.offset_right = -6
	planet_panel.offset_top = -150
	planet_panel.offset_bottom = -6
	environ_display.add_child(planet_panel)
	var planet_lbl := RichTextLabel.new()
	planet_lbl.name = "PlanetInfo"
	planet_lbl.bbcode_enabled = true
	planet_lbl.fit_content = true
	planet_lbl.add_theme_font_size_override("normal_font_size", 12)
	planet_panel.add_child(planet_lbl)

	var env_title := Label.new()
	env_title.name = "EnvironTitle"
	env_title.text = "Superficie Planetaria"
	env_title.position = Vector2(10, 5)
	env_title.z_index = 10
	_style_map_title(env_title)
	environ_display.add_child(env_title)

	# Preparazione spedizione (drag-and-drop), sul pannello sinistro durante l'orbita
	_build_prep_display(left_panel)

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
	center_panel.custom_minimum_size = Vector2(0, 180)
	center_vbox.add_child(center_panel)

	# --- Pannello DISPOSIZIONE (sotto il testo): dove sta ogni unità (5.6/5.7) ---
	# Pedine grandi e sovrapposte a ventaglio (niente scroll), il nome è sulla pedina.
	var disp_sec := UITheme.section("Disposizione · dove sta ogni unità")
	disp_sec["panel"].name = "DispositionSection"
	disp_sec["panel"].custom_minimum_size = Vector2(0, 440)
	disp_sec["panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(disp_sec["panel"])
	var disp_vbox := VBoxContainer.new()
	disp_vbox.add_theme_constant_override("separation", 6)
	disp_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	disp_sec["vbox"].add_child(disp_vbox)
	# Riga superiore: Pandora (box largo, molte pedine in orizzontale)
	var _disp_add_bucket := func(parent: Control, bucket: String, h_stretch: int):
		var col := PanelContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.size_flags_stretch_ratio = float(h_stretch)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		col.add_child(cv)
		var hdr := Label.new()
		hdr.text = bucket.to_upper()
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 12)
		hdr.add_theme_color_override("font_color", UITheme.CYAN)
		cv.add_child(hdr)
		var box := Control.new()
		box.name = "Disp_%s" % bucket
		box.clip_contents = true
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Al ridimensionamento ricalcola la dimensione globale e ridispone tutto.
		box.resized.connect(_relayout_all_disp)
		cv.add_child(box)
		var info_lbl := Label.new()
		info_lbl.name = "DispInfo_%s" % bucket
		info_lbl.add_theme_font_size_override("font_size", 10)
		info_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.visible = false   # mostrata solo per i box di superficie (vedi _refresh_disposition)
		cv.add_child(info_lbl)
		parent.add_child(col)
	# Pandora ospita tutta la nave (3 categorie su più righe): leggermente più bassa
	# dei box di superficie, ma sufficiente per le 3 file di pedine.
	_disp_add_bucket.call(disp_vbox, "Pandora", 1)
	(disp_vbox.get_child(disp_vbox.get_child_count() - 1) as Control).size_flags_stretch_ratio = 1.0
	# Riga inferiore: Shuttle + A piedi + Rover (larghezza uguale), un po' più alta.
	var disp_row := HBoxContainer.new()
	disp_row.add_theme_constant_override("separation", 6)
	disp_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	disp_row.size_flags_stretch_ratio = 1.3
	disp_vbox.add_child(disp_row)
	_disp_add_bucket.call(disp_row, "Shuttle", 1)
	_disp_add_bucket.call(disp_row, "A piedi", 1)
	_disp_add_bucket.call(disp_row, "Rover", 1)
	# Riga informativa: fase corrente + capacità di superficie + scelta del mezzo (5.7/5.8).
	var info_row := HBoxContainer.new()
	info_row.name = "DispInfoRow"
	info_row.add_theme_constant_override("separation", 10)
	disp_sec["vbox"].add_child(info_row)
	var phase_lbl := Label.new()
	phase_lbl.name = "DispPhase"
	phase_lbl.add_theme_font_size_override("font_size", 12)
	phase_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	info_row.add_child(phase_lbl)
	var info_spacer := Control.new()
	info_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info_spacer)
	var veh_btn := Button.new()
	veh_btn.name = "DispVehicleBtn"
	veh_btn.add_theme_font_size_override("font_size", 12)
	veh_btn.pressed.connect(_on_toggle_vehicle)
	info_row.add_child(veh_btn)
	# Controlli di preparazione (rifornimenti + lancio), visibili solo in orbita.
	var prep_ctrl := HBoxContainer.new()
	prep_ctrl.name = "DispPrepControls"
	prep_ctrl.add_theme_constant_override("separation", 8)
	prep_ctrl.visible = false
	disp_sec["vbox"].add_child(prep_ctrl)
	var disp_load := Label.new()
	disp_load.name = "DispLoad"
	disp_load.add_theme_font_size_override("font_size", 12)
	prep_ctrl.add_child(disp_load)
	var sup_lbl2 := Label.new()
	sup_lbl2.text = "·  Rifornimenti:"
	sup_lbl2.add_theme_font_size_override("font_size", 12)
	prep_ctrl.add_child(sup_lbl2)
	var sup_slider := HSlider.new()
	sup_slider.name = "DispSupply"
	sup_slider.min_value = 0
	sup_slider.max_value = GameData.max_supply()
	sup_slider.step = 1
	sup_slider.custom_minimum_size = Vector2(150, 0)
	sup_slider.value_changed.connect(_on_prep_supply_changed)
	prep_ctrl.add_child(sup_slider)
	var sup_val2 := Label.new()
	sup_val2.name = "DispSupplyVal"
	sup_val2.custom_minimum_size = Vector2(26, 0)
	prep_ctrl.add_child(sup_val2)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prep_ctrl.add_child(spacer2)
	var launch2 := Button.new()
	launch2.name = "DispLaunch"
	launch2.text = "🚀 Lancia lo shuttle"
	launch2.add_theme_color_override("font_color", UITheme.CYAN)
	launch2.pressed.connect(_on_prep_launch)
	prep_ctrl.add_child(launch2)

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

	var btn_land := Button.new()
	btn_land.name = "BtnLand"
	btn_land.text = "🛬 Esplora il pianeta"
	btn_land.visible = false
	btn_land.add_theme_color_override("font_color", UITheme.CYAN)
	btn_land.pressed.connect(_on_land)
	actions_hbox.add_child(btn_land)

	var btn_orbit := Button.new()
	btn_orbit.name = "BtnOrbit"
	btn_orbit.text = "➡ Riparti (non esplorare)"
	btn_orbit.visible = false
	btn_orbit.pressed.connect(_on_leave_orbit)
	actions_hbox.add_child(btn_orbit)

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

	var btn_artifact := Button.new()
	btn_artifact.name = "BtnArtifact"
	btn_artifact.text = "Acquisisci artefatto"
	btn_artifact.visible = false
	btn_artifact.pressed.connect(_on_acquire_artifact)
	actions_hbox.add_child(btn_artifact)

	var btn_examine := Button.new()
	btn_examine.name = "BtnExamine"
	btn_examine.text = "Esamina"
	btn_examine.visible = false
	btn_examine.pressed.connect(_on_examine)
	actions_hbox.add_child(btn_examine)

	var btn_procedure := Button.new()
	btn_procedure.name = "BtnProcedure"
	btn_procedure.text = "Risolvi"
	btn_procedure.visible = false
	btn_procedure.pressed.connect(_on_procedure)
	actions_hbox.add_child(btn_procedure)

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
	btn_kill.add_theme_color_override("font_color", UITheme.RED)
	btn_kill.pressed.connect(_on_combat.bind("kill"))
	actions_hbox.add_child(btn_kill)

	var btn_capture := Button.new()
	btn_capture.name = "BtnCapture"
	btn_capture.text = "Cattura"
	btn_capture.visible = false
	btn_capture.add_theme_color_override("font_color", UITheme.GREEN)
	btn_capture.pressed.connect(_on_combat.bind("capture"))
	actions_hbox.add_child(btn_capture)

	var btn_comm := Button.new()
	btn_comm.name = "BtnComm"
	btn_comm.text = "💬 Comunica"
	btn_comm.visible = false
	btn_comm.add_theme_color_override("font_color", UITheme.CYAN)
	btn_comm.pressed.connect(_on_strategy.bind("communicate"))
	actions_hbox.add_child(btn_comm)

	var btn_strat := Button.new()
	btn_strat.name = "BtnStrat"
	btn_strat.text = "🎯 Cattura/Uccidi"
	btn_strat.visible = false
	btn_strat.add_theme_color_override("font_color", UITheme.AMBER)
	btn_strat.pressed.connect(_on_strategy.bind("capture_kill"))
	actions_hbox.add_child(btn_strat)

	var btn_flee := Button.new()
	btn_flee.name = "BtnFlee"
	btn_flee.text = "🏃 Fuggi"
	btn_flee.visible = false
	btn_flee.add_theme_color_override("font_color", UITheme.MUTED)
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

	# Spaziatore per spingere Salva/Menu a destra
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_hbox.add_child(spacer)

	var btn_save := Button.new()
	btn_save.name = "BtnSave"
	btn_save.text = "💾 Salva"
	btn_save.pressed.connect(_on_save)
	actions_hbox.add_child(btn_save)

	var btn_charts := Button.new()
	btn_charts.name = "BtnCharts"
	btn_charts.text = "📖 Tabelle"
	btn_charts.pressed.connect(_toggle_charts)
	actions_hbox.add_child(btn_charts)

	var btn_menu := Button.new()
	btn_menu.name = "BtnMenu"
	btn_menu.text = "☰ Menu"
	btn_menu.pressed.connect(_on_menu)
	actions_hbox.add_child(btn_menu)

	# (Il Registro di Bordo è nel pannello destro, in basso.)

	# RIGHT PANEL - Stato della Missione (a sezioni/card)
	right_panel = Panel.new()
	right_panel.custom_minimum_size = Vector2(340, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["left", "top", "right", "bottom"]:
		right_margin.add_theme_constant_override("margin_" + m, 8)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	# --- Sezione: Stato della Missione ---
	var sec_status := UITheme.section("Stato della Missione")
	right_vbox.add_child(sec_status["panel"])
	status_display = VBoxContainer.new()
	status_display.name = "StatusDisplay"
	sec_status["vbox"].add_child(status_display)
	_build_status_rows(status_display)

	# (L'equipaggio e l'equipaggiamento sono ora nel pannello "Disposizione" sotto il
	# testo centrale; la colonna destra resta solo informativa.)

	# --- Sezione: Dado (compatta) ---
	var sec_dice := UITheme.section("Dado")
	right_vbox.add_child(sec_dice["panel"])
	dice_panel = VBoxContainer.new()
	dice_panel.name = "DicePanel"
	dice_panel.add_theme_constant_override("separation", 4)
	sec_dice["vbox"].add_child(dice_panel)

	var dice_row := HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 10)
	dice_panel.add_child(dice_row)

	var dice_result_label := Label.new()
	dice_result_label.name = "DiceResult"
	dice_result_label.text = "—"
	dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_result_label.custom_minimum_size = Vector2(40, 0)
	dice_result_label.add_theme_font_size_override("font_size", 26)
	dice_result_label.add_theme_color_override("font_color", UITheme.AMBER)
	dice_row.add_child(dice_result_label)

	var roll_btn := Button.new()
	roll_btn.name = "RollBtn"
	roll_btn.text = "🎲 Tira"
	roll_btn.custom_minimum_size = Vector2(0, 34)
	roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_btn.pressed.connect(_on_roll_dice)
	dice_row.add_child(roll_btn)

	var manual_chk := CheckButton.new()
	manual_chk.name = "ManualDiceChk"
	manual_chk.text = "Tiri manuali"
	manual_chk.button_pressed = GameState.manual_dice
	manual_chk.add_theme_font_size_override("font_size", 12)
	manual_chk.tooltip_text = "Se attivo, tiri tu i dadi dove la regola lo prevede; altrimenti li tira il sistema."
	manual_chk.toggled.connect(func(on): GameState.manual_dice = on)
	dice_panel.add_child(manual_chk)

	var dice_hint := Label.new()
	dice_hint.name = "DiceHint"
	dice_hint.text = ""
	dice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_hint.add_theme_font_size_override("font_size", 11)
	dice_hint.add_theme_color_override("font_color", UITheme.MUTED)
	dice_panel.add_child(dice_hint)

	# --- Sezione: Punti Vittoria ---
	var sec_vp := UITheme.section("Punti Vittoria")
	right_vbox.add_child(sec_vp["panel"])
	var vp_label := Label.new()
	vp_label.name = "VPLabel"
	vp_label.text = "Punti Vittoria: 0"
	vp_label.add_theme_font_size_override("font_size", 20)
	vp_label.add_theme_color_override("font_color", UITheme.GREEN)
	sec_vp["vbox"].add_child(vp_label)

	var tour_label2 := Label.new()
	tour_label2.name = "TourLabel"
	tour_label2.text = "Tour: —"
	tour_label2.add_theme_font_size_override("font_size", 13)
	tour_label2.add_theme_color_override("font_color", UITheme.MUTED)
	sec_vp["vbox"].add_child(tour_label2)

	# --- Sezione: Registro di Bordo (occupa lo spazio rimanente) ---
	var sec_log := UITheme.section("Registro di Bordo")
	sec_log["panel"].size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(sec_log["panel"])

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec_log["vbox"].add_child(log_scroll)

	log_display = RichTextLabel.new()
	log_display.name = "LogDisplay"
	log_display.bbcode_enabled = true
	log_display.fit_content = false
	log_display.scroll_following = true
	log_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_display.add_theme_font_size_override("normal_font_size", 12)
	log_display.add_theme_color_override("default_color", Color(0.82, 0.88, 0.82))
	log_scroll.add_child(log_display)

func _build_status_rows(parent: Control) -> void:
	var rows := [
		["Position", "Sistema: —"],
		["Months",   "Mesi: 0 / 0"],
		["Planet",   "Pianeta: —"],
	]
	for row in rows:
		var lbl := Label.new()
		lbl.name = row[0]
		lbl.text = row[1]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		parent.add_child(lbl)

	# Traccia del Tempo (6.8): quante ore mancano al prossimo Controllo del Rifornimento
	var time_lbl := Label.new()
	time_lbl.name = "TimeTrackLabel"
	time_lbl.text = "Traccia Tempo: — / — h (prossimo Controllo del Rifornimento)"
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	parent.add_child(time_lbl)
	var time_bar := ProgressBar.new()
	time_bar.name = "TimeTrackBar"
	time_bar.custom_minimum_size = Vector2(0, 12)
	time_bar.show_percentage = false
	time_bar.add_theme_color_override("font_color", Color.TRANSPARENT)
	var time_bar_style := StyleBoxFlat.new()
	time_bar_style.bg_color = Color(0.4, 0.75, 1.0)
	time_bar_style.set_corner_radius_all(3)
	time_bar.add_theme_stylebox_override("fill", time_bar_style)
	var time_bar_bg := StyleBoxFlat.new()
	time_bar_bg.bg_color = Color(0.1, 0.18, 0.28)
	time_bar_bg.set_corner_radius_all(3)
	time_bar.add_theme_stylebox_override("background", time_bar_bg)
	parent.add_child(time_bar)

	# Rifornimenti spedizione: barra visiva
	var sup_lbl := Label.new()
	sup_lbl.name = "Supply"
	sup_lbl.text = "Rifornimenti shuttle: 6  |  spedizione: 0"
	sup_lbl.add_theme_font_size_override("font_size", 12)
	sup_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	parent.add_child(sup_lbl)
	var sup_bar := ProgressBar.new()
	sup_bar.name = "SupplyBar"
	sup_bar.custom_minimum_size = Vector2(0, 12)
	sup_bar.show_percentage = false
	sup_bar.add_theme_color_override("font_color", Color.TRANSPARENT)
	var sup_bar_style := StyleBoxFlat.new()
	sup_bar_style.bg_color = Color(0.3, 0.85, 0.5)
	sup_bar_style.set_corner_radius_all(3)
	sup_bar.add_theme_stylebox_override("fill", sup_bar_style)
	var sup_bar_bg := StyleBoxFlat.new()
	sup_bar_bg.bg_color = Color(0.1, 0.22, 0.14)
	sup_bar_bg.set_corner_radius_all(3)
	sup_bar.add_theme_stylebox_override("background", sup_bar_bg)
	parent.add_child(sup_bar)

	var rows2 := [
		["ExpTime",  "Ore spedizione: 0"],
		["Damage",   "Danni: 0"],
	]
	for row in rows2:
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
		# Tooltip: nome + Valore Intelligenza (3.3).
		var box_ctrl := box as Control
		if box_ctrl:
			box_ctrl.tooltip_text = "%s — Intelligenza %d" % [c.get("name", key), int(c.get("intelligence", 0))]
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

# Segnalini dei robot/strumenti imbarcati (mostrati durante la spedizione).
func _refresh_gear_counters() -> void:
	var grid := find_child("GearCounters", true, false) as GridContainer
	var title := find_child("GearTitle", true, false) as Label
	if not grid:
		return
	for c in grid.get_children():
		grid.remove_child(c)
		c.free()
	var show := GameState.expedition_pos > 0 and GameState.expedition_gear.size() > 0
	if title: title.visible = show
	if not show:
		return
	for k in GameState.expedition_gear:
		var u := GameData.get_unit(k)
		var folder := "bots" if GameData.get_bot_keys().has(k) else "tools"
		var box := VBoxContainer.new()
		box.tooltip_text = u.get("name", k)
		box.add_theme_constant_override("separation", 0)
		var tex := TextureRect.new()
		var path := "res://assets/%s/%s.png" % [folder, u.get("img", "")]
		if ResourceLoader.exists(path):
			tex.texture = load(path)
		tex.custom_minimum_size = Vector2(46, 46)
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var damaged: bool = k in GameState.damaged_gear
		tex.modulate = Color(0.5, 0.3, 0.3, 0.7) if damaged else Color(1, 1, 1)
		box.add_child(tex)
		var lb := Label.new()
		lb.text = "guasto" if damaged else u.get("name", k)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 8)
		lb.add_theme_color_override("font_color", Color(1, 0.5, 0.5) if damaged else Color(0.8, 0.85, 0.9))
		box.add_child(lb)
		grid.add_child(box)

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
	var img_w: float = float(env.get("w", 1000))
	var img_h: float = float(env.get("h", 1400))
	# Calcola la scala per far stare l'INTERA mappa nello spazio disponibile
	# (larghezza del pannello, altezza meno titolo e pannello caratteristiche).
	var avail_w: float = max(left_panel.size.x - 16, 360.0)
	var avail_h: float = max(left_panel.size.y - 28 - 158, 360.0)
	env_scale = min(avail_w / img_w, avail_h / img_h)
	var iw: float = img_w * env_scale
	var ih: float = img_h * env_scale
	env_map.texture = load(env.get("img", ""))
	env_map.size = Vector2(iw, ih)
	env_canvas.size = Vector2(iw, ih)
	# Centra orizzontalmente la mappa nel pannello
	env_canvas.position = Vector2(max((left_panel.size.x - iw) * 0.5, 4.0), 28)

	var dx: float = float(env.get("dx", 168.0))
	var bsize: float = dx * env_scale * 0.92
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
	_refresh_planet_panel()

func _environ_hex_screen_pos(hex_id: int) -> Vector2:
	var cell: Dictionary = GameState.environ_grid.get(hex_id, {})
	return Vector2(cell.get("x", 0.0), cell.get("y", 0.0)) * env_scale

# Mostra le caratteristiche del pianeta sotto la mappa di superficie.
func _refresh_planet_panel() -> void:
	var lbl := find_child("PlanetInfo", true, false) as RichTextLabel
	if not lbl:
		return
	var a := GameState.planet_attrs
	var atmo: String = a.get("atmosphere", "Normal")
	var bb := "[b]%s[/b]\n" % GameState.current_planet
	bb += "Gravità: %s · Atmosfera: %s\n" % [GameData.gravity_it(GameState.planet_gravity), GameData.atmosphere_it(atmo)]
	bb += "Idrografia: %d%% · Geologia: %s · Supporto vitale: %d\n" % [
		int(a.get("hydro", 0)), str(a.get("geology", "—")), int(a.get("lsv", 0))]
	var note := GameData.atmosphere_note(atmo)
	if note != "":
		bb += "[color=#ffcc66]⚠ %s[/color]" % note
	lbl.text = bb

func _refresh_environ_buttons() -> void:
	for hex_id in GameState.environ_grid:
		var btn := env_canvas.find_child("Env_%d" % hex_id, false, false) as Button
		if not btn:
			continue
		var explored: bool = GameState.environ_grid[hex_id].get("explored", false)
		var is_pos: bool = (hex_id == GameState.expedition_pos)
		var reachable: bool = GameState.can_move_expedition(hex_id)
		var hasty: bool = GameState.can_hasty_move(hex_id)

		var fill := Color(0, 0, 0, 0)
		var border := Color(0, 0, 0, 0)
		var bw := 0
		btn.text = ""
		if is_pos:
			# Segnalino squadra: Rover (R) o a piedi (P) a seconda del mezzo scelto (5.7).
			fill = Color(0.2, 0.8, 1.0, 0.35)
			border = Color(0.3, 0.9, 1.0, 1.0)
			bw = 4
			btn.text = "R" if GameState.expedition_on_rover() else "P"
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			btn.add_theme_font_size_override("font_size", 20)
		elif hex_id == GameState.landing_hex and GameState.landing_hex > 0:
			# Lo shuttle resta posato sull'esagono di atterraggio (5.6).
			border = Color(1.0, 0.7, 0.2, 0.9)
			bw = 3
			btn.text = "S"
			btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
			btn.add_theme_font_size_override("font_size", 18)
		elif reachable:
			fill = Color(1.0, 1.0, 1.0, 0.16)
			border = Color(1.0, 0.95, 0.5, 0.9)
			bw = 3
		elif hasty:
			# Raggiungibile con movimento affrettato (6.3): contorno tenue
			border = Color(0.6, 0.7, 1.0, 0.35)
			bw = 1
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
		var clickable := reachable or hasty
		btn.disabled = not clickable
		btn.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
		if hasty and not reachable:
			btn.tooltip_text = "Movimento affrettato (6.3)"

func _on_environ_hex_clicked(hex_id: int) -> void:
	if GameState.can_move_expedition(hex_id):
		GameState.move_expedition(hex_id)            # mossa normale (adiacente)
	elif GameState.can_hasty_move(hex_id):
		GameState.hasty_move_to(hex_id)              # movimento affrettato (6.3)

# Badge translucido per i titoli sovrapposti alle mappe (leggibilità sull'immagine).
func _style_map_title(lbl: Label) -> void:
	lbl.add_theme_color_override("font_color", UITheme.CYAN)
	lbl.add_theme_font_size_override("font_size", 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.82)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = UITheme.BORDER
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	lbl.add_theme_stylebox_override("normal", sb)

func _update_left_panel_mode() -> void:
	var on_surface := GameState.current_phase == GameState.Phase.EXPEDITION \
		or (GameState.current_phase == GameState.Phase.PARAGRAPH and GameState.expedition_pos > 0) \
		or not GameState.current_creature.is_empty()
	# Durante la preparazione la sinistra mostra la squadra (drag-and-drop)
	if _prep_open and on_surface:
		_prep_open = false
	if prep_display: prep_display.visible = _prep_open and not on_surface
	if interstellar_display: interstellar_display.visible = not on_surface and not _prep_open
	if environ_display:
		environ_display.visible = on_surface
		if on_surface:
			if env_loaded_id != GameState.current_environ_id:
				_load_environ_view()
			else:
				_refresh_environ_buttons()

func _init_audio() -> void:
	sfx = AudioStreamPlayer.new()
	sfx.name = "Sfx"
	add_child(sfx)
	for key in ["click", "page", "encounter", "success", "hit", "save"]:
		var p := "res://assets/audio/%s.wav" % key
		if ResourceLoader.exists(p):
			_sounds[key] = load(p)

# Riproduce un effetto sonoro (no-op se l'asset non è disponibile).
func _play(key: String) -> void:
	if sfx and _sounds.has(key):
		sfx.stream = _sounds[key]
		sfx.play()

# Breve dissolvenza in entrata del testo del paragrafo, come "cambio pagina".
func _flash_paragraph() -> void:
	var pd := find_child("ParagraphText", true, false) as Control
	if not pd:
		return
	pd.modulate = Color(1, 1, 1, 0.15)
	var tw := create_tween()
	tw.tween_property(pd, "modulate", Color(1, 1, 1, 1), 0.22)

func _connect_signals() -> void:
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.state_updated.connect(_update_display)
	GameState.paragraph_request.connect(_on_paragraph_request)
	GameState.choices_resolved.connect(_clear_choices)
	GameState.message_posted.connect(_on_message)
	GameState.encounter_started.connect(_on_encounter_started)
	GameState.encounter_ended.connect(_on_encounter_ended)
	GameState.environ_changed.connect(_on_environ_changed)
	GameState.die_rolled.connect(_on_die_rolled)
	GameState.combat_resolved.connect(_on_combat_resolved)
	GameState.game_saved.connect(func(): _play("save"))

func _on_combat_resolved(result: String, _detail: String) -> void:
	# A/B = esito netto a favore (poco danno); C/D/E = colpo duro alla spedizione.
	_play("success" if result in ["A", "B"] else "hit")

func _on_environ_changed() -> void:
	_update_left_panel_mode()

func _on_phase_changed(phase: String) -> void:
	_update_display()
	_update_action_buttons(phase)
	if phase == "game_over":
		_append_endtour_summary()

# Riepilogo dettagliato di fine tour: appende al paragrafo finale lo storico
# delle variazioni di Punti Vittoria e il totale, con lo stato dell'equipaggio.
func _append_endtour_summary() -> void:
	var pd := find_child("ParagraphText", true, false) as RichTextLabel
	if not pd:
		return
	var bb := "\n\n[color=#ffd24d]──── Riepilogo del Tour ────[/color]\n"
	for e in GameState.vp_ledger:
		var amt := int(e.get("amount", 0))
		var col := "#9fe0a0" if amt >= 0 else "#ff8866"
		bb += "[color=%s]%+d[/color]  %s\n" % [col, amt, e.get("reason", "")]
	bb += "[color=#ffe27a]── Punti Vittoria finali: [b]%d[/b] ──[/color]\n\n" % GameState.victory_points
	# Stato dell'equipaggio a fine tour
	var alive := 0
	var dead: Array = []
	for k in GameState.crew:
		if GameState.crew[k].get("alive", false):
			alive += 1
		else:
			dead.append(GameState.crew[k].get("name", k))
	bb += "Equipaggio sopravvissuto: [b]%d/7[/b]" % alive
	if dead.size() > 0:
		bb += " — caduti: [color=#ff8866]%s[/color]" % ", ".join(dead)
	bb += "\nSistemi visitati: [b]%d[/b]" % GameState.visited_systems.size()
	pd.append_text(bb)

func _update_action_buttons(phase: String) -> void:
	var btn_orbit := find_child("BtnOrbit", true, false)
	var btn_land := find_child("BtnLand", true, false)
	var btn_return := find_child("BtnReturn", true, false)
	var btn_explore := find_child("BtnExplore", true, false)
	var btn_continue := find_child("BtnContinue", true, false)
	var btn_kill := find_child("BtnKill", true, false)
	var btn_capture := find_child("BtnCapture", true, false)
	var btn_flee := find_child("BtnFlee", true, false)
	var btn_comm := find_child("BtnComm", true, false)
	var btn_strat := find_child("BtnStrat", true, false)
	var btn_heal := find_child("BtnHeal", true, false)

	var creature_active := not GameState.current_creature.is_empty()
	var on_surface := GameState.expedition_pos > 0
	var orbit_decision := GameState.is_orbit_decision() and not creature_active
	# Incontro iniziale (paragrafo della creatura) → si dichiara la strategia (8.2)
	# ¶226: paragrafo d'esito che offre comunque la strategia d'incontro (la creatura resta).
	var initial_creature := creature_active and (GameData.creature_for_paragraph(current_para_num) == GameState.current_creature or current_para_num == 226)
	# Paragrafo-esito che richiede combattimento (8.5)
	var para_low := GameData.get_paragraph_text(current_para_num).to_lower()
	var combat_outcome := creature_active and not initial_creature and ("combattiment" in para_low)
	var encounter_busy := initial_creature or combat_outcome

	# In orbita: scelta netta esplora/riparti
	if btn_land: btn_land.visible = false               # prep+lancio ora nel pannello Disposizione
	if btn_orbit: btn_orbit.visible = orbit_decision    # "Riparti (non esplorare)"
	# "Torna alla Pandora" solo se sbarcati e fuori da un incontro attivo
	if btn_return: btn_return.visible = on_surface and not encounter_busy
	# "Esplora" appare quando l'esagono occupato non è ancora stato esplorato (es. atterraggio)
	var here_explored: bool = GameState.environ_grid.get(GameState.expedition_pos, {}).get("explored", true)
	var here_unexplored: bool = on_surface and not here_explored
	if btn_explore: btn_explore.visible = (phase == "expedition") and not creature_active and here_unexplored
	# Strategia d'incontro (8.2) sul paragrafo iniziale della creatura.
	# ¶033: la comunicazione non può essere scelta.
	var comm_forbidden := current_para_num in [33]
	if btn_comm: btn_comm.visible = initial_creature and not comm_forbidden
	if btn_strat: btn_strat.visible = initial_creature
	# Risoluzione del combattimento (8.5) sui paragrafi-esito di combattimento
	if btn_kill:
		btn_kill.visible = combat_outcome
		if combat_outcome: btn_kill.text = "Uccidi (squadra %d)" % GameState.best_combat("kill")
	if btn_capture:
		btn_capture.visible = combat_outcome and not GameState.pending_no_capture
		if combat_outcome: btn_capture.text = "Cattura (squadra %d)" % GameState.best_combat("capture")
	# Fuggi: strategia all'inizio, oppure ritirata durante il combattimento
	if btn_flee: btn_flee.visible = initial_creature or combat_outcome
	# "Continua" per i paragrafi senza scelte, fuori da orbita e da incontro attivo
	var has_choices: bool = choices_box != null and choices_box.get_child_count() > 0
	if btn_continue: btn_continue.visible = (phase == "paragraph") and not orbit_decision and not has_choices and not encounter_busy
	if btn_heal: btn_heal.visible = (phase == "expedition") and not creature_active and GameState.can_heal()
	var btn_repair := find_child("BtnRepair", true, false)
	if btn_repair: btn_repair.visible = (phase == "expedition") and not creature_active and GameState.can_repair()
	# Acquisizione artefatto (2.6/9.1): sul paragrafo dell'artefatto, in spedizione,
	# se non già acquisito e nessun incontro attivo.
	var btn_artifact := find_child("BtnArtifact", true, false)
	if btn_artifact:
		# La raccolta diretta non vale per i paragrafi con check Intelligenza (¶006/¶175),
		# dove l'acquisizione passa dall'esame dell'oggetto.
		var can_take: bool = (phase == "paragraph") and on_surface and not creature_active \
			and GameData.is_artifact_paragraph(current_para_num) \
			and not GameData.has_intel_check(current_para_num) \
			and not GameState.procedure_available(current_para_num) \
			and not GameState.is_artifact_acquired(current_para_num)
		btn_artifact.visible = can_take
		if can_take:
			var a := GameData.get_artifact(current_para_num)
			btn_artifact.text = "Raccogli: %s (+%d PV al rientro)" % [a.get("name", "artefatto"), int(a.get("vp", 0))]
	# Esame di un oggetto con check Intelligenza (3.3): ¶006/¶175.
	var btn_examine := find_child("BtnExamine", true, false)
	if btn_examine:
		var can_examine: bool = (phase == "paragraph") and on_surface and not creature_active \
			and GameState.intel_check_available(current_para_num)
		btn_examine.visible = can_examine
	# Paragrafo procedurale una-tantum (¶187 raggi, ¶193 struttura).
	var btn_procedure := find_child("BtnProcedure", true, false) as Button
	if btn_procedure:
		var can_proc: bool = (phase == "paragraph") and on_surface and not creature_active \
			and GameState.procedure_available(current_para_num)
		btn_procedure.visible = can_proc
		if can_proc:
			btn_procedure.text = GameState.procedure_label(current_para_num)

func _update_display() -> void:
	# Update status labels
	var s := GameState

	var lbl_pos := find_child("Position", true, false) as Label
	if lbl_pos: lbl_pos.text = "Sistema: %s" % s.current_system

	var lbl_months := find_child("Months", true, false) as Label
	if lbl_months: lbl_months.text = "Mesi: %d / %d (%d rimanenti)" % [s.tour_months_used, s.tour_length, s.months_remaining()]

	var lbl_supply := find_child("Supply", true, false) as Label
	if lbl_supply: lbl_supply.text = "Rifornimenti shuttle: %d  |  spedizione: %d" % [s.shuttle_supply, s.expedition_supply]

	# Barra Rifornimenti spedizione
	var sup_bar := find_child("SupplyBar", true, false) as ProgressBar
	if sup_bar:
		sup_bar.max_value = maxf(1.0, float(GameState.max_planned_supply()))
		sup_bar.value = float(GameState.expedition_supply)

	# Barra Traccia del Tempo (6.8)
	var time_bar := find_child("TimeTrackBar", true, false) as ProgressBar
	var time_lbl := find_child("TimeTrackLabel", true, false) as Label
	var spc := GameState.supply_check_space()
	var pos := GameState.supply_track_pos
	if time_bar:
		time_bar.max_value = maxf(1.0, float(spc))
		time_bar.value = float(pos)
	if time_lbl:
		if GameState.expedition_pos > 0:
			time_lbl.text = "Traccia Tempo: %d / %d h → prossimo Controllo del Rifornimento" % [pos, spc]
		else:
			time_lbl.text = "Traccia Tempo: (fuori spedizione)"

	var lbl_exp := find_child("ExpTime", true, false) as Label
	if lbl_exp: lbl_exp.text = "Ore spedizione: %d" % s.expedition_hours

	var lbl_damage := find_child("Damage", true, false) as Label
	if lbl_damage:
		lbl_damage.text = "Danni: %d" % s.damage_points
		lbl_damage.add_theme_color_override("font_color",
			Color(1, 0.6, 0.5) if s.damage_points > 0 else Color(0.85, 0.85, 0.85))

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
		elif s.is_orbit_decision():
			hint = "Esamina il pianeta, poi decidi: «Esplora il pianeta» (prepara la squadra) o «Riparti»."
		elif phase == "interstellar":
			hint = "Scegli un sistema raggiungibile sulla mappa per spostare la Pandora."
		elif s.expedition_pos > 0 and phase != "paragraph":
			hint = "Muoviti su un esagono adiacente oppure esplora l'esagono attuale."
		elif phase == "paragraph":
			hint = "Leggi e scegli un rimando, oppure premi Continua."
		lbl_hint.text = hint

	# Refresh hex buttons and panel mode
	_refresh_hex_buttons()
	_refresh_crew_counters()
	_refresh_gear_counters()
	_refresh_disposition()
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

			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
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
	if not GameState.can_move_to(hex_id):
		var dist := GameData.get_hex_distance(GameState.pandora_hex, hex_id)
		_post_message("Troppo lontano! Distanza: %d mesi, disponibili: %d" % [dist, GameState.months_remaining()])
		return

	# Muove la Pandora; all'arrivo su un sistema parte il tiro evento (4.2),
	# poi l'ingresso in orbita col paragrafo del pianeta è automatico.
	GameState.move_pandora_to(hex_id)
	_update_display()

# --- Preparazione spedizione drag-and-drop (pannello sinistro) ---------------

func _build_prep_display(parent: Control) -> void:
	prep_display = Control.new()
	prep_display.name = "PrepDisplay"
	prep_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prep_display.visible = false
	parent.add_child(prep_display)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8; vbox.offset_top = 8; vbox.offset_right = -8; vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 6)
	prep_display.add_child(vbox)

	var title := Label.new()
	title.text = "Preparazione della Spedizione"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	var info := Label.new()
	info.name = "PrepDispInfo"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(info)

	var rlbl := Label.new()
	rlbl.text = "Disponibili (trascina o clicca per imbarcare):"
	rlbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(rlbl)

	var rscroll := ScrollContainer.new()
	rscroll.custom_minimum_size = Vector2(0, 230)
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(rscroll)
	var roster := GridContainer.new()
	roster.name = "PrepRoster"
	roster.columns = 4
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster.add_theme_constant_override("h_separation", 4)
	roster.add_theme_constant_override("v_separation", 4)
	rscroll.add_child(roster)
	# Il roster accetta il rilascio per RIMUOVERE dalla squadra
	rscroll.set_drag_forwarding(Callable(), _prep_can_drop.bind("roster"), _prep_drop.bind("roster"))

	var tlbl := Label.new()
	tlbl.text = "Squadra di esplorazione:"
	tlbl.add_theme_font_size_override("font_size", 12)
	tlbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	vbox.add_child(tlbl)

	var team_zone := PanelContainer.new()
	team_zone.name = "PrepTeamZone"
	team_zone.custom_minimum_size = Vector2(0, 130)
	vbox.add_child(team_zone)
	team_zone.set_drag_forwarding(Callable(), _prep_can_drop.bind("team"), _prep_drop.bind("team"))
	var team := GridContainer.new()
	team.name = "PrepTeam"
	team.columns = 4
	team.add_theme_constant_override("h_separation", 4)
	team.add_theme_constant_override("v_separation", 4)
	team_zone.add_child(team)

	var load_lbl := Label.new()
	load_lbl.name = "PrepDispLoad"
	load_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(load_lbl)

	var sup_box := HBoxContainer.new()
	vbox.add_child(sup_box)
	var sup_lbl := Label.new()
	sup_lbl.text = "Rifornimenti:"
	sup_box.add_child(sup_lbl)
	var slider := HSlider.new()
	slider.name = "PrepDispSupply"
	slider.min_value = 0
	slider.max_value = GameData.max_supply()
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_prep_supply_changed)
	sup_box.add_child(slider)
	var sval := Label.new()
	sval.name = "PrepDispSupplyVal"
	sval.custom_minimum_size = Vector2(28, 0)
	sup_box.add_child(sval)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	vbox.add_child(btns)
	var launch := Button.new()
	launch.name = "PrepDispLaunch"
	launch.text = "🚀 Lancia lo shuttle"
	launch.custom_minimum_size = Vector2(0, 42)
	launch.pressed.connect(_on_prep_launch)
	btns.add_child(launch)
	var cancel := Button.new()
	cancel.text = "Annulla"
	cancel.custom_minimum_size = Vector2(0, 42)
	cancel.pressed.connect(_on_prep_cancel)
	btns.add_child(cancel)

func _unit_token_path(key: String) -> String:
	var u := GameData.get_unit(key)
	var folder := "characters"
	if GameData.get_bot_keys().has(key): folder = "bots"
	elif GameData.get_tool_keys().has(key): folder = "tools"
	return "res://assets/%s/%s.png" % [folder, u.get("img", "")]

# --- Pannello Disposizione (centro-basso): dove sta ogni unità (5.6/5.7) ---
func _refresh_disposition() -> void:
	if not find_child("DispositionSection", true, false):
		return
	var orbit := GameState.is_orbit_decision()
	var landed := GameState.expedition_pos > 0
	var on_rover := GameState.expedition_on_rover()
	var buckets := {"Pandora": [], "Shuttle": [], "A piedi": [], "Rover": []}
	for k in GameData.get_character_keys():
		if not GameState.crew.get(k, {}).get("alive", true):
			continue
		buckets[_disp_bucket_for(k, k in GameState.expedition_units, landed, on_rover)].append(k)
	for k in GameData.get_bot_keys() + GameData.get_tool_keys():
		buckets[_disp_bucket_for(k, k in GameState.expedition_gear, landed, on_rover)].append(k)
	# In orbita i click spostano Pandora↔Shuttle (preparazione); sulla superficie
	# spostano una unità tra «con la squadra» e «resta sullo shuttle» (5.6).
	var clickable := orbit or landed
	for bucket in buckets:
		var box := find_child("Disp_%s" % bucket, true, false) as Control
		if box:
			box.set_meta("keys", buckets[bucket])
			box.set_meta("clickable", clickable)
	# 5.7: la spedizione è O nel Rover O a piedi → mostra un solo box di superficie.
	for surf in ["Rover", "A piedi"]:
		var sbox := find_child("Disp_%s" % surf, true, false) as Control
		if sbox:
			var col := sbox.get_parent().get_parent() as Control
			if col:
				col.visible = (surf == "Rover") if on_rover else (surf == "A piedi")
	# Ridispone tutte le pedine con dimensione uniforme che entra in ogni box.
	_relayout_all_disp()
	# Riga informativa: fase + capacità di superficie + scelta del mezzo.
	_refresh_disp_info(orbit, landed, on_rover)
	var prep_ctrl := find_child("DispPrepControls", true, false) as Control
	if prep_ctrl:
		prep_ctrl.visible = orbit
	if orbit:
		var slider := find_child("DispSupply", true, false) as HSlider
		if slider:
			_prep_updating = true
			slider.max_value = max(GameState.max_planned_supply(), GameState.planned_supply)
			slider.value = GameState.planned_supply
			_prep_updating = false
		var sval := find_child("DispSupplyVal", true, false) as Label
		if sval: sval.text = "%d" % GameState.planned_supply
		var ll := find_child("DispLoad", true, false) as Label
		if ll:
			var over := GameState.total_load() > GameState.shuttle_capacity
			ll.text = "Carico %d/%d (unità %d + rif. %d)" % [GameState.total_load(), GameState.shuttle_capacity, GameState.units_weight(), GameState.planned_supply]
			ll.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if over else UITheme.GREEN)
		var launch := find_child("DispLaunch", true, false) as Button
		if launch: launch.disabled = not GameState.prep_valid()

	# Info carico+rifornimenti nei box di superficie
	for surf in ["Shuttle", "A piedi", "Rover"]:
		var info := find_child("DispInfo_%s" % surf, true, false) as Label
		if not info:
			continue
		if landed:
			var cap := GameState.surface_carry_capacity()
			var load_cur := GameState.units_weight()
			var sup := GameState.expedition_supply
			info.text = "Porto %d/%d · Rif. %d" % [load_cur, cap, sup]
			info.visible = true
		elif orbit and surf == "Shuttle":
			var over := GameState.total_load() > GameState.shuttle_capacity
			info.text = "Carico %d/%d" % [GameState.total_load(), GameState.shuttle_capacity]
			info.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if over else Color(0.65, 0.85, 1.0))
			info.visible = true
		else:
			info.visible = false

# Riga informativa sotto i box: fase corrente, capacità di superficie (5.8) e
# pulsante per scegliere il mezzo (Rover/piedi, 5.7).
func _refresh_disp_info(orbit: bool, landed: bool, on_rover: bool) -> void:
	var phase_lbl := find_child("DispPhase", true, false) as Label
	if phase_lbl:
		var txt := ""
		if orbit:
			txt = "Fase: preparazione in orbita · clic su una pedina per spostarla Pandora↔Shuttle"
		elif GameState.expedition_pos > 0:
			# Capacità di superficie (5.8): Rover per gravità o somma dei Porti a piedi.
			var cap := GameState.surface_carry_capacity()
			var mezzo := "Rover" if on_rover else "a piedi"
			var guard := GameState.shuttle_party.size()
			var guard_txt := ("%d a guardia dello shuttle" % guard) if guard > 0 else "shuttle non presidiato"
			txt = "Fase: spedizione su %s (%s) · Porto %d · %s · clic su una pedina per lasciarla allo shuttle" % [GameState.current_planet, mezzo, cap, guard_txt]
		elif GameState.expedition_units.size() > 0:
			txt = "Fase: shuttle in volo verso la superficie"
		phase_lbl.text = txt
	var veh_btn := find_child("DispVehicleBtn", true, false) as Button
	if veh_btn:
		veh_btn.visible = GameState.rover_available()
		veh_btn.text = "Muovi a piedi" if on_rover else "Usa il Rover"

func _on_toggle_vehicle() -> void:
	GameState.toggle_vehicle()
	_refresh_disposition()

# Suddivide le chiavi di un box nei tre gruppi (equipaggio, equipaggiamento, robot).
func _disp_groups(keys: Array) -> Array:
	var char_keys := GameData.get_character_keys()
	var bot_keys := GameData.get_bot_keys()
	var groups := [[], [], []]
	for k in keys:
		if char_keys.has(k):
			groups[0].append(k)
		elif bot_keys.has(k):
			groups[2].append(k)
		else:
			groups[1].append(k)
	return groups

# Numero di righe necessarie per un box dati i gruppi e le colonne disponibili
# (ogni gruppo va a capo, così si vedono le tre categorie su righe distinte).
func _disp_rows_needed(groups: Array, cols: int) -> int:
	var rows := 0
	for g in groups:
		if g.size() > 0:
			rows += int(ceil(float(g.size()) / float(cols)))
	return rows

# Dimensione GLOBALE delle pedine: la più grande in [MIN,MAX] per cui TUTTI i box
# visibili riescono a contenere le proprie pedine senza scroll né tagli.
func _disp_global_tile_size() -> float:
	var gap := 4.0
	var best := 60.0
	for bucket in ["Pandora", "Shuttle", "A piedi", "Rover"]:
		var box := find_child("Disp_%s" % bucket, true, false) as Control
		if box == null or not box.is_visible_in_tree():
			continue
		var keys: Array = box.get_meta("keys", [])
		if keys.is_empty():
			continue
		var w := box.size.x
		var h := box.size.y
		if w < 10.0 or h < 10.0:
			continue
		var groups := _disp_groups(keys)
		var fit := 36.0
		for ti in range(60, 35, -2):
			var t := float(ti)
			var cols := maxi(1, int((w + gap) / (t + gap)))
			var need_h := _disp_rows_needed(groups, cols) * (t + gap)
			if need_h <= h:
				fit = t
				break
		best = minf(best, fit)
	return clampf(best, 36.0, 60.0)

# Ridispone TUTTI i box con la stessa dimensione di pedina (uniforme e che entra).
func _relayout_all_disp() -> void:
	var ts := _disp_global_tile_size()
	for bucket in ["Pandora", "Shuttle", "A piedi", "Rover"]:
		var box := find_child("Disp_%s" % bucket, true, false) as Control
		if box:
			_layout_disp_box(box, ts)

# Dispone le pedine di un box in righe per categoria (equipaggio / equipaggiamento /
# robot), a griglia con posizionamento manuale: pedine uguali, niente scroll.
func _layout_disp_box(box: Control, ts: float) -> void:
	for c in box.get_children():
		c.queue_free()
	var keys: Array = box.get_meta("keys", [])
	var clickable: bool = box.get_meta("clickable", false)
	if keys.is_empty():
		return
	var w := box.size.x
	if w < 10.0:
		return
	var gap := 4.0
	var cols := maxi(1, int((w + gap) / (ts + gap)))
	var y := 0.0
	for g in _disp_groups(keys):
		if g.is_empty():
			continue
		var col := 0
		for k in g:
			var t := _make_disp_tile(str(k), clickable)
			t.position = Vector2(col * (ts + gap), y)
			t.size = Vector2(ts, ts)
			t.custom_minimum_size = Vector2(ts, ts)
			box.add_child(t)
			col += 1
			if col >= cols:
				col = 0
				y += ts + gap
		if col > 0:
			y += ts + gap   # chiude la riga parziale prima del gruppo successivo

# Bucket di un'unità: Pandora (a bordo) / Shuttle (in spedizione non sbarcata) /
# A piedi o Rover (in spedizione, sbarcata, secondo l'uso del rover).
func _unit_bucket(deployed: bool, landed: bool, rover: bool) -> String:
	if not deployed:
		return "Pandora"
	if not landed:
		return "Shuttle"
	return "Rover" if rover else "A piedi"

# Come _unit_bucket, ma sulla superficie le unità rimaste a presidiare lo shuttle
# (5.6) finiscono nel box «Shuttle» invece che in Rover/A piedi.
func _disp_bucket_for(key: String, deployed: bool, landed: bool, rover: bool) -> String:
	if deployed and landed and GameState.unit_stays_at_shuttle(key):
		return "Shuttle"
	return _unit_bucket(deployed, landed, rover)

func _make_disp_tile(key: String, clickable: bool) -> Control:
	var u := GameData.get_unit(key)
	var damaged := key in GameState.damaged_gear
	var base: Control = Button.new() if clickable else PanelContainer.new()
	base.tooltip_text = "%s — Peso %d%s" % [u.get("name", key), int(u.get("weight", 0)), " (danneggiato)" if damaged else ""]
	var tex := TextureRect.new()
	var path := _unit_token_path(key)
	if ResourceLoader.exists(path): tex.texture = load(path)
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if damaged: tex.modulate = Color(0.62, 0.38, 0.38)
	base.add_child(tex)
	if clickable and base is Button:
		(base as Button).pressed.connect(_disp_toggle.bind(key))
	return base

func _disp_toggle(key: String) -> void:
	if GameState.is_orbit_decision():
		# In orbita: preparazione, sposta l'unità Pandora↔Shuttle.
		if GameData.get_character_keys().has(key):
			GameState.toggle_expedition_unit(key)
		else:
			GameState.toggle_gear_unit(key)
		_refresh_disposition()
	elif GameState.expedition_pos > 0:
		# Sulla superficie: l'unità resta sullo shuttle o torna con la squadra (5.6).
		GameState.toggle_shuttle_stay(key)
		_refresh_disposition()

func _make_prep_tile(key: String, in_team: bool) -> Button:
	var u := GameData.get_unit(key)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 58)
	btn.tooltip_text = "%s — Peso %d" % [u.get("name", key), int(u.get("weight", 0))]
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var tex := TextureRect.new()
	var path := _unit_token_path(key)
	if ResourceLoader.exists(path): tex.texture = load(path)
	tex.custom_minimum_size = Vector2(0, 34)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tex)
	var lb := Label.new()
	lb.text = "%s · %dkg" % [u.get("name", key), int(u.get("weight", 0))]
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 8)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lb)
	btn.add_child(v)
	# Click: imbarca/sbarca; Drag: sposta fra roster e squadra
	btn.pressed.connect(_prep_toggle.bind(key))
	btn.set_drag_forwarding(_prep_get_drag.bind(key, btn), Callable(), Callable())
	return btn

func _prep_get_drag(at_position: Vector2, key: String, tile: Button) -> Variant:
	var prev := TextureRect.new()
	var path := _unit_token_path(key)
	if ResourceLoader.exists(path): prev.texture = load(path)
	prev.custom_minimum_size = Vector2(48, 48)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.set_drag_preview(prev)
	return {"key": key}

func _prep_can_drop(_at: Vector2, data: Variant, zone: String) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("key"):
		return false
	var key: String = data["key"]
	var in_team: bool = key in GameState.expedition_units or key in GameState.expedition_gear
	return (zone == "team" and not in_team) or (zone == "roster" and in_team)

func _prep_drop(_at: Vector2, data: Variant, _zone: String) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("key"):
		_prep_toggle(data["key"])

func _prep_toggle(key: String) -> void:
	if GameData.get_character_keys().has(key):
		GameState.toggle_expedition_unit(key)
	else:
		GameState.toggle_gear_unit(key)
	_refresh_prep_display()

func _open_prep_display() -> void:
	if GameState.expedition_units.is_empty():
		GameState.setup_orbit_planet()
	_refresh_prep_display()

func _refresh_prep_display() -> void:
	if not prep_display:
		return
	_prep_updating = true
	var info := find_child("PrepDispInfo", true, false) as Label
	if info:
		var atmo: String = GameState.planet_attrs.get("atmosphere", "Normal")
		var txt := "%s · Gravità %s · Atmosfera %s · Capacità shuttle %d" % [
			GameState.current_system, GameData.gravity_it(GameState.planet_gravity),
			GameData.atmosphere_it(atmo), GameState.shuttle_capacity]
		var note := GameData.atmosphere_note(atmo)
		if note != "": txt += "\n⚠ " + note
		info.text = txt
	var roster := find_child("PrepRoster", true, false) as GridContainer
	var team := find_child("PrepTeam", true, false) as GridContainer
	if roster and team:
		for c in roster.get_children(): roster.remove_child(c); c.free()
		for c in team.get_children(): team.remove_child(c); c.free()
		# Squadra
		for k in GameState.expedition_units + GameState.expedition_gear:
			team.add_child(_make_prep_tile(k, true))
		# Disponibili: personaggi vivi non imbarcati + gear non imbarcato
		for k in GameData.get_character_keys():
			if GameState.crew.get(k, {}).get("alive", true) and not (k in GameState.expedition_units):
				roster.add_child(_make_prep_tile(k, false))
		for k in GameData.get_bot_keys() + GameData.get_tool_keys():
			if not (k in GameState.expedition_gear):
				roster.add_child(_make_prep_tile(k, false))
	var slider := find_child("PrepDispSupply", true, false) as HSlider
	if slider:
		slider.max_value = max(GameState.max_planned_supply(), GameState.planned_supply)
		slider.value = GameState.planned_supply
	var sval := find_child("PrepDispSupplyVal", true, false) as Label
	if sval: sval.text = "%d" % GameState.planned_supply
	var load_lbl := find_child("PrepDispLoad", true, false) as Label
	if load_lbl:
		var over := GameState.total_load() > GameState.shuttle_capacity
		# Breakdown esplicito: i Punti Rifornimento pesano 1 ciascuno (5.3) e contano
		# nel carico insieme alle unità.
		load_lbl.text = "Carico: %d / %d   (unità %d + rifornimenti %d)" % [
			GameState.total_load(), GameState.shuttle_capacity,
			GameState.units_weight(), GameState.planned_supply]
		load_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if over else Color(0.6, 1, 0.6))
	var launch := find_child("PrepDispLaunch", true, false) as Button
	if launch: launch.disabled = not GameState.prep_valid()
	_prep_updating = false

# --- Pannello di preparazione della spedizione (vecchio overlay, non più usato) ---

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

	_add_prep_section(list_vbox, "Robot (clicca per imbarcare):")
	_build_gear_grid(list_vbox, GameData.get_bot_keys(), "bots")

	_add_prep_section(list_vbox, "Strumenti (clicca per imbarcare):")
	_build_gear_grid(list_vbox, GameData.get_tool_keys(), "tools")

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

# Griglia di caselle-segnalino (token originale + nome/peso) per robot/strumenti.
func _build_gear_grid(parent: Control, keys: Array, folder: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for k in keys:
		var u := GameData.get_unit(k)
		var btn := Button.new()
		btn.name = "PrepGear_%s" % k
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(104, 92)
		btn.tooltip_text = "%s — %s (Peso %d)" % [u.get("name", k), u.get("desc", ""), int(u.get("weight", 0))]
		btn.toggled.connect(_on_prep_gear_toggled.bind(k))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 1)
		var tr := TextureRect.new()
		var path := "res://assets/%s/%s.png" % [folder, u.get("img", "")]
		if ResourceLoader.exists(path):
			tr.texture = load(path)
		tr.custom_minimum_size = Vector2(0, 50)
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tr)
		var lb := Label.new()
		lb.text = "%s\n%dkg" % [u.get("name", k), int(u.get("weight", 0))]
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		lb.add_theme_font_size_override("font_size", 9)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(lb)
		btn.add_child(v)
		grid.add_child(btn)

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
		# Peso/Porto/Velocità EFFICACI: includono i modificatori dell'equipaggiamento
		# d'atmosfera del pianeta in orbita (rig/respiratore, regola 5.2).
		chk.text = "%s — Catt %d / Ucc %d · Peso %d · Porto %d · Vel %d" % [
			u.get("name", k), u.get("capture", 0), u.get("kill", 0),
			GameState.effective_char_stat(k, "weight"),
			GameState.effective_char_stat(k, "port"),
			GameState.effective_char_stat(k, "speed")]
		chk.disabled = not GameState.crew.get(k, {}).get("alive", true)
	# Robot e strumenti imbarcabili (caselle-segnalino)
	for k in GameData.get_bot_keys() + GameData.get_tool_keys():
		var gbtn := find_child("PrepGear_%s" % k, true, false) as Button
		if not gbtn:
			continue
		gbtn.button_pressed = k in GameState.expedition_gear
		gbtn.modulate = Color(1, 1, 1) if k in GameState.expedition_gear else Color(0.72, 0.72, 0.72)
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
	# Aggiorna il pannello disposizione (dove ora vivono prep e rifornimenti).
	_refresh_disposition()

func _on_prep_cancel() -> void:
	_prep_open = false
	_update_left_panel_mode()

func _on_prep_launch() -> void:
	if not GameState.prep_valid():
		return
	_prep_open = false
	var die := randi_range(1, 6)
	_set_dice_result(die)
	GameState.launch_expedition(die)

func _on_leave_orbit() -> void:
	GameState.leave_orbit()

func _on_land() -> void:
	# "Esplora il pianeta": apre la preparazione (squadra drag-and-drop a sinistra)
	if not GameState.is_orbit_decision():
		return
	_prep_open = true
	_open_prep_display()
	_update_left_panel_mode()

func _on_strategy(strategy: String) -> void:
	GameState.choose_encounter_strategy(strategy)

func _on_continue() -> void:
	# A Tour concluso (GAME_OVER) il "Continua" non riprende il gioco né rientra in orbita.
	if GameState.current_phase == GameState.Phase.GAME_OVER:
		GameState.current_paragraph = 0
		_update_display()
		return
	# Chiude il paragrafo corrente e torna alla fase appropriata
	GameState.current_paragraph = 0
	if GameState.expedition_pos > 0:
		# Un eventuale incontro è concluso (esito narrativo risolto)
		GameState.current_creature = ""
		GameState.creature_rating = 0
		GameState.set_phase(GameState.Phase.EXPEDITION)
		_show_expedition_panel()
	elif GameState.current_system != "" and GameState.current_system != "Sol" and GameState.current_planet == "":
		# Dopo un evento interstellare: entra in orbita e mostra il pianeta (decisione)
		GameState.enter_orbit()
	else:
		GameState.set_phase(GameState.Phase.INTERSTELLAR)

func _on_return_to_pandora() -> void:
	GameState.return_to_pandora()

func _on_acquire_artifact() -> void:
	if GameState.acquire_artifact(current_para_num):
		_update_display()
		_update_action_buttons(GameState.phase_name(GameState.current_phase))

func _on_examine() -> void:
	# Risolve il check Intelligenza del paragrafo (3.3); può rimandare ad altro paragrafo.
	GameState.resolve_intel_check(current_para_num)
	_update_display()
	_update_action_buttons(GameState.phase_name(GameState.current_phase))

func _on_procedure() -> void:
	# Risolve un paragrafo procedurale una-tantum (¶187/¶193); può rimandare.
	GameState.resolve_procedure(current_para_num)
	_update_display()
	_update_action_buttons(GameState.phase_name(GameState.current_phase))

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
	# All'inizio dell'incontro «Fuggi» è una strategia (8.2); durante il combattimento è una ritirata.
	if not GameState.current_creature.is_empty() and GameData.creature_for_paragraph(current_para_num) == GameState.current_creature:
		GameState.choose_encounter_strategy("flee")
	else:
		GameState.flee_encounter()
		_show_expedition_panel()

func _on_heal() -> void:
	GameState.heal_wounded()
	_show_expedition_panel()

func _on_repair() -> void:
	GameState.repair_gear()
	_show_expedition_panel()

func _on_save() -> void:
	GameState.save_game()

func _on_menu() -> void:
	# Torna al menu principale (lo stato resta in memoria; usa Salva per conservarlo).
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# --- Riferimento regole: overlay con le tabelle originali del gioco -----------
func _toggle_charts() -> void:
	if charts_overlay and is_instance_valid(charts_overlay):
		charts_overlay.queue_free()
		charts_overlay = null
		return
	_build_charts_overlay()

func _build_charts_overlay() -> void:
	_play("click")
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	charts_overlay = panel

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.12, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16; v.offset_top = 12; v.offset_right = -16; v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	var title := Label.new()
	title.text = "📖 Tabelle di riferimento"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕ Chiudi"
	close_btn.pressed.connect(_toggle_charts)
	header.add_child(close_btn)

	var flow := HFlowContainer.new()
	v.add_child(flow)
	for c in CHARTS:
		var b := Button.new()
		b.text = c[1]
		b.pressed.connect(_show_chart.bind(c[0]))
		flow.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var tex := TextureRect.new()
	tex.name = "ChartImage"
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tex)

	_show_chart(CHARTS[0][0])

func _show_chart(filename: String) -> void:
	if not charts_overlay:
		return
	var tex := charts_overlay.find_child("ChartImage", true, false) as TextureRect
	if not tex:
		return
	var path := "res://assets/charts/%s" % filename
	if ResourceLoader.exists(path):
		tex.texture = load(path)

func _on_encounter_started(creature_name: String) -> void:
	_play("encounter")
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
		bb += _creature_combat_summary() + "\n\n"
		bb += "Modificatori creatura — Intelligenza: %d · Combattimento: %d · Aggressività: %d · Velocità: %d\n\n" % [
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

func _on_die_rolled(value: int, _purpose: String) -> void:
	# Mostra il risultato dei tiri automatici gestiti dal sistema
	_set_dice_result(value)

func _on_roll_dice() -> void:
	# Il controllo (4.0) e l'evento (4.2) interstellari usano DUE dadi (2-12);
	# gli altri tiri usano un dado solo.
	var p: String = GameState.pending_die_purpose
	# Tiri a DUE dadi: controllo/evento interstellare (4.0/4.2) e gli eventi 4.2 che
	# confrontano 2 dadi con un Valore di Intelligenza/creatura (¶044, ¶061, ¶084).
	var two_dice := GameState.awaiting_die_roll and (
		p == "interstellar_event" or p == "interstellar_check"
		or p == "event_044" or p == "event_061" or p == "event_084")
	var die := (randi_range(1, 6) + randi_range(1, 6)) if two_dice else randi_range(1, 6)
	_set_dice_result(die)

	if GameState.awaiting_die_roll:
		GameState.awaiting_die_roll = false
		match GameState.pending_die_purpose:
			"interstellar_check":
				GameState.resolve_interstellar_check(die)
			"interstellar_event":
				GameState.resolve_interstellar_event(die)
			"landing":
				GameState.land_on_planet(die)
				return
			"supply_check":
				# Controllo del Rifornimento (7.2): risolve un controllo in coda e, se ne
				# restano altri, richiede subito un nuovo tiro al giocatore (6.8 loop multiplo).
				GameState.resolve_pending_supply_check(die)
				return
			"event_044", "event_055", "event_058", "event_061", "event_084":
				# Tiro manuale per un paragrafo-evento interstellare in attesa (4.2).
				GameState.resolve_event_die(die)
				return

func _set_dice_result(val: int) -> void:
	var lbl := find_child("DiceResult", true, false) as Label
	if lbl: lbl.text = str(val)

# Box coi Valori calcolati dal sistema (8.4) per le condizioni del paragrafo.
func _computed_values_box(text: String) -> String:
	var low := text.to_lower()
	var rows: Array = []
	if "aggressività" in low or "aggressivita" in low:
		rows.append("Aggressività creatura: [b]%d[/b]" % GameState.creature_attr("aggression"))
	if "velocità" in low or "velocita" in low:
		rows.append("Velocità creatura: [b]%d[/b]  (squadra: max %d, min %d)" % [
			GameState.creature_attr("speed"), GameState.expedition_max_speed(), GameState.expedition_min_speed()])
	if "intelligenza" in low:
		rows.append("Intelligenza creatura: [b]%d[/b]" % GameState.creature_attr("intel"))
	if rows.is_empty():
		return ""
	return "\n\n[color=#88ccff]Calcolato dal sistema (8.4):[/color]\n• " + "\n• ".join(rows)

# Riepilogo dei Valori utili per l'incontro: valutazione della creatura per l'esagono
# (8.4) e i migliori valori della squadra (Uccidi/Cattura) con la forbice di Velocità.
func _creature_combat_summary() -> String:
	if GameState.current_creature.is_empty():
		return ""
	var kill: int = GameState.best_combat("kill")
	var capt: int = GameState.best_combat("capture")
	var s := "[color=#ffd24d]Valutazione creatura (esagono): [b]%d[/b][/color]\n" % GameState.creature_rating
	s += "[color=#9fe0a0]Squadra — Uccidi: [b]%d[/b]  ·  Cattura: [b]%d[/b][/color]\n" % [kill, capt]
	s += "[color=#9fc6e0]Velocità squadra: max [b]%d[/b] · min [b]%d[/b][/color]" % [
		GameState.expedition_max_speed(), GameState.expedition_min_speed()]
	return s

# Anteprima delle probabilità d'esito del combattimento (8.6/8.7): per Uccidi e
# Cattura mostra la percentuale di ciascuna lettera (A-E) della Tabella sul tiro
# 1d6, con l'esito e i Punti Danno relativi alla modalità.
func _combat_odds_box() -> String:
	if GameState.current_creature.is_empty():
		return ""
	var order := ["A", "B", "C", "D", "E"]
	var s := "\n\n[color=#88ccff]Probabilità d'esito (tiro 1d6):[/color]"
	for mode in [["kill", "Uccidi", false], ["capture", "Cattura", true]]:
		if mode[0] == "capture" and GameState.pending_no_capture:
			continue
		var dist: Dictionary = GameState.combat_odds(mode[0])
		var parts: Array = []
		for code in order:
			if dist.has(code):
				var pct := int(round(float(dist[code]) * 100.0 / 6.0))
				parts.append("%s (%s) %d%%" % [code, _combat_result_label(code, bool(mode[2])), pct])
		s += "\n[b]%s[/b]: %s" % [mode[1], " · ".join(parts)]
	return s

# Descrizione breve dell'esito di una lettera di risultato (8.7), per modalità.
func _combat_result_label(code: String, as_capture: bool) -> String:
	var dmg := {"A": 1, "B": 4 if as_capture else 2, "C": 8 if as_capture else 4,
		"D": 8, "E": 12 if as_capture else 8}
	var escapes: bool = (code == "E") or (code == "D" and as_capture)
	var verb := "fugge" if escapes else ("catturata" if as_capture else "uccisa")
	return "%s, −%d" % [verb, int(dmg.get(code, 0))]

func _on_paragraph_request(para_num: int) -> void:
	_play("page")
	_flash_paragraph()
	current_para_num = para_num
	var text := GameData.get_paragraph_text(para_num)

	var title_lbl := find_child("ParaTitle", true, false) as Label
	if title_lbl: title_lbl.text = "Paragrafo %03d" % para_num

	# Questo paragrafo è l'incontro di una creatura attualmente in corso?
	# ¶226 mantiene la creatura (Draloid/Oraloid) e offre la strategia.
	var creature := GameData.creature_for_paragraph(para_num)
	var is_creature_here := (creature != "" and creature == GameState.current_creature) or (para_num == 226 and not GameState.current_creature.is_empty())

	var para_display := find_child("ParagraphText", true, false) as RichTextLabel
	if para_display:
		var bb := ""
		if is_creature_here:
			# Segnalino originale della creatura + valutazione, sopra al testo
			var cpath := "res://assets/creatures/%s.png" % GameData.get_creature(creature).get("img", "")
			if ResourceLoader.exists(cpath):
				bb += "[center][img=150]" + cpath + "[/img][/center]\n"
			bb += "[center][b]%s[/b][/center]\n\n" % creature
			bb += _creature_combat_summary() + "\n\n"
		else:
			# Illustrazione narrativa dell'evento (se presente)
			var img_path := GameData.get_event_image_path(para_num)
			if not img_path.is_empty():
				bb += "[center][img=360]" + img_path + "[/img][/center]\n\n"
		# «Come ci sei arrivato»: tiri della Matrice di Esplorazione, instradamento
		# degli snodi 6.5 e controlli di rifornimento, così la logica di scelta del
		# paragrafo è chiara (non solo nel log). Mostrato per esplorazione/creatura/evento.
		if GameState.expedition_pos > 0 and (GameState.encounter_trail != "" or GameState.encounter_formulas != ""):
			# Narrazione dell'azione: mostrata SEMPRE per intero (è il centro dell'azione).
			var narr := GameState.encounter_trail.strip_edges()
			bb += "[bgcolor=#10243a]  [color=#7fc7ff]Cosa succede:[/color]\n[color=#d6e8c6]%s[/color]" % narr
			# Formule e controlli: sezione COLLASSABILE (espandi/comprimi col link).
			if GameState.encounter_formulas != "":
				var formulas := GameState.encounter_formulas.strip_edges()
				var n_formulas := formulas.split("\n").size()
				if _show_full_trail:
					bb += "\n[url=trail_expand][color=#ffd24d]▲ nascondi formule e controlli[/color][/url]\n[color=#9fb8d6]%s[/color]" % formulas
				else:
					bb += "\n[url=trail_expand][color=#ffd24d]▶ formule e controlli (%d)[/color][/url]" % n_formulas
			bb += "  [/bgcolor]\n\n"
		# In orbita i rimandi del paragrafo (opzioni d'atterraggio) non sono cliccabili:
		# l'atterraggio si determina col tiro alla preparazione (5.4).
		if GameState.is_orbit_decision():
			bb += "[p]" + text + "[/p]"
		else:
			bb += "[p]" + _linkify(text) + "[/p]"
		# Esito risolto dal sistema (rami codificati 8.2/8.5), o valori calcolati.
		if GameState.encounter_outcome_text != "":
			bb += "\n\n[color=#ffd24d]➡ %s[/color]" % GameState.encounter_outcome_text
		elif not GameState.current_creature.is_empty() and not is_creature_here:
			bb += _computed_values_box(text)
		# Anteprima probabilità sui paragrafi-esito che richiedono combattimento (8.5).
		if not GameState.current_creature.is_empty() and not is_creature_here \
				and "combattiment" in text.to_lower():
			bb += _combat_odds_box()
		para_display.bbcode_text = bb

	# Durante un incontro i comandi di combattimento sostituiscono le scelte; in orbita
	# la decisione è esplora/riparti (l'atterraggio si determina col tiro, 5.4).
	if is_creature_here or GameState.is_orbit_decision():
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
	# I paragrafi procedurali (¶187/¶193) gestiscono i propri rimandi tramite il
	# pulsante «Risolvi»: si sopprimono le scelte auto-estratte dal testo.
	var choices := [] if GameState.procedure_available(para_num) else GameData.get_paragraph_choices(para_num)
	var lbl := find_child("ChoicesLabel", true, false) as Label
	if lbl: lbl.visible = choices.size() > 0
	for ch in choices:
		var b := Button.new()
		var label_text: String = ch.label
		if label_text.length() > 90:
			label_text = label_text.substr(0, 88) + "…"
		if ch.has("act"):
			b.text = "▶  %s" % label_text
		else:
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
		if ch.has("act"):
			b.pressed.connect(_on_choice_act.bind(ch.act))
		else:
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
	_play("click")
	GameState.show_paragraph(para)

# Scelta-paragrafo con azione (tiro/condizione): vedi paragraph_choices.json.
func _on_choice_act(act: Dictionary) -> void:
	_play("click")
	GameState.resolve_paragraph_choice(act)

func _on_meta_clicked(meta) -> void:
	if str(meta) == "trail_expand":
		# Espande/comprime la sezione collassabile «Formule e controlli» del centro.
		_show_full_trail = not _show_full_trail
		_on_paragraph_request(current_para_num)
		return
	var n := int(str(meta))
	if n > 0:
		GameState.show_paragraph(n)

# Colore/icona per la voce di diario in base al contenuto (regola: solo estetica).
func _log_decorate(msg: String) -> String:
	var low := msg.to_lower()
	var icon := "▸"
	var col := "#aaffaa"
	if "incontro" in low or "creatura" in low:
		icon = "✦"; col = "#ffd24d"
	elif "punti vittoria" in low or " pv" in low or "+pv" in low:
		icon = "★"; col = "#ffe27a"
	elif "salvata" in low or "caricata" in low:
		icon = "💾"; col = "#9fc6e0"
	elif "ucciso" in low or "danno" in low or "resistenza" in low or "danneggiat" in low:
		icon = "✖"; col = "#ff8866"
	elif "arriva" in low or "orbita" in low or "spedizione" in low or "atterr" in low:
		icon = "➤"; col = "#9fe0a0"
	return "[color=%s]%s[/color] %s" % [col, icon, msg]

# Ricostruisce l'intero Registro di Bordo dalle voci salvate (usato all'avvio
# e dopo un caricamento di partita).
func _render_full_log() -> void:
	if not log_display:
		return
	log_display.clear()
	var lines: Array = []
	for e in GameState.log_entries:
		lines.append(_log_decorate(str(e)))
	log_display.append_text("\n".join(lines))

func _on_message(msg: String) -> void:
	if log_display:
		log_display.append_text("\n" + _log_decorate(msg))

	var hint_lbl := find_child("DiceHint", true, false) as Label
	if hint_lbl and GameState.awaiting_die_roll:
		hint_lbl.text = msg

func _post_message(msg: String) -> void:
	if log_display:
		log_display.append_text("\n[color=#ffaa44]►[/color] " + msg)
