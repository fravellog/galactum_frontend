extends "res://galactum_screen_base.gd"

var request: HTTPRequest
var status_label: Label
var name_label: Label
var commander_label: Label
var detail_box: VBoxContainer
var energy_bar: ProgressBar
var shield_bar: ProgressBar
var hull_bar: ProgressBar
var energy_label: Label
var shield_label: Label
var hull_label: Label


func _ready() -> void:
	var shell: Dictionary = build_shell("MI NAVE", "ESTADO OPERATIVO Y NAVEGACIÓN")
	status_label = shell["status"] as Label

	var identity_bundle: Dictionary = make_margin_panel()
	var identity: PanelContainer = identity_bundle["panel"] as PanelContainer
	var identity_margin: MarginContainer = identity_bundle["margin"] as MarginContainer
	identity.custom_minimum_size.y = 108
	content_box.add_child(identity)

	var identity_box: VBoxContainer = VBoxContainer.new()
	identity_box.add_theme_constant_override("separation", 5)
	identity_margin.add_child(identity_box)

	commander_label = make_label("Comandante: Cargando...", 16, COLOR_MUTED)
	name_label = make_label("Nave: Cargando...", 22, COLOR_ACCENT)
	identity_box.add_child(commander_label)
	identity_box.add_child(name_label)
	identity_box.add_child(
		make_label(
			"Los datos se obtienen desde GET /ship/estado.",
			14,
			COLOR_MUTED
		)
	)

	content_box.add_child(make_section_title("ESTADO DE LA NAVE"))

	var state_bundle: Dictionary = make_margin_panel()
	var state_panel: PanelContainer = state_bundle["panel"] as PanelContainer
	var state_margin: MarginContainer = state_bundle["margin"] as MarginContainer
	state_panel.custom_minimum_size.y = 186
	content_box.add_child(state_panel)

	var state_box: VBoxContainer = VBoxContainer.new()
	state_box.add_theme_constant_override("separation", 12)
	state_margin.add_child(state_box)

	var energy_data: Dictionary = _add_stat_line(state_box, "Energía")
	energy_label = energy_data["label"] as Label
	energy_bar = energy_data["bar"] as ProgressBar

	var shield_data: Dictionary = _add_stat_line(state_box, "Escudo")
	shield_label = shield_data["label"] as Label
	shield_bar = shield_data["bar"] as ProgressBar

	var hull_data: Dictionary = _add_stat_line(state_box, "Casco")
	hull_label = hull_data["label"] as Label
	hull_bar = hull_data["bar"] as ProgressBar

	content_box.add_child(make_section_title("DATOS DE NAVEGACIÓN"))

	var navigation_panel: PanelContainer = make_panel()
	navigation_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(navigation_panel)

	var navigation_margin: MarginContainer = MarginContainer.new()
	navigation_margin.add_theme_constant_override("margin_left", 20)
	navigation_margin.add_theme_constant_override("margin_top", 16)
	navigation_margin.add_theme_constant_override("margin_right", 20)
	navigation_margin.add_theme_constant_override("margin_bottom", 16)
	navigation_panel.add_child(navigation_margin)

	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	navigation_margin.add_child(detail_box)
	detail_box.add_child(make_label("Cargando datos de navegación...", 16, COLOR_MUTED))

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_state_completed)

	finish_shell()
	_load_ship()


func _add_stat_line(parent: VBoxContainer, label_text: String) -> Dictionary:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	parent.add_child(group)

	var label: Label = make_label(label_text + ": cargando...", 16)
	group.add_child(label)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 18
	group.add_child(bar)

	return {
		"label": label,
		"bar": bar,
	}


func _load_ship() -> void:
	set_status(status_label, "Cargando nave...", COLOR_WARN)
	set_footer("Consultando GET /ship/estado...")

	var error: int = request.request(
		api_url("/ship/estado"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la consulta.", COLOR_DANGER)


func _on_state_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer("No se pudo cargar la nave.", COLOR_DANGER)
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend no devolvió un objeto JSON válido.", COLOR_DANGER)
		return

	var response: Dictionary = parsed as Dictionary
	var ship_data: Variant = response.get("nave", null)

	if typeof(ship_data) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend no devolvió el contrato de nave esperado.", COLOR_DANGER)
		return

	var ship: Dictionary = ship_data as Dictionary
	_show_ship(response, ship)


func _show_ship(response: Dictionary, ship: Dictionary) -> void:
	commander_label.text = "Comandante: " + str(response.get("comandante", "Desconocido"))
	name_label.text = (
		"Nave: "
		+ str(ship.get("nombre", "Sin nombre"))
		+ "  |  Nivel "
		+ str(ship.get("nivel", 1))
	)

	_update_bar(
		energy_label,
		energy_bar,
		"Energía",
		ship.get("energia_actual", 0),
		ship.get("energia_maxima", 100)
	)
	_update_bar(
		shield_label,
		shield_bar,
		"Escudo",
		ship.get("escudo_actual", 0),
		ship.get("escudo_maximo", 100)
	)
	_update_bar(
		hull_label,
		hull_bar,
		"Casco",
		ship.get("casco_actual", 0),
		ship.get("casco_maximo", 100)
	)

	clear_children(detail_box)

	var raw_position: Variant = ship.get("posicion", {})
	var position: Dictionary = {}
	if typeof(raw_position) == TYPE_DICTIONARY:
		position = raw_position as Dictionary

	var movement: String = "En movimiento" if bool(ship.get("en_movimiento", false)) else "En espera"
	var upgrades: String = "Disponibles" if bool(ship.get("mejoras_disponibles", false)) else "No disponibles"

	detail_box.add_child(
		make_label(
			"Posición: X "
			+ str(position.get("x", 0))
			+ " | Y "
			+ str(position.get("y", 0)),
			16
		)
	)
	detail_box.add_child(
		make_label(
			"Velocidad: " + str(ship.get("velocidad", 0)) + " unidades",
			16
		)
	)
	detail_box.add_child(make_label("Estado de movimiento: " + movement, 16, COLOR_MUTED))
	detail_box.add_child(make_label("Mejoras: " + upgrades, 16, COLOR_MUTED))

	set_status(status_label, "Nave conectada", COLOR_OK)
	set_footer("Estado cargado desde FastAPI.", COLOR_OK)


func _update_bar(
	label: Label,
	bar: ProgressBar,
	title: String,
	current: Variant,
	maximum: Variant
) -> void:
	var maximum_value: int = int(maximum)
	if maximum_value < 1:
		maximum_value = 1

	var current_value: int = clampi(int(current), 0, maximum_value)

	label.text = title + ": " + str(current_value) + " / " + str(maximum_value)
	bar.max_value = float(maximum_value)
	bar.value = float(current_value)
