extends Control

@onready var btn_volver = $VBoxContainer/Header/Button_Volver
@onready var label_titulo = $VBoxContainer/Header/Label_Titulo
@onready var label_estado = $VBoxContainer/Label_Estado
@onready var contenedor_solicitudes = $VBoxContainer/TabContainer/Solicitudes/ScrollContainer/VBoxContainer
@onready var contenedor_miembros = $VBoxContainer/TabContainer/Miembros/ScrollContainer/VBoxContainer
@onready var http_request = $HTTPRequest

var alliance_id: int = 0
var solicitud_actual := ""


func _ready():
	btn_volver.pressed.connect(queue_free)
	http_request.request_completed.connect(_on_request_completed)
	_cargar_mi_alianza()


func _cargar_mi_alianza():
	solicitud_actual = "mi_alianza"
	label_estado.text = "Cargando gestión de alianza..."
	_enviar_get(APIManager.base_url + "/alianzas/mi-alianza")


func _cargar_detalle():
	solicitud_actual = "detalle"
	_enviar_get(APIManager.base_url + "/alianzas/" + str(alliance_id))


func _cargar_solicitudes():
	solicitud_actual = "solicitudes"
	_enviar_get(APIManager.base_url + "/alianzas/mi-alianza/solicitudes")


func _enviar_get(url: String):
	var error = http_request.request(url, APIManager.get_auth_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		label_estado.text = "No fue posible iniciar la conexión."


func _on_request_completed(_result, response_code, _headers, body):
	var response_text = body.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		_mostrar_error_http(response_code, response_text)
		return

	if solicitud_actual == "mi_alianza":
		var alliance = JSON.parse_string(response_text)
		if typeof(alliance) != TYPE_DICTIONARY:
			label_estado.text = "No perteneces a una alianza o la respuesta no es válida."
			return
		alliance_id = int(alliance.get("id", 0))
		label_titulo.text = "Gestión: " + str(alliance.get("nombre", "Mi alianza"))
		_cargar_detalle()
		return

	if solicitud_actual == "detalle":
		var detail = JSON.parse_string(response_text)
		if typeof(detail) == TYPE_DICTIONARY:
			_cargar_miembros(detail.get("miembros", []))
			_cargar_solicitudes()
		else:
			label_estado.text = "El detalle de la alianza no es válido."
		return

	if solicitud_actual == "solicitudes":
		var requests = JSON.parse_string(response_text)
		if typeof(requests) == TYPE_ARRAY:
			_cargar_solicitudes_en_pantalla(requests)
		else:
			label_estado.text = "La lista de solicitudes no es válida."
		return

	if solicitud_actual == "accion":
		var action = JSON.parse_string(response_text)
		label_estado.text = str(action.get("mensaje", "Operación realizada.")) if typeof(action) == TYPE_DICTIONARY else "Operación realizada."
		_cargar_mi_alianza()


func _cargar_solicitudes_en_pantalla(solicitudes: Array):
	for child in contenedor_solicitudes.get_children():
		child.queue_free()

	if solicitudes.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No hay solicitudes pendientes."
		contenedor_solicitudes.add_child(empty_label)
		label_estado.text = "Gestión actualizada."
		return

	for solicitud in solicitudes:
		if typeof(solicitud) != TYPE_DICTIONARY:
			continue

		var applicant = solicitud.get("solicitante", {})
		var request_id = int(solicitud.get("id", 0))

		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 8)
		var box = VBoxContainer.new()

		var label = Label.new()
		label.text = "👤 " + str(applicant.get("nombre", "Jugador")) + " | ⚡ Poder: " + str(applicant.get("poder", 0))
		box.add_child(label)

		var message = Label.new()
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.text = "Mensaje: " + str(solicitud.get("mensaje", "Sin mensaje"))
		box.add_child(message)

		var actions = HBoxContainer.new()
		var btn_accept = Button.new()
		btn_accept.text = "Aceptar"
		btn_accept.pressed.connect(_on_btn_aceptar_pressed.bind(request_id))
		var btn_reject = Button.new()
		btn_reject.text = "Rechazar"
		btn_reject.pressed.connect(_on_btn_rechazar_pressed.bind(request_id))
		actions.add_child(btn_accept)
		actions.add_child(btn_reject)
		box.add_child(actions)

		margin.add_child(box)
		card.add_child(margin)
		contenedor_solicitudes.add_child(card)

	label_estado.text = str(solicitudes.size()) + " solicitud(es) pendiente(s)."


func _cargar_miembros(miembros: Array):
	for child in contenedor_miembros.get_children():
		child.queue_free()

	for miembro in miembros:
		if typeof(miembro) != TYPE_DICTIONARY:
			continue

		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 8)
		var row = HBoxContainer.new()

		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var es_lider = bool(miembro.get("es_lider", false))
		var rango = "Líder" if es_lider else "Miembro"
		label.text = "👤 " + str(miembro.get("nombre", "Jugador")) + " | " + rango + " | ⚡ " + str(miembro.get("poder", 0))
		row.add_child(label)

		if not es_lider:
			var btn_kick = Button.new()
			btn_kick.text = "Expulsar"
			btn_kick.pressed.connect(_on_btn_expulsar_pressed.bind(int(miembro.get("jugador_id", 0))))
			row.add_child(btn_kick)

		margin.add_child(row)
		card.add_child(margin)
		contenedor_miembros.add_child(card)


func _on_btn_aceptar_pressed(request_id: int):
	_ejecutar_accion(APIManager.base_url + "/alianzas/solicitudes/" + str(request_id) + "/aceptar", HTTPClient.METHOD_POST)


func _on_btn_rechazar_pressed(request_id: int):
	_ejecutar_accion(APIManager.base_url + "/alianzas/solicitudes/" + str(request_id) + "/rechazar", HTTPClient.METHOD_POST)


func _on_btn_expulsar_pressed(jugador_id: int):
	_ejecutar_accion(APIManager.base_url + "/alianzas/mi-alianza/miembros/" + str(jugador_id), HTTPClient.METHOD_DELETE)


func _ejecutar_accion(url: String, method: HTTPClient.Method):
	solicitud_actual = "accion"
	label_estado.text = "Procesando acción..."
	var error = http_request.request(url, APIManager.get_auth_headers(), method)
	if error != OK:
		label_estado.text = "No fue posible iniciar la acción."


func _mostrar_error_http(response_code: int, response_text: String):
	var response = JSON.parse_string(response_text)
	if typeof(response) == TYPE_DICTIONARY and response.has("detail"):
		label_estado.text = str(response["detail"])
	else:
		label_estado.text = "Error HTTP: " + str(response_code)
