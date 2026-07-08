extends Control


var GestionAlianzaEscena = preload("res://gestion_alianza.tscn")

@onready var btn_volver: Button = $VBoxContainer/MarginContainer/HBoxContainer/Button2
@onready var label_titulo: Label = $VBoxContainer/MarginContainer/HBoxContainer/Label
@onready var btn_solicitar: Button = $VBoxContainer/MarginContainer/HBoxContainer/Button
@onready var label_info: Label = $VBoxContainer/TabContainer/Info/Label
@onready var contenedor_miembros: VBoxContainer = $VBoxContainer/TabContainer/Miembros/VBoxContainer/ScrollContainer/VBoxContainer

var id_actual: int = 0
var nombre_actual: String = ""
var requisito_actual: int = 0

var request_detalle: HTTPRequest
var request_solicitud: HTTPRequest
var btn_gestionar: Button


func _ready() -> void:
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	btn_solicitar.pressed.connect(_on_btn_solicitar_pressed)

	request_detalle = HTTPRequest.new()
	request_solicitud = HTTPRequest.new()

	add_child(request_detalle)
	add_child(request_solicitud)

	request_detalle.request_completed.connect(_on_detalle_completed)
	request_solicitud.request_completed.connect(_on_solicitud_completed)

	btn_gestionar = Button.new()
	btn_gestionar.text = "Gestionar alianza"
	btn_gestionar.visible = false
	$VBoxContainer/MarginContainer/HBoxContainer.add_child(btn_gestionar)
	btn_gestionar.pressed.connect(_on_btn_gestionar_pressed)

	label_titulo.text = "🛡️ Cargando alianza..."
	label_info.text = "Cargando información..."
	btn_solicitar.visible = false
	btn_solicitar.disabled = true


func configurar_vista(
	id_alianza: int,
	nombre_alianza: String,
	req_poder: int
) -> void:
	id_actual = id_alianza
	nombre_actual = nombre_alianza
	requisito_actual = req_poder

	label_titulo.text = "🛡️ " + nombre_actual
	label_info.text = "Cargando detalle de la alianza..."

	print("========== VISTA DETALLADA ALIANZA ==========")
	print("ID recibido: ", id_actual)
	print("Nombre recibido: ", nombre_actual)
	print("Requisito recibido: ", requisito_actual)

	_cargar_detalle_alianza()


func _on_btn_volver_pressed() -> void:
	queue_free()


func _on_btn_gestionar_pressed() -> void:
	var gestion = GestionAlianzaEscena.instantiate()
	get_tree().current_scene.add_child(gestion)


func _on_btn_solicitar_pressed() -> void:
	if id_actual <= 0:
		label_info.text = "No se puede solicitar ingreso: ID de alianza inválido."
		return

	btn_solicitar.disabled = true
	btn_solicitar.text = "Enviando..."

	var payload: Dictionary = {
		"mensaje": "Solicitud enviada desde Godot."
	}

	var url: String = (
		APIManager.base_url
		+ "/alianzas/"
		+ str(id_actual)
		+ "/solicitudes"
	)

	print("========== ENVIANDO SOLICITUD DIRECTA ==========")
	print("Usuario actual: ", APIManager.usuario_actual)
	print("ID alianza destino: ", id_actual)
	print("URL POST: ", url)
	print("Payload: ", JSON.stringify(payload))

	var error: int = request_solicitud.request(
		url,
		_auth_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		btn_solicitar.disabled = false
		btn_solicitar.text = "📩 Solicitar"
		label_info.text = "No fue posible enviar la solicitud. Error Godot: " + str(error)


func _cargar_detalle_alianza() -> void:
	if id_actual <= 0:
		label_info.text = "No se pudo cargar la alianza: ID inválido."
		return

	var url: String = APIManager.base_url + "/alianzas/" + str(id_actual)

	print("Solicitando detalle alianza: ", url)

	var error: int = request_detalle.request(
		url,
		_auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		label_info.text = "No fue posible iniciar la solicitud del detalle. Error Godot: " + str(error)


func _on_detalle_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var texto: String = body.get_string_from_utf8()

	print("========== DETALLE ALIANZA ==========")
	print("HTTP: ", response_code)
	print("Body: ", texto)

	if response_code != 200:
		label_info.text = _extraer_error_backend(texto, response_code)
		return

	var parsed: Variant = JSON.parse_string(texto)

	if typeof(parsed) != TYPE_DICTIONARY:
		label_info.text = "El servidor devolvió un detalle inválido."
		return

	var datos: Dictionary = parsed as Dictionary
	_actualizar_vista(datos)


func _on_solicitud_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var texto: String = body.get_string_from_utf8()

	print("========== RESPUESTA SOLICITUD ==========")
	print("HTTP: ", response_code)
	print("Body: ", texto)

	if response_code == 201:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Solicitud enviada"
		label_info.text = (
			"Solicitud enviada correctamente.\n\n"
			+ "Ahora inicia sesión como líder y revisa: "
			+ "Mi Alianza → Gestionar alianza → Solicitudes."
		)
		return

	btn_solicitar.disabled = false
	btn_solicitar.text = "📩 Solicitar"
	label_info.text = _extraer_error_backend(texto, response_code)


func _actualizar_vista(datos: Dictionary) -> void:
	id_actual = _to_int(datos.get("id", id_actual), id_actual)
	nombre_actual = str(datos.get("nombre", nombre_actual))
	requisito_actual = _to_int(datos.get("req_poder", requisito_actual), requisito_actual)

	var tag: String = str(datos.get("tag", "---"))
	var nivel: int = _to_int(datos.get("nivel", 1), 1)
	var miembros_actuales: int = _to_int(datos.get("miembros_actuales", 0), 0)
	var miembros_maximos: int = _to_int(datos.get("miembros_maximos", 0), 0)
	var poder_total: String = str(datos.get("poder_total", "0"))
	var region: String = str(datos.get("region", "ES"))
	var lider_jugador_id: int = _to_int(datos.get("lider_jugador_id", 0), 0)

	var jugador_id: int = _to_int(
		APIManager.usuario_actual.get("player_id", 0),
		0
	)

	var alliance_id_usuario: int = _to_int(
		APIManager.usuario_actual.get("alliance_id", 0),
		0
	)

	var usuario_tiene_alianza: bool = alliance_id_usuario > 0
	var usuario_es_lider: bool = (
		lider_jugador_id > 0
		and lider_jugador_id == jugador_id
	)

	label_titulo.text = (
		"🛡️ "
		+ nombre_actual
		+ " ["
		+ tag
		+ "]"
	)

	label_info.text = (
		"Nivel: " + str(nivel) + "\n"
		+ "Miembros: " + str(miembros_actuales) + "/" + str(miembros_maximos) + "\n"
		+ "Poder total: " + poder_total + "\n"
		+ "Región: " + region + "\n"
		+ "Poder requerido: " + str(requisito_actual) + "\n"
		+ "ID alianza: " + str(id_actual) + "\n"
		+ "Líder jugador ID: " + str(lider_jugador_id)
	)

	btn_gestionar.visible = usuario_es_lider

	if usuario_es_lider:
		btn_solicitar.visible = false
	elif usuario_tiene_alianza:
		btn_solicitar.visible = true
		btn_solicitar.disabled = true
		btn_solicitar.text = "Ya tienes alianza"
	elif lider_jugador_id <= 0:
		btn_solicitar.visible = true
		btn_solicitar.disabled = true
		btn_solicitar.text = "Sin líder"
	else:
		btn_solicitar.visible = true
		_configurar_boton_solicitud()

	var raw_miembros: Variant = datos.get("miembros", [])

	if typeof(raw_miembros) == TYPE_ARRAY:
		_cargar_miembros(raw_miembros as Array)
	else:
		_cargar_miembros([])


func _configurar_boton_solicitud() -> void:
	var poder_jugador: int = _to_int(
		APIManager.usuario_actual.get("poder", 0),
		0
	)

	if poder_jugador < requisito_actual:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Poder insuficiente"
	else:
		btn_solicitar.disabled = false
		btn_solicitar.text = "📩 Solicitar"


func _cargar_miembros(miembros: Array) -> void:
	for hijo: Node in contenedor_miembros.get_children():
		hijo.queue_free()

	if miembros.is_empty():
		var label_vacio: Label = Label.new()
		label_vacio.text = "No hay miembros reales registrados en esta alianza."
		contenedor_miembros.add_child(label_vacio)
		return

	for item: Variant in miembros:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var miembro: Dictionary = item as Dictionary

		var tarjeta: PanelContainer = PanelContainer.new()
		var margen: MarginContainer = MarginContainer.new()
		var label: Label = Label.new()

		margen.add_theme_constant_override("margin_left", 12)
		margen.add_theme_constant_override("margin_top", 8)
		margen.add_theme_constant_override("margin_right", 12)
		margen.add_theme_constant_override("margin_bottom", 8)

		var es_lider: bool = bool(miembro.get("es_lider", false))
		var rango: String = "Líder" if es_lider else "Miembro"

		label.text = (
			"👤 "
			+ str(miembro.get("nombre", "Jugador"))
			+ " | "
			+ rango
			+ " | ⚡ "
			+ str(miembro.get("poder", 0))
		)

		margen.add_child(label)
		tarjeta.add_child(margen)
		contenedor_miembros.add_child(tarjeta)


func _extraer_error_backend(response_text: String, response_code: int) -> String:
	if response_text.strip_edges().is_empty():
		return "Error HTTP " + str(response_code)

	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary

		if response.has("detail"):
			return str(response["detail"])

		if response.has("mensaje"):
			return str(response["mensaje"])

	return "Error HTTP " + str(response_code) + ": " + response_text


func _auth_headers() -> PackedStringArray:
	var headers: PackedStringArray = PackedStringArray()

	for header: Variant in APIManager.get_auth_headers():
		headers.append(str(header))

	return headers


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return int(value)

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var texto: String = str(value).strip_edges()

		if texto.is_valid_int():
			return texto.to_int()

	return fallback
