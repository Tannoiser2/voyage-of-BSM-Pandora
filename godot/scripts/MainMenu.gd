extends Control

func _ready() -> void:
	theme = UITheme.make_theme()
	add_child(UITheme.make_background())

	# Layout a due colonne: copertina grande a sinistra, azioni a destra.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(row)

	# --- Copertina ---
	var cover := _load_cover()
	if cover:
		var cover_rect := TextureRect.new()
		cover_rect.texture = cover
		cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Copertina 1086×1448 (aspetto 0,75): a 600 d'altezza ≈ 450 di larghezza.
		cover_rect.custom_minimum_size = Vector2(465, 620)
		# Cornice sottile attorno alla copertina
		var frame := PanelContainer.new()
		frame.add_child(cover_rect)
		row.add_child(frame)

	# --- Colonna azioni ---
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 14)
	row.add_child(col)

	if cover == null:
		var title := Label.new()
		title.text = "VOYAGE OF THE\nB.S.M. PANDORA"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", UITheme.AMBER)
		col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Adventures on Unknown Worlds"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", UITheme.CYAN)
	col.add_child(subtitle)

	var edition := Label.new()
	edition.text = "Versione digitale italiana · SPI 1981"
	edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edition.add_theme_font_size_override("font_size", 13)
	edition.add_theme_color_override("font_color", UITheme.MUTED)
	col.add_child(edition)

	col.add_child(_spacer(18))

	# Continua: visibile solo se esiste un salvataggio su disco.
	if GameState.has_save():
		var continue_btn := _menu_button("▶  Continua partita", 60)
		continue_btn.add_theme_color_override("font_color", UITheme.GREEN)
		continue_btn.pressed.connect(_on_continue)
		col.add_child(continue_btn)
		col.add_child(_spacer(6))

	var tour_label := Label.new()
	tour_label.text = "NUOVA PARTITA · DURATA DEL TOUR"
	tour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tour_label.add_theme_font_size_override("font_size", 13)
	tour_label.add_theme_color_override("font_color", UITheme.CYAN)
	col.add_child(tour_label)

	for t in [10, 20, 30]:
		var btn := _menu_button("%d Mesi" % t, 54)
		btn.pressed.connect(_on_tour_selected.bind(t))
		col.add_child(btn)

	col.add_child(_spacer(10))
	var version_label := Label.new()
	version_label.text = "Prototipo v0.1"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", UITheme.MUTED)
	col.add_child(version_label)

func _menu_button(text: String, height: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, height)
	b.add_theme_font_size_override("font_size", 18)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# Carica la copertina del gioco dai percorsi noti in assets/ (.png o .jpg), se esiste.
func _load_cover() -> Texture2D:
	for path in [
		"res://assets/cover.png", "res://assets/cover.jpg",
		"res://assets/copertina.png", "res://assets/copertina.jpg",
	]:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

func _on_tour_selected(tour_length: int) -> void:
	GameState.start_new_game(tour_length)
	get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")

func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")
