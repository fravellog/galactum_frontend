extends Control

# Gestión real de solicitudes y miembros de la alianza.
# Esta escena se abre desde vista_detallada.gd únicamente para el líder.

const OP_NONE: String = ""
const OP_LOAD_MY_ALLIANCE: String = "load_my_alliance"
const OP_LOAD_DETAIL: String = "load_detail"
const OP_LOAD_REQUESTS: String = "load_requests"
const OP_ACCEPT_REQUEST: String = "accept_request"
const OP_REJECT_REQUEST: String = "reject_request"
const OP_KICK_MEMBER: String = "kick_member"

const COLOR_OK: Color = Color(0.27, 0.82, 0.52, 1.0)
const COLOR_ERROR: Color = Color(0.96, 0.36, 0.36, 1.0)
const COLOR_WARN: Color = Color(1.0, 0.73, 0.23, 1.0)
const COLOR_TEXT: Color = Color(0.92, 0.95, 1.0, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.73, 0.86, 1.0)

@onready var button_volver: Button = $VBoxContainer/Header/Button_Volver
@onready var label_titulo: Label = $VBoxContainer/Header/Label_Titulo
@onready var label_estado: Label = $VBoxContainer/Label_Estado
@onready var solicitudes_container: VBoxContainer = $VBoxContainer/TabContainer/Solicitudes/ScrollContainer/VBoxContainer
@onready var miembros_container: VBoxContainer = $VBoxContainer/TabContainer/Miembros/ScrollContainer/VBoxContainer
@onready var http_request: HTTPRequest = $HTTPRequest

var active_operation: String = OP_NONE
var alliance_id: int = 0
var alliance_name: String = ""
var alliance_tag: String = ""
var leader_player_id: int = 0


func _ready() -> void:
	button_volver.pressed.connect(_on_button_volver_pressed)
	http_request.request_completed.connect(_on_request_completed)

	label_titulo.text = "Gestión de alianza"
	_set_status("Cargando gestión de alianza...", COLOR_WARN)
	_load_my_alliance()


func _on_button_volver_pressed() -> void:
	queue_free()


func _load_my_alliance() -> void:
	_clear_container(solicitudes_container)
	_clear_container(miembros_container)

	_set_status("Consultando tu alianza...", COLOR_WARN)
	_start_request(
		OP_LOAD_MY_ALLIANCE,
		APIManager.base_url + "/alianzas/mi-alianza",
		HTTPClient.METHOD_GET
	)


func _load_alliance_detail() -> void:
	if alliance_id <= 0:
		_set_status("No se recibió un ID válido de alianza.", COLOR_ERROR)
		return

	_set_status("Cargando miembros de la alianza...", COLOR_WARN)
	_start_request(
		OP_LOAD_DETAIL,
		APIManager.base_url + "/alianzas/" + str(alliance_id),
		HTTPClient.METHOD_GET
	)


func _load_pending_requests() -> void:
	_set_status("Cargando solicitudes pendientes...", COLOR_WARN)
	_start_request(
		OP_LOAD_REQUESTS,
		APIManager.base_url + "/alianzas/mi-alianza/solicitudes",
		HTTPClient.METHOD_GET
	)


func _start_request(operation: String, url: String, method: int, body: String = "") -> void:
	active_operation = operation

	var request_error: int = http_request.request(
		url,
		APIManager.get_auth_headers(),
		method,
		body
	)

	if request_error != OK:
		active_operation = OP_NONE
		_set_status(
			"No fue posible iniciar la conexión con el servidor.",
			COLOR_ERROR
		)


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var response_text: String = body.get_string_from_utf8()
	var finished_operation: String = active_operation
	active_operation = OP_NONE

	if response_code < 200 or response_code >= 300:
		var error_message: String = _read_error_message(response_text)
		_set_status(
			"Error HTTP " + str(response_code) + ": " + error_message,
			COLOR_ERROR
		)
		return

	var parsed: Variant = JSON.parse_string(response_text)

	match finished_operation:
		OP_LOAD_MY_ALLIANCE:
			_handle_my_alliance(parsed)
		OP_LOAD_DETAIL:
			_handle_alliance_detail(parsed)
		OP_LOAD_REQUESTS:
			_handle_pending_requests(parsed)
		OP_ACCEPT_REQUEST:
			_handle_operation_result(parsed, "Solicitud aceptada.")
		OP_REJECT_REQUEST:
			_handle_operation_result(parsed, "Solicitud rechazada.")
		OP_KICK_MEMBER:
			_handle_operation_result(parsed, "Miembro expulsado.")
		_:
			_set_status("La respuesta recibida no corresponde a una operación válida.", COLOR_ERROR)


func _handle_my_alliance(parsed: Variant) -> void:
	if parsed == null:
		_set_status("No perteneces a ninguna alianza.", COLOR_WARN)
		_add_empty_message(
			solicitudes_container,
			"No hay solicitudes porque no perteneces a una alianza."
		)
		_add_empty_message(
			miembros_container,
			"No hay miembros para mostrar."
		)
		return

	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("El servidor devolvió datos inválidos para tu alianza.", COLOR_ERROR)
		return

	var alliance: Dictionary = parsed as Dictionary
	alliance_id = _to_int(alliance.get("id", 0), 0)
	alliance_name = str(alliance.get("nombre", alliance.get("name", "Mi alianza")))
	alliance_tag = str(alliance.get("tag", ""))
	leader_player_id = _to_int(alliance.get("lider_jugador_id", 0), 0)

	if alliance_id <= 0:
		_set_status("Tu alianza no contiene un ID válido.", COLOR_ERROR)
		return

	label_titulo.text = "Gestión: " + alliance_name + _format_tag(alliance_tag)
	_load_alliance_detail()


func _handle_alliance_detail(parsed: Variant) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("El detalle de alianza no tiene un formato válido.", COLOR_ERROR)
		return

	var detail: Dictionary = parsed as Dictionary
	alliance_id = _to_int(detail.get("id", alliance_id), alliance_id)
	alliance_name = str(detail.get("nombre", alliance_name))
	alliance_tag = str(detail.get("tag", alliance_tag))
	leader_player_id = _to_int(detail.get("lider_jugador_id", leader_player_id), leader_player_id)

	label_titulo.text = "Gestión: " + alliance_name + _format_tag(alliance_tag)

	var raw_members: Variant = detail.get("miembros", [])
	var members: Array = []
	if typeof(raw_members) == TYPE_ARRAY:
		members = raw_members as Array

	_show_members(members)
	_load_pending_requests()


func _handle_pending_requests(parsed: Variant) -> void:
	if typeof(parsed) != TYPE_ARRAY:
		_set_status("La lista de solicitudes tiene un formato inválido.", COLOR_ERROR)
		return

	var requests: Array = parsed as Array
	_show_pending_requests(requests)

	var members_count: int = miembros_container.get_child_count()
	_set_status(
		str(requests.size())
		+ " solicitud(es) pendiente(s) · "
		+ str(members_count)
		+ " miembro(s) en la lista.",
		COLOR_OK
	)


func _show_pending_requests(requests: Array) -> void:
	_clear_container(solicitudes_container)

	if requests.is_empty():
		_add_empty_message(
			solicitudes_container,
			"No tienes solicitudes pendientes de ingreso."
		)
		return

	for raw_request: Variant in requests:
		if typeof(raw_request) != TYPE_DICTIONARY:
			continue

		var request_data: Dictionary = raw_request as Dictionary
		_add_request_card(request_data)


func _show_members(members: Array) -> void:
	_clear_container(miembros_container)

	if members.is_empty():
		_add_empty_message(miembros_container, "La alianza aún no tiene miembros registrados.")
		return

	for raw_member: Variant in members:
		if typeof(raw_member) != TYPE_DICTIONARY:
			continue

		var member_data: Dictionary = raw_member as Dictionary
		_add_member_card(member_data)


func _add_request_card(request_data: Dictionary) -> void:
	var raw_applicant: Variant = request_data.get("solicitante", {})
	var applicant: Dictionary = {}
	if typeof(raw_applicant) == TYPE_DICTIONARY:
		applicant = raw_applicant as Dictionary

	var request_id: int = _to_int(request_data.get("id", 0), 0)
	var applicant_name: String = str(applicant.get("nombre", "Jugador sin nombre"))
	var applicant_power: int = _to_int(applicant.get("poder", 0), 0)
	var request_message: String = str(request_data.get("mensaje", "")).strip_edges()
	var created_at: String = _format_date(str(request_data.get("creada_en", "")))

	var card: PanelContainer = _make_card_panel()
	var margin: MarginContainer = _make_card_margin()
	var row: HBoxContainer = HBoxContainer.new()
	var details: VBoxContainer = VBoxContainer.new()
	var buttons: HBoxContainer = HBoxContainer.new()

	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_END

	var name_label: Label = _make_label("📩 " + applicant_name, 18, COLOR_TEXT)
	var power_label: Label = _make_label("⚡ Poder: " + str(applicant_power), 14, COLOR_MUTED)
	var message_label: Label = _make_label(
		"Mensaje: " + (request_message if not request_message.is_empty() else "Sin mensaje."),
		14,
		COLOR_MUTED
	)
	var date_label: Label = _make_label("Enviada: " + created_at, 12, COLOR_MUTED)

	var accept_button: Button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.tooltip_text = "Aceptar la solicitud de " + applicant_name
	accept_button.pressed.connect(_accept_request.bind(request_id))

	var reject_button: Button = Button.new()
	reject_button.text = "Rechazar"
	reject_button.tooltip_text = "Rechazar la solicitud de " + applicant_name
	reject_button.pressed.connect(_reject_request.bind(request_id))

	if request_id <= 0:
		accept_button.disabled = true
		reject_button.disabled = true

	details.add_child(name_label)
	details.add_child(power_label)
	details.add_child(message_label)
	details.add_child(date_label)
	buttons.add_child(accept_button)
	buttons.add_child(reject_button)
	row.add_child(details)
	row.add_child(buttons)
	margin.add_child(row)
	card.add_child(margin)
	solicitudes_container.add_child(card)


func _add_member_card(member_data: Dictionary) -> void:
	var player_id: int = _to_int(member_data.get("jugador_id", 0), 0)
	var player_name: String = str(member_data.get("nombre", "Jugador sin nombre"))
	var player_power: int = _to_int(member_data.get("poder", 0), 0)
	var is_leader: bool = bool(member_data.get("es_lider", false))

	var card: PanelContainer = _make_card_panel()
	var margin: MarginContainer = _make_card_margin()
	var row: HBoxContainer = HBoxContainer.new()
	var details: VBoxContainer = VBoxContainer.new()

	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)

	var role_text: String = "Líder" if is_leader else "Miembro"
	var role_icon: String = "👑" if is_leader else "👤"
	var name_label: Label = _make_label(role_icon + " " + player_name, 18, COLOR_TEXT)
	var detail_label: Label = _make_label(
		role_text + "  ·  ⚡ Poder: " + str(player_power),
		14,
		COLOR_MUTED
	)

	details.add_child(name_label)
	details.add_child(detail_label)
	row.add_child(details)

	if not is_leader:
		var kick_button: Button = Button.new()
		kick_button.text = "Expulsar"
		kick_button.tooltip_text = "Expulsar a " + player_name + " de la alianza"
		kick_button.pressed.connect(_kick_member.bind(player_id, player_name))

		if player_id <= 0:
			kick_button.disabled = true

		row.add_child(kick_button)

	margin.add_child(row)
	card.add_child(margin)
	miembros_container.add_child(card)


func _accept_request(request_id: int) -> void:
	if request_id <= 0:
		_set_status("La solicitud seleccionada no tiene un ID válido.", COLOR_ERROR)
		return

	_set_status("Aceptando solicitud...", COLOR_WARN)
	_start_request(
		OP_ACCEPT_REQUEST,
		APIManager.base_url + "/alianzas/solicitudes/" + str(request_id) + "/aceptar",
		HTTPClient.METHOD_POST
	)


func _reject_request(request_id: int) -> void:
	if request_id <= 0:
		_set_status("La solicitud seleccionada no tiene un ID válido.", COLOR_ERROR)
		return

	_set_status("Rechazando solicitud...", COLOR_WARN)
	_start_request(
		OP_REJECT_REQUEST,
		APIManager.base_url + "/alianzas/solicitudes/" + str(request_id) + "/rechazar",
		HTTPClient.METHOD_POST
	)


func _kick_member(player_id: int, player_name: String) -> void:
	if player_id <= 0:
		_set_status("El miembro seleccionado no tiene un ID válido.", COLOR_ERROR)
		return

	_set_status("Expulsando a " + player_name + "...", COLOR_WARN)
	_start_request(
		OP_KICK_MEMBER,
		APIManager.base_url + "/alianzas/mi-alianza/miembros/" + str(player_id),
		HTTPClient.METHOD_DELETE
	)


func _handle_operation_result(parsed: Variant, fallback_message: String) -> void:
	var message: String = fallback_message

	if typeof(parsed) == TYPE_DICTIONARY:
		var result: Dictionary = parsed as Dictionary
		message = str(result.get("mensaje", result.get("message", fallback_message)))

	_set_status(message, COLOR_OK)
	_load_my_alliance()


func _read_error_message(response_text: String) -> String:
	var parsed_error: Variant = JSON.parse_string(response_text)

	if typeof(parsed_error) == TYPE_DICTIONARY:
		var error_data: Dictionary = parsed_error as Dictionary
		var detail: Variant = error_data.get("detail", error_data.get("mensaje", ""))
		var detail_text: String = str(detail).strip_edges()
		if not detail_text.is_empty():
			return detail_text

	var trimmed_text: String = response_text.strip_edges()
	if not trimmed_text.is_empty():
		return trimmed_text

	return "El servidor no entregó un detalle del error."


func _set_status(message: String, color: Color) -> void:
	label_estado.text = message
	label_estado.modulate = color


func _clear_container(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _add_empty_message(container: VBoxContainer, message: String) -> void:
	var empty_label: Label = _make_label(message, 16, COLOR_MUTED)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.custom_minimum_size = Vector2(0.0, 52.0)
	container.add_child(empty_label)


func _make_card_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 102.0)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.23, 0.98)
	style.border_color = Color(0.20, 0.39, 0.72, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	return panel


func _make_card_margin() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	return margin


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = color
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _format_tag(tag: String) -> String:
	var clean_tag: String = tag.strip_edges()
	if clean_tag.is_empty():
		return ""
	return " [" + clean_tag + "]"


func _format_date(raw_date: String) -> String:
	var clean_date: String = raw_date.strip_edges()
	if clean_date.is_empty():
		return "Fecha no disponible"

	var visible_date: String = clean_date.replace("T", " ")
	if visible_date.length() > 16:
		return visible_date.left(16)
	return visible_date


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return value as int

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var value_text: String = str(value).strip_edges()
		if value_text.is_valid_int():
			return value_text.to_int()

	return fallback
