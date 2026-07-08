extends "res://galactum_screen_base.gd"


var list_request: HTTPRequest
var start_request: HTTPRequest
var claim_request: HTTPRequest

var status_label: Label
var list_box: VBoxContainer
var refresh_button: Button


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"MINERÍA",
		"EXTRACCIÓN PERSISTENTE DE ASTEROIDES"
	)

	status_label = shell["status"] as Label

	_build_intro_panel()
	_build_toolbar()
	_build_asteroid_list()
	_setup_requests()

	finish_shell()
	_scan_asteroids()


func _build_intro_panel() -> void:
	var bundle: Dictionary = make_margin_panel()
	var panel: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer

	content_box.add_child(panel)

	var label: Label = make_label(
		"Escanea asteroides reales desde Neon, inicia una extracción y reclama los recursos para sumarlos al inventario persistente.",
		16,
		COLOR_MUTED
	)

	margin.add_child(label)


func _build_toolbar() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content_box.add_child(row)

	var title: Label = make_section_title("ASTEROIDES DISPONIBLES")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	refresh_button = make_button("Actualizar escáner", COLOR_ACCENT)
	refresh_button.custom_minimum_size = Vector2(180, 38)
	refresh_button.pressed.connect(_scan_asteroids)
	row.add_child(refresh_button)


func _build_asteroid_list() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 12)
	scroll.add_child(list_box)

	scroll.resized.connect(_adjust_list_width.bind(scroll))
	call_deferred("_adjust_list_width", scroll)


func _adjust_list_width(scroll: ScrollContainer) -> void:
	if not is_instance_valid(list_box):
		return

	var available_width: float = maxf(0.0, scroll.size.x - 10.0)
	list_box.custom_minimum_size = Vector2(available_width, 0)


func _setup_requests() -> void:
	list_request = HTTPRequest.new()
	start_request = HTTPRequest.new()
	claim_request = HTTPRequest.new()

	add_child(list_request)
	add_child(start_request)
	add_child(claim_request)

	list_request.request_completed.connect(_on_scan_completed)
	start_request.request_completed.connect(_on_start_completed)
	claim_request.request_completed.connect(_on_claim_completed)


func _scan_asteroids() -> void:
	set_status(status_label, "Escaneando asteroides...", COLOR_WARN)
	set_footer("Consultando GET /mining/asteroides en FastAPI...")

	refresh_button.disabled = true
	clear_children(list_box)

	var loading_label: Label = make_label(
		"Escaneando sector espacial...",
		16,
		COLOR_MUTED
	)
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.custom_minimum_size = Vector2(0, 80)
	list_box.add_child(loading_label)

	var error: int = list_request.request(
		api_url("/mining/asteroides"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		refresh_button.disabled = false
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar el escaneo.", COLOR_DANGER)


func _on_scan_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	refresh_button.disabled = false

	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer(_extract_error_message(text), COLOR_DANGER)
		_show_empty_message("No fue posible cargar asteroides.")
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_ARRAY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend no devolvió una lista de asteroides.", COLOR_DANGER)
		_show_empty_message("Respuesta inválida del backend.")
		return

	var asteroids: Array = parsed as Array
	_show_asteroids(asteroids)


func _show_asteroids(asteroids: Array) -> void:
	clear_children(list_box)

	if asteroids.is_empty():
		set_status(status_label, "Sin asteroides", COLOR_WARN)
		set_footer("No se encontraron asteroides activos en Neon.", COLOR_WARN)
		_show_empty_message("No se encontraron asteroides disponibles.")
		return

	for item: Variant in asteroids:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var asteroid: Dictionary = item as Dictionary
		_add_asteroid_card(asteroid)

	set_status(status_label, str(asteroids.size()) + " asteroides detectados", COLOR_OK)
	set_footer("Selecciona un asteroide para iniciar extracción o reclamar recursos.", COLOR_OK)


func _add_asteroid_card(asteroid: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer

	card.custom_minimum_size = Vector2(0, 160)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	row.add_child(details)

	var asteroid_id: String = str(asteroid.get("id", ""))
	var name: String = str(asteroid.get("nombre", "Asteroide"))
	var resource_name: String = str(asteroid.get("recurso", "Recurso desconocido"))
	var richness: String = str(asteroid.get("riqueza", "-"))
	var distance: String = str(asteroid.get("distancia_al", "-"))
	var state: String = str(asteroid.get("estado", "Disponible"))
	var available: int = _to_int(asteroid.get("cantidad_disponible", 0), 0)
	var maximum: int = _to_int(asteroid.get("cantidad_maxima", 0), 0)
	var seconds_left: int = _to_int(asteroid.get("tiempo_restante_segundos", 0), 0)
	var ready_to_claim: bool = bool(asteroid.get("listo_para_reclamar", false))
	var mined_by_user: bool = bool(asteroid.get("minado_por_usuario", false))

	var title_label: Label = make_label(
		_resource_icon(resource_name) + " " + name,
		20,
		COLOR_ACCENT
	)
	details.add_child(title_label)

	var resource_label: Label = make_label(
		"Recurso: " + resource_name + " | Riqueza: " + richness,
		15,
		COLOR_TEXT
	)
	details.add_child(resource_label)

	var amount_label: Label = make_label(
		"Disponible: " + str(available) + " / " + str(maximum) + " unidades | Distancia: " + distance,
		14,
		COLOR_MUTED
	)
	details.add_child(amount_label)

	var state_text: String = "Estado: " + state

	if mined_by_user and seconds_left > 0:
		state_text += " | Restan " + str(seconds_left) + " s"

	var state_label: Label = make_label(
		state_text,
		14,
		_status_color(state, ready_to_claim)
	)
	details.add_child(state_label)

	var action_box: VBoxContainer = VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(190, 0)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(action_box)

	var action_button: Button

	if ready_to_claim:
		action_button = make_button("Reclamar recursos", COLOR_OK)
		action_button.pressed.connect(_claim_resources.bind(asteroid_id))
	elif mined_by_user:
		action_button = make_button("Extracción activa", COLOR_WARN)
		action_button.disabled = true
	elif state.to_lower() == "disponible":
		action_button = make_button("Extraer", COLOR_OK)
		action_button.pressed.connect(_start_mining.bind(asteroid_id))
	else:
		action_button = make_button("No disponible", COLOR_DANGER)
		action_button.disabled = true

	action_button.custom_minimum_size = Vector2(180, 42)
	action_box.add_child(action_button)

	var id_label: Label = make_label(
		asteroid_id,
		11,
		COLOR_MUTED
	)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.add_child(id_label)


func _start_mining(asteroid_id: String) -> void:
	if asteroid_id.strip_edges().is_empty():
		set_footer("Asteroide inválido.", COLOR_DANGER)
		return

	set_status(status_label, "Iniciando extracción...", COLOR_WARN)
	set_footer("Enviando POST /mining/extraer al backend...")

	var path: String = "/mining/extraer?asteroide_id=" + asteroid_id + "&horas=1"
	var error: int = start_request.request(
		api_url(path),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la extracción.", COLOR_DANGER)


func _claim_resources(asteroid_id: String) -> void:
	if asteroid_id.strip_edges().is_empty():
		set_footer("Asteroide inválido.", COLOR_DANGER)
		return

	set_status(status_label, "Reclamando recursos...", COLOR_WARN)
	set_footer("Enviando POST /mining/reclamar al backend...")

	var path: String = "/mining/reclamar?asteroide_id=" + asteroid_id
	var error: int = claim_request.request(
		api_url(path),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible reclamar los recursos.", COLOR_DANGER)


func _on_start_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Extracción rechazada", COLOR_DANGER)
		set_footer(_extract_error_message(text), COLOR_DANGER)
		_scan_asteroids()
		return

	var parsed: Variant = JSON.parse_string(text)
	var message: String = "Extracción iniciada correctamente."

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		message = str(response.get("mensaje", message))

	set_status(status_label, "Extracción activa", COLOR_OK)
	set_footer(message, COLOR_OK)
	_scan_asteroids()


func _on_claim_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Reclamo rechazado", COLOR_DANGER)
		set_footer(_extract_error_message(text), COLOR_DANGER)
		_scan_asteroids()
		return

	var parsed: Variant = JSON.parse_string(text)
	var message: String = "Recursos reclamados y enviados al inventario."

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		message = str(response.get("mensaje", message))

	set_status(status_label, "Inventario actualizado", COLOR_OK)
	set_footer(message + " Revisa Inventario para ver la nueva cantidad.", COLOR_OK)
	_scan_asteroids()


func _show_empty_message(message: String) -> void:
	clear_children(list_box)

	var label: Label = make_label(
		message,
		17,
		COLOR_MUTED
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 100)
	list_box.add_child(label)


func _resource_icon(resource_name: String) -> String:
	var normalized: String = resource_name.to_lower()

	if "kliptium" in normalized:
		return "✦"

	if "litium" in normalized or "litio" in normalized:
		return "◉"

	if "copper" in normalized or "cobre" in normalized:
		return "⬡"

	if "h2o" in normalized or "agua" in normalized:
		return "◌"

	if "org" in normalized:
		return "◒"

	return "▣"


func _status_color(state: String, ready_to_claim: bool) -> Color:
	if ready_to_claim:
		return COLOR_OK

	var normalized: String = state.to_lower()

	if "ocupado" in normalized:
		return COLOR_DANGER

	if "extrayendo" in normalized:
		return COLOR_WARN

	return COLOR_MUTED


func _extract_error_message(response_text: String) -> String:
	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		return str(response.get("detail", response_text))

	if response_text.strip_edges().is_empty():
		return "Error desconocido del backend."

	return response_text


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return int(value)

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var text: String = str(value).strip_edges()

		if text.is_valid_int():
			return text.to_int()

	return fallback
