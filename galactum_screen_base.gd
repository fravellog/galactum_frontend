extends Control

const COLOR_BG := Color("071126")
const COLOR_OVERLAY := Color(0.02, 0.05, 0.12, 0.76)
const COLOR_PANEL := Color("101827")
const COLOR_PANEL_ALT := Color("0d1728")
const COLOR_BORDER := Color("263b5c")
const COLOR_TEXT := Color("f1f5f9")
const COLOR_MUTED := Color("aab8d0")
const COLOR_ACCENT := Color("77bdfb")
const COLOR_OK := Color("7ee787")
const COLOR_WARN := Color("f0c674")
const COLOR_DANGER := Color("ff7b72")

var content_box: VBoxContainer
var footer_label: Label

func build_shell(title: String, subtitle: String, show_back: bool = true) -> Dictionary:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var space_texture = load("res://fondo_espacio.jpg")
	if space_texture:
		background.texture = space_texture
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		background.modulate = COLOR_BG
	add_child(background)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = COLOR_OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	content_box = VBoxContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 16)
	margin.add_child(content_box)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	content_box.add_child(header)

	if show_back:
		var btn_back := make_button("<- Centro de mando", COLOR_PANEL_ALT)
		btn_back.custom_minimum_size = Vector2(154, 36)
		btn_back.pressed.connect(_return_to_command_center)
		header.add_child(btn_back)

	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size.x = 275
	title_box.add_theme_constant_override("separation", 2)
	header.add_child(title_box)

	var label_title := make_label(title, 26, COLOR_TEXT)
	title_box.add_child(label_title)
	var label_subtitle := make_label(subtitle, 13, COLOR_ACCENT)
	title_box.add_child(label_subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var status_label := make_label("• Preparando conexión...", 14, COLOR_WARN)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.custom_minimum_size.x = 210
	header.add_child(status_label)

	footer_label = make_label("", 14, COLOR_MUTED)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	return {"status": status_label}


func finish_shell():
	if footer_label.get_parent() == null:
		content_box.add_child(footer_label)


func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL))
	return panel


func make_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT))
	return panel


func make_margin_panel() -> Dictionary:
	var panel := make_panel()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	return {"panel": panel, "margin": margin}


func make_label(text_value: String, font_size: int = 16, color: Color = COLOR_TEXT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func make_button(text_value: String, fill_color: Color = COLOR_ACCENT) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(fill_color, 0.95))
	button.add_theme_stylebox_override("hover", _button_style(fill_color.lightened(0.10), 1.0))
	button.add_theme_stylebox_override("pressed", _button_style(fill_color.darkened(0.16), 1.0))
	return button


func make_section_title(text_value: String) -> Label:
	var title := make_label(text_value, 18, COLOR_TEXT)
	title.custom_minimum_size.y = 26
	return title


func set_status(label: Label, text_value: String, color: Color = COLOR_WARN):
	label.text = "• " + text_value
	label.add_theme_color_override("font_color", color)


func set_footer(text_value: String, color: Color = COLOR_MUTED):
	footer_label.text = text_value
	footer_label.add_theme_color_override("font_color", color)


func api_url(path: String) -> String:
	var base := str(APIManager.base_url).strip_edges().trim_suffix("/")
	var clean_path := path
	if not clean_path.begins_with("/"):
		clean_path = "/" + clean_path

	if base.ends_with("/api/v1") and clean_path.begins_with("/api/v1/"):
		return base + clean_path.trim_prefix("/api/v1")

	return base + clean_path


func auth_headers() -> PackedStringArray:
	return APIManager.get_auth_headers()


func clear_children(node: Node):
	for child in node.get_children():
		child.queue_free()


func _return_to_command_center():
	get_tree().change_scene_to_file("res://centro_mando.tscn")


func _panel_style(fill_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _button_style(fill_color: Color, opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill_color, opacity)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
