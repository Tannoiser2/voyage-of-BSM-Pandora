extends Control

func _ready() -> void:
	# Build UI programmatically
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -250
	vbox.offset_right = 250
	vbox.offset_top = -200
	vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var title := Label.new()
	title.text = "IL VIAGGIO\nDELLA B.S.M. PANDORA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Versione digitale italiana — SPI 1981"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Continua: visibile solo se esiste un salvataggio su disco.
	if GameState.has_save():
		var continue_btn := Button.new()
		continue_btn.text = "▶ Continua partita"
		continue_btn.custom_minimum_size = Vector2(200, 50)
		continue_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		continue_btn.pressed.connect(_on_continue)
		vbox.add_child(continue_btn)

		var nuovo_label := Label.new()
		nuovo_label.text = "— oppure nuova partita —"
		nuovo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nuovo_label.add_theme_font_size_override("font_size", 12)
		nuovo_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		vbox.add_child(nuovo_label)

	var tour_label := Label.new()
	tour_label.text = "Durata del Tour:"
	tour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tour_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(tour_label)

	for t in [10, 20, 30]:
		var btn := Button.new()
		btn.text = "%d Mesi" % t
		btn.custom_minimum_size = Vector2(200, 50)
		btn.pressed.connect(_on_tour_selected.bind(t))
		vbox.add_child(btn)

	var version_label := Label.new()
	version_label.text = "Prototipo v0.1"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(version_label)

func _on_tour_selected(tour_length: int) -> void:
	GameState.start_new_game(tour_length)
	get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")

func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")
