extends "res://galactum_screen_base.gd"

var request_available: HTTPRequest
var request_active: HTTPRequest
var request_accept: HTTPRequest
var request_claim: HTTPRequest

var status_label: Label
var available_box: VBoxContainer
var active_box: VBoxContainer
var refresh_button: Button


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"MISIONES",
		"OBJETIVOS PERSISTENTES CON INVENTARIO REAL"
	)

	status_label = shell["status"] as Label

	_build_intro_panel()
	_build_refresh_bar()
	_build_mission_sections()
	_build_requests()

	finish_shell()
	_load_all_missions()


func _build_intro_panel() -> void:
	var bundle: Dictionary = make_margin_panel()
	var panel: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer

	content_box.add_child(panel)

	var text: Label = make_label(
		"Acepta misiones y completa objetivos usando recursos reales del inventario. "
		+ "Cuando la meta se cumpla, podrás reclamar recompensas que se guardan en Neon.",
		16,
		COLOR_MUTED
	)

	margin.add_child(text)


func _build_refresh_bar() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content_box.add_child(row)

	var info: Label = make_label(
		"Flujo: aceptar misión → minar recursos → volver a misiones → reclamar recompensa",
		15,
		COLOR_TEXT
	)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	refresh_button = make_button("Actualizar misiones", COLOR_PANEL_ALT)
	refresh_button.custom_minimum_size = Vector2(170, 38)
	refresh_button.pressed.connect(_load_all_missions)
	row.add_child(refresh_button)


func _build_mission_sections() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var wrapper: VBoxContainer = VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 18)
	scroll.add_child(wrapper)

	wrapper.add_child(make_section_title("MISIONES ACTIVAS / COMPLETADAS"))

	active_box = VBoxContainer.new()
	active_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_box.add_theme_constant_override("separation", 12)
	wrapper.add_child(active_box)

	wrapper.add_child(make_section_title("TABLERO DE MISIONES DISPONIBLES"))

	available_box = VBoxContainer.new()
	available_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	available_box.add_theme_constant_override("separation", 12)
	wrapper.add_child(available_box)


func _build_requests() -> void:
	request_available = HTTPRequest.new()
	request_active = HTTPRequest.new()
	request_accept = HTTPRequest.new()
	request_claim = HTTPRequest.new()

	add_child(request_available)
	add_child(request_active)
	add_child(request_accept)
	add_child(request_claim)

	request_available.request_completed.connect(_on_available_completed)
	request_active.request_completed.connect(_on_active_completed)
	request_accept.request_completed.connect(_on_accept_completed)
	request_claim.request_completed.connect(_on_claim_completed)


func _load_all_missions() -> void:
	set_status(status_label, "Sincronizando misiones...", COLOR_WARN)
	set_footer("Consultando misiones persistentes en FastAPI / Neon...")
	refresh_button.disabled = true

	_show_loading(active_box, "Cargando misiones aceptadas...")
	_show_loading(available_box, "Cargando tablero de misiones...")

	var error_active: int = request_active.request(
		api_url("/misiones/activas"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error_active != OK:
		_show_error(active_box, "No fue posible consultar misiones activas.")

	var error_available: int = request_available.request(
		api_url("/misiones/disponibles"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error_available != OK:
		_show_error(available_box, "No fue posible consultar misiones disponibles.")


func _on_active_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		_show_error(active_box, "Error HTTP " + str(response_code) + ": " + _extract_detail(text))
		set_status(status_label, "Error en misiones activas", COLOR_DANGER)
		refresh_button.disabled = false
		return

	var parsed: Variant = JSON.parse_string(text)
	var missions: Array = _extract_missions(parsed)

	_show_active_missions(missions)
	refresh_button.disabled = false


func _on_available_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		_show_error(available_box, "Error HTTP " + str(response_code) + ": " + _extract_detail(text))
		set_status(status_label, "Error en tablero", COLOR_DANGER)
		refresh_button.disabled = false
		return

	var parsed: Variant = JSON.parse_string(text)
	var missions: Array = _extract_missions(parsed)

	_show_available_missions(missions)
	set_status(status_label, "Misiones sincronizadas", COLOR_OK)
	set_footer("Acepta misiones, mina recursos y vuelve para reclamar recompensas.", COLOR_OK)
	refresh_button.disabled = false


func _show_active_missions(missions: Array) -> void:
	clear_children(active_box)

	if missions.is_empty():
		active_box.add_child(
			_make_message_label("Aún no tienes misiones aceptadas.")
		)
		return

	for item: Variant in missions:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var mission: Dictionary = item as Dictionary
		_add_mission_card(mission, active_box, true)


func _show_available_missions(missions: Array) -> void:
	clear_children(available_box)

	if missions.is_empty():
		available_box.add_child(
			_make_message_label("No hay misiones disponibles actualmente.")
		)
		return

	for item: Variant in missions:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var mission: Dictionary = item as Dictionary
		_add_mission_card(mission, available_box, false)


func _add_mission_card(mission: Dictionary, parent_box: VBoxContainer, active_section: bool) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer

	card.custom_minimum_size = Vector2(0, 170)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_box.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 7)
	row.add_child(details)

	var mission_id: String = str(mission.get("mision_id", mission.get("id", "")))
	var title: String = str(mission.get("titulo", "Misión sin título"))
	var description: String = str(mission.get("descripcion", "Sin descripción"))
	var difficulty: String = str(mission.get("dificultad", "No definida"))
	var objective_resource: String = str(mission.get("objetivo_recurso", "Recurso"))
	var required: int = _to_int(mission.get("cantidad_requerida", 1), 1)
	var progress: int = _to_int(mission.get("progreso_actual", 0), 0)
	var state: String = str(mission.get("estado_jugador", "disponible"))
	var reward_text: String = str(mission.get("recompensa_texto", "Sin recompensa definida"))

	details.add_child(make_label(_state_icon(state) + " " + title, 20, _state_color(state)))
	details.add_child(make_label(description, 14, COLOR_MUTED))
	details.add_child(
		make_label(
			"Objetivo: "
			+ str(progress)
			+ " / "
			+ str(required)
			+ " "
			+ objective_resource,
			15,
			COLOR_TEXT
		)
	)

	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.max_value = max(1, required)
	progress_bar.value = clampi(progress, 0, required)
	progress_bar.custom_minimum_size = Vector2(0, 18)
	details.add_child(progress_bar)

	details.add_child(
		make_label(
			"Dificultad: "
			+ difficulty
			+ " | Recompensa: "
			+ reward_text,
			14,
			COLOR_ACCENT
		)
	)

	var action_box: VBoxContainer = VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(190, 0)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	action_box.add_theme_constant_override("separation", 8)
	row.add_child(action_box)

	var state_label: Label = make_label(_state_text(state), 14, _state_color(state))
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_box.add_child(state_label)

	var button: Button = _make_action_button(mission_id, state, active_section)
	action_box.add_child(button)


func _make_action_button(mission_id: String, state: String, active_section: bool) -> Button:
	var button: Button = make_button("Aceptar", COLOR_OK)
	button.custom_minimum_size = Vector2(170, 42)

	if state == "disponible":
		button.text = "Aceptar misión"
		button.disabled = false
		button.pressed.connect(_accept_mission.bind(mission_id))
		return button

	if state == "completada":
		button.text = "Reclamar recompensa"
		button.disabled = false
		button.pressed.connect(_claim_mission.bind(mission_id))
		return button

	if state == "activa":
		button.text = "En progreso"
		button.disabled = true
		return button

	if state == "reclamada":
		button.text = "Reclamada"
		button.disabled = true
		return button

	if active_section:
		button.text = "Sin acción"
	else:
		button.text = "No disponible"

	button.disabled = true
	return button


func _accept_mission(mission_id: String) -> void:
	if mission_id.strip_edges().is_empty():
		set_footer("La misión seleccionada no tiene ID válido.", COLOR_DANGER)
		return

	set_status(status_label, "Aceptando misión...", COLOR_WARN)
	set_footer("Guardando misión en Neon...")

	var error: int = request_accept.request(
		api_url("/misiones/" + mission_id + "/aceptar"),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible enviar la aceptación.", COLOR_DANGER)


func _claim_mission(mission_id: String) -> void:
	if mission_id.strip_edges().is_empty():
		set_footer("La misión seleccionada no tiene ID válido.", COLOR_DANGER)
		return

	set_status(status_label, "Reclamando recompensa...", COLOR_WARN)
	set_footer("Actualizando inventario real en Neon...")

	var error: int = request_claim.request(
		api_url("/misiones/" + mission_id + "/reclamar"),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible reclamar la recompensa.", COLOR_DANGER)


func _on_accept_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "No aceptada", COLOR_DANGER)
		set_footer("Error HTTP " + str(response_code) + ": " + _extract_detail(text), COLOR_DANGER)
		return

	set_status(status_label, "Misión aceptada", COLOR_OK)
	set_footer(_extract_message(text, "Misión aceptada correctamente."), COLOR_OK)
	_load_all_missions()


func _on_claim_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "No reclamada", COLOR_DANGER)
		set_footer("Error HTTP " + str(response_code) + ": " + _extract_detail(text), COLOR_DANGER)
		return

	set_status(status_label, "Recompensa reclamada", COLOR_OK)
	set_footer(_extract_message(text, "Recompensa reclamada correctamente."), COLOR_OK)
	_load_all_missions()


func _extract_missions(parsed: Variant) -> Array:
	if typeof(parsed) == TYPE_ARRAY:
		return parsed as Array

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		var candidate: Variant = response.get("misiones", response.get("data", []))

		if typeof(candidate) == TYPE_ARRAY:
			return candidate as Array

	return []


func _show_loading(target: VBoxContainer, message: String) -> void:
	clear_children(target)
	target.add_child(_make_message_label(message))


func _show_error(target: VBoxContainer, message: String) -> void:
	clear_children(target)
	var label: Label = _make_message_label(message)
	label.add_theme_color_override("font_color", COLOR_DANGER)
	target.add_child(label)


func _make_message_label(text_value: String) -> Label:
	var label: Label = make_label(text_value, 16, COLOR_MUTED)
	label.custom_minimum_size = Vector2(0, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _extract_detail(response_text: String) -> String:
	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		return str(response.get("detail", response_text))

	if response_text.strip_edges().is_empty():
		return "Error desconocido."

	return response_text


func _extract_message(response_text: String, fallback: String) -> String:
	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		return str(response.get("mensaje", response.get("message", fallback)))

	return fallback


func _state_icon(state: String) -> String:
	if state == "disponible":
		return "◇"

	if state == "activa":
		return "▣"

	if state == "completada":
		return "✓"

	if state == "reclamada":
		return "★"

	return "•"


func _state_text(state: String) -> String:
	if state == "disponible":
		return "Disponible"

	if state == "activa":
		return "En progreso"

	if state == "completada":
		return "Lista para reclamar"

	if state == "reclamada":
		return "Reclamada"

	return state.capitalize()


func _state_color(state: String) -> Color:
	if state == "disponible":
		return COLOR_ACCENT

	if state == "activa":
		return COLOR_WARN

	if state == "completada":
		return COLOR_OK

	if state == "reclamada":
		return COLOR_MUTED

	return COLOR_TEXT


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return int(value)

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var value_text: String = str(value).strip_edges()

		if value_text.is_valid_int():
			return value_text.to_int()

	return fallback
