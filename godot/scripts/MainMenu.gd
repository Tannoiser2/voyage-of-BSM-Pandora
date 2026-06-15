extends Control

const VERSION := "v0.9.0"

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
	# Pulsante "Novità" (changelog) + etichetta versione.
	var changelog_btn := _menu_button("📋  Novità (changelog)", 44)
	changelog_btn.add_theme_font_size_override("font_size", 15)
	changelog_btn.add_theme_color_override("font_color", UITheme.CYAN)
	changelog_btn.pressed.connect(_show_changelog)
	col.add_child(changelog_btn)

	var version_label := Label.new()
	version_label.text = VERSION
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", UITheme.MUTED)
	col.add_child(version_label)

# Overlay con il changelog (res://CHANGELOG.md), reso leggibile nel menu.
func _show_changelog() -> void:
	if find_child("ChangelogOverlay", false, false):
		return
	var overlay := PanelContainer.new()
	overlay.name = "ChangelogOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.10, 0.97)
	overlay.add_theme_stylebox_override("panel", sb)
	add_child(overlay)

	var margin := MarginContainer.new()
	for m in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 40)
	overlay.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "NOVITÀ"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UITheme.AMBER)
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 15)
	rt.text = _changelog_bbcode()
	scroll.add_child(rt)

	var close := _menu_button("Chiudi", 44)
	close.pressed.connect(overlay.queue_free)
	vb.add_child(close)

# Carica CHANGELOG.md e lo converte in BBCode leggibile (titoli/elenco).
func _changelog_bbcode() -> String:
	var src := "Changelog non disponibile."
	if ResourceLoader.exists("res://CHANGELOG.md") or FileAccess.file_exists("res://CHANGELOG.md"):
		var f := FileAccess.open("res://CHANGELOG.md", FileAccess.READ)
		if f:
			src = f.get_as_text()
	var out := ""
	for line in src.split("\n"):
		var l: String = line
		if l.begins_with("### "):
			out += "[color=#46d3e0][b]" + l.substr(4) + "[/b][/color]\n"
		elif l.begins_with("## "):
			out += "\n[color=#f5b942][b]" + l.substr(3) + "[/b][/color]\n"
		elif l.begins_with("# "):
			out += "[b]" + l.substr(2) + "[/b]\n"
		elif l.begins_with("- "):
			out += "  • " + l.substr(2) + "\n"
		else:
			out += l + "\n"
	return out

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
