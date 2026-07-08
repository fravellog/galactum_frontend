extends "res://galactum_screen_base.gd"

var request: HTTPRequest
var status_label: Label
var event_list: VBoxContainer
var total_label: Label


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"BITÁCORA GALÁCTICA",
		"HISTORIAL DEL COMANDANTE"
	)
	status_label = shell["status"] as Label

	var info_bundle: Dictionary = make_margin_panel()
	var info_panel: PanelContainer = info_bundle["panel"] as PanelContainer
	var info_margin: MarginContainer = info_bundle["margin"] as MarginContainer
	info_panel.custom_minimum_size.y = 96
	content_box.add_child(info_panel)

	var info_box: HBoxContainer = HBoxContainer.new()
	info_box.add_theme_constant_override("separation", 12)
	info_margin.add_child(info_box)

	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	info_box.add_child(left)

	left.add_child(make_label("Registro de acciones importantes", 18, COLOR_TEXT))
	left.add_child(make_label("Esta pantalla resume eventos reales derivados desde Neon: nave, alianza, inventario, misiones y conflictos.", 14, COLOR_MUTED))

	total_label = make_label("0 eventos", 18, COLOR_ACCENT)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.custom_minimum_size.x = 170
	info_box.add_child(total_label)

	content_box.add_child(make_section_title("EVENTOS RECIENTES"))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)

	event_list = VBoxContainer.new()
	event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_list.add_theme_constant_override("separation", 12)
	scroll.add_child(event_list)

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_bitacora_completed)

	finish_shell()
	_load_bitacora()


func _load_bitacora() -> void:
	set_status(status_label, "Consultando bitácora...", COLOR_WARN)
	set_footer("Solicitando eventos al backend...")
	clear_children(event_list)
	event_list.add_child(make_label("Cargando eventos del comandante...", 17, COLOR_MUTED))

	var error: int = request.request(
		api_url("/api/v1/player/bitacora"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la solicitud.", COLOR_DANGER)


func _on_bitacora_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer(_extract_error(text, response_code), COLOR_DANGER)
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("La bitácora no llegó en JSON válido.", COLOR_DANGER)
		return

	var response: Dictionary = parsed as Dictionary
	var raw_events: Variant = response.get("eventos", [])

	if typeof(raw_events) != TYPE_ARRAY:
		set_status(status_label, "Datos inválidos", COLOR_DANGER)
		set_footer("El backend no devolvió una lista de eventos.", COLOR_DANGER)
		return

	_show_events(raw_events as Array)


func _show_events(events: Array) -> void:
	clear_children(event_list)
	total_label.text = str(events.size()) + " eventos"

	if events.is_empty():
		event_list.add_child(make_label("Todavía no hay eventos registrados.", 17, COLOR_WARN))
		set_status(status_label, "Sin eventos", COLOR_WARN)
		set_footer("Realiza acciones en el simulador para completar la bitácora.", COLOR_WARN)
		return

	for event_value: Variant in events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		_add_event_card(event_value as Dictionary)

	set_status(status_label, "Bitácora sincronizada", COLOR_OK)
	set_footer("Eventos generados desde datos persistentes en Neon.", COLOR_OK)


func _add_event_card(event: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer
	card.custom_minimum_size.y = 118
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_list.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var icon_label: Label = make_label(_icon_for(str(event.get("tipo", "sistema"))), 25, _color_for(str(event.get("estado", "info"))))
	icon_label.custom_minimum_size.x = 42
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon_label)

	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)

	box.add_child(make_label(str(event.get("titulo", "Evento")), 18, COLOR_ACCENT))
	box.add_child(make_label(str(event.get("descripcion", "Sin descripción.")), 14, COLOR_TEXT))

	var fecha: String = str(event.get("fecha", ""))
	if fecha == "" or fecha == "<null>":
		fecha = "Fecha no registrada"
	box.add_child(make_label("Fecha: " + fecha, 13, COLOR_MUTED))


func _icon_for(tipo: String) -> String:
	var normalized: String = tipo.to_lower()
	if "nave" in normalized:
		return "🚀"
	if "inventario" in normalized:
		return "📦"
	if "mis" in normalized:
		return "✓"
	if "conflicto" in normalized:
		return "⚔"
	if "alianza" in normalized:
		return "🛡"
	if "perfil" in normalized:
		return "👤"
	return "•"


func _color_for(estado: String) -> Color:
	var normalized: String = estado.to_lower()
	if normalized == "ok":
		return COLOR_OK
	if normalized == "warn":
		return COLOR_WARN
	if normalized == "danger":
		return COLOR_DANGER
	return COLOR_ACCENT


func _extract_error(response_text: String, response_code: int) -> String:
	var parsed: Variant = JSON.parse_string(response_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		if response.has("detail"):
			return str(response["detail"])
	return "Error HTTP " + str(response_code)
