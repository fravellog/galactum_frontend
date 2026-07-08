extends "res://galactum_screen_base.gd"

var list_request: HTTPRequest
var action_request: HTTPRequest

var status_label: Label
var list_box: VBoxContainer
var last_result_label: Label
var refresh_button: Button


func _ready() -> void:
	var shell: Dictionary = build_shell(
		"CONFLICTOS",
		"COMBATE PERSISTENTE CONTRA FACCIONES NPC"
	)

	status_label = shell["status"] as Label

	_build_info_panel()
	_build_conflict_list()
	_build_requests()

	finish_shell()
	_load_conflicts()


func _build_info_panel() -> void:
	var info_bundle: Dictionary = make_margin_panel()
	var info_panel: PanelContainer = info_bundle["panel"] as PanelContainer
	var info_margin: MarginContainer = info_bundle["margin"] as MarginContainer

	content_box.add_child(info_panel)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 8)
	info_margin.add_child(info_box)

	var description: Label = make_label(
		"Selecciona un conflicto activo y resuelve un combate simple desde FastAPI. "
		+ "Si ganas, el backend suma recursos al inventario real. "
		+ "Si pierdes, la nave recibe daño en Neon.",
		15,
		COLOR_MUTED
	)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_child(description)

	last_result_label = make_label(
		"Resultado: sin combate reciente.",
		15,
		COLOR_TEXT
	)
	last_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_child(last_result_label)


func _build_conflict_list() -> void:
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.custom_minimum_size.y = 38
	content_box.add_child(header_row)

	var section_title: Label = make_section_title("CONFLICTOS ACTIVOS")
	section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(section_title)

	refresh_button = make_button("Actualizar conflictos", COLOR_PANEL_ALT)
	refresh_button.custom_minimum_size = Vector2(180, 36)
	refresh_button.pressed.connect(_load_conflicts)
	header_row.add_child(refresh_button)

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


func _build_requests() -> void:
	list_request = HTTPRequest.new()
	action_request = HTTPRequest.new()

	add_child(list_request)
	add_child(action_request)

	list_request.request_completed.connect(_on_list_completed)
	action_request.request_completed.connect(_on_attack_completed)


func _load_conflicts() -> void:
	set_status(status_label, "Cargando conflictos...", COLOR_WARN)
	set_footer("Consultando conflictos persistentes en FastAPI...")
	refresh_button.disabled = true

	var error: int = list_request.request(
		api_url("/conflicto/activos"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		refresh_button.disabled = false
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la consulta.", COLOR_DANGER)


func _on_list_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	refresh_button.disabled = false

	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer(_extract_error_detail(text), COLOR_DANGER)
		return

	var parsed: Variant = JSON.parse_string(text)
	var conflicts: Array = _extract_conflicts(parsed)

	clear_children(list_box)

	if conflicts.is_empty():
		_add_empty_message()
		set_status(status_label, "Sin conflictos", COLOR_WARN)
		set_footer("No hay conflictos activos para mostrar.", COLOR_WARN)
		return

	for item: Variant in conflicts:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var conflict: Dictionary = item as Dictionary
		_add_conflict_card(conflict)

	set_status(status_label, str(conflicts.size()) + " conflictos activos", COLOR_OK)
	set_footer("Selecciona una operación para atacar.", COLOR_OK)


func _extract_conflicts(parsed: Variant) -> Array:
	if typeof(parsed) == TYPE_ARRAY:
		return parsed as Array

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		var data: Variant = response.get("conflictos", response.get("data", []))

		if typeof(data) == TYPE_ARRAY:
			return data as Array

	return []


func _add_conflict_card(conflict: Dictionary) -> void:
	var bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = bundle["panel"] as PanelContainer
	var margin: MarginContainer = bundle["margin"] as MarginContainer

	card.custom_minimum_size = Vector2(0, 176)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	var details: VBoxContainer = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	row.add_child(details)

	var conflict_id: int = _to_int(conflict.get("id", 0), 0)
	var enemy: String = _get_enemy_name(conflict)
	var sector: String = str(conflict.get("sector", "Sector desconocido"))
	var state: String = str(conflict.get("estado", "Activo"))
	var danger: String = str(conflict.get("peligro", "No definido"))
	var player_power: int = _to_int(conflict.get("poder_jugador", 0), 0)
	var enemy_power: int = _to_int(conflict.get("poder_enemigo", 0), 0)
	var result_estimate: String = str(conflict.get("resultado_estimado", "Sin estimación"))
	var energy_cost: int = _to_int(conflict.get("energia_requerida", 0), 0)
	var reward_text: String = _format_reward(conflict)

	details.add_child(make_label(enemy, 20, COLOR_ACCENT))
	details.add_child(make_label("Sector: " + sector, 15, COLOR_MUTED))
	details.add_child(
		make_label(
			"Estado: "
			+ state
			+ " | Peligro: "
			+ danger,
			15,
			COLOR_TEXT
		)
	)
	details.add_child(
		make_label(
			"Poder jugador: "
			+ _format_number(player_power)
			+ " | Poder enemigo: "
			+ _format_number(enemy_power),
			14,
			COLOR_MUTED
		)
	)
	details.add_child(
		make_label(
			"Estimación: "
			+ result_estimate
			+ " | Energía requerida: "
			+ str(energy_cost),
			14,
			COLOR_MUTED
		)
	)
	details.add_child(make_label("Recompensa: " + reward_text, 14, COLOR_OK))

	var action_box: VBoxContainer = VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(170, 0)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(action_box)

	var button: Button = make_button("Atacar", COLOR_DANGER)
	button.custom_minimum_size = Vector2(160, 44)
	button.pressed.connect(_attack.bind(conflict_id))
	action_box.add_child(button)


func _add_empty_message() -> void:
	var label: Label = make_label(
		"No hay conflictos activos disponibles.",
		17,
		COLOR_MUTED
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 90)
	list_box.add_child(label)


func _attack(conflict_id: int) -> void:
	if conflict_id <= 0:
		set_footer("Conflicto inválido.", COLOR_DANGER)
		return

	set_status(status_label, "Resolviendo combate...", COLOR_WARN)
	set_footer("Enviando ataque al backend...")
	last_result_label.text = "Resultado: combate en proceso..."

	var path: String = (
		"/conflicto/atacar?conflicto_id="
		+ str(conflict_id)
		+ "&naves_enviadas=1"
	)

	var error: int = action_request.request(
		api_url(path),
		auth_headers(),
		HTTPClient.METHOD_POST,
		""
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible enviar la orden de ataque.", COLOR_DANGER)
		last_result_label.text = "Resultado: error al iniciar el ataque."


func _on_attack_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Ataque rechazado", COLOR_DANGER)
		set_footer(_extract_error_detail(text), COLOR_DANGER)
		last_result_label.text = "Resultado: ataque rechazado por el backend."
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend resolvió el ataque, pero no devolvió un JSON válido.", COLOR_DANGER)
		return

	var response: Dictionary = parsed as Dictionary
	var details: Dictionary = _extract_details(response)
	var status_text: String = str(response.get("status", "resultado"))
	var message: String = str(response.get("mensaje", "Combate resuelto."))

	var is_victory: bool = status_text.to_lower() == "victoria"
	var color: Color = COLOR_OK if is_victory else COLOR_DANGER

	set_status(status_label, "Combate resuelto", color)
	set_footer(message, color)

	last_result_label.text = _format_battle_result(details, message)

	_load_conflicts()


func _extract_details(response: Dictionary) -> Dictionary:
	var raw_details: Variant = response.get("detalles", {})

	if typeof(raw_details) == TYPE_DICTIONARY:
		return raw_details as Dictionary

	return {}


func _format_battle_result(details: Dictionary, fallback: String) -> String:
	if details.is_empty():
		return "Resultado: " + fallback

	var result: String = str(details.get("resultado", "sin resultado"))
	var player_power: int = _to_int(details.get("poder_jugador", 0), 0)
	var enemy_power: int = _to_int(details.get("poder_enemigo", 0), 0)
	var hull_damage: int = _to_int(details.get("daño_casco", 0), 0)
	var hull_left: int = _to_int(details.get("casco_restante", 0), 0)
	var energy_left: int = _to_int(details.get("energia_restante", 0), 0)
	var reward: String = _format_reward(details)

	return (
		"Resultado: "
		+ result.to_upper()
		+ " | Poder "
		+ _format_number(player_power)
		+ " vs "
		+ _format_number(enemy_power)
		+ " | Daño casco: "
		+ str(hull_damage)
		+ " | Casco restante: "
		+ str(hull_left)
		+ " | Energía restante: "
		+ str(energy_left)
		+ " | Recompensa: "
		+ reward
	)


func _format_reward(source: Dictionary) -> String:
	var raw_reward: Variant = source.get("recompensa", {})

	if typeof(raw_reward) != TYPE_DICTIONARY:
		return "Sin recompensa"

	var reward: Dictionary = raw_reward as Dictionary
	var quantity: int = _to_int(reward.get("cantidad", 0), 0)
	var resource_name: String = str(reward.get("recurso", "recurso"))
	var unit: String = str(reward.get("unidad", "unidades"))

	if quantity <= 0:
		return "Sin recompensa"

	return "+" + str(quantity) + " " + resource_name + " " + unit


func _get_enemy_name(conflict: Dictionary) -> String:
	return str(
		conflict.get(
			"facción_enemiga",
			conflict.get("faccion_enemiga", "Facción desconocida")
		)
	)


func _extract_error_detail(response_text: String) -> String:
	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary
		return str(response.get("detail", response_text))

	if response_text.strip_edges().is_empty():
		return "Error desconocido."

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


func _format_number(number: int) -> String:
	var text: String = str(number)
	var result: String = ""
	var count: int = 0

	for index: int in range(text.length() - 1, -1, -1):
		result = text[index] + result
		count += 1

		if count % 3 == 0 and index > 0:
			result = "." + result

	return result
