class_name UITheme
extends RefCounted

# Tema visivo condiviso, ispirato alla copertina di "Voyage of the BSM Pandora":
# blu notte con accenti ciano e ambra. Tutto costruito da codice (nessun font
# esterno richiesto) così da degradare ovunque.

const BG_TOP := Color("0a0e1c")
const BG_BOTTOM := Color("141a33")
const PANEL := Color("141b33")       # pannelli
const PANEL_HI := Color("1d2747")    # pannelli/bottoni in rilievo
const BORDER := Color("2b3a66")
const BORDER_HI := Color("3f67b6")
const CYAN := Color("46d3e0")        # accento primario (glifi della cover)
const AMBER := Color("f5b942")       # accento titolo
const TEXT := Color("e9edf7")
const MUTED := Color("96a2bf")
const GREEN := Color("7fdd8f")
const RED := Color("ff6b5a")

static func _sb(bg: Color, border_col: Color, border_w: int = 1, radius: int = 8, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(6, pad - 2)
	sb.content_margin_bottom = maxi(6, pad - 2)
	return sb

# Tema applicabile alla radice di una scena.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16

	# Bottoni
	t.set_stylebox("normal", "Button", _sb(PANEL_HI, BORDER, 1, 8, 14))
	t.set_stylebox("hover", "Button", _sb(Color("273357"), BORDER_HI, 1, 8, 14))
	t.set_stylebox("pressed", "Button", _sb(Color("0e1426"), CYAN, 2, 8, 14))
	t.set_stylebox("disabled", "Button", _sb(Color("11162a"), Color("222a44"), 1, 8, 14))
	var focus := _sb(Color(0, 0, 0, 0), CYAN, 2, 8, 14)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", CYAN)
	t.set_color("font_pressed_color", "Button", CYAN)
	t.set_color("font_disabled_color", "Button", Color("66708f"))
	t.set_font_size("font_size", "Button", 16)

	# Pannelli
	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, BORDER, 1, 12, 12))
	t.set_stylebox("panel", "Panel", _sb(PANEL, BORDER, 1, 12, 12))

	# Etichette e testo
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "RichTextLabel", TEXT)

	# Separatori
	var sep := StyleBoxLine.new()
	sep.color = BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)

	return t

# Sfondo a gradiente verticale (blu notte) come TextureRect a tutto schermo.
static func make_background() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP)
	grad.set_color(1, BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 16
	tex.height = 256
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# Pannello-sezione con titolo: ritorna un VBox dentro un PanelContainer.
static func section(title: String) -> Dictionary:
	var pc := PanelContainer.new()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)
	if title != "":
		var h := Label.new()
		h.text = title.to_upper()
		h.add_theme_font_size_override("font_size", 13)
		h.add_theme_color_override("font_color", CYAN)
		vb.add_child(h)
	return {"panel": pc, "vbox": vb}
