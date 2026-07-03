extends Control

var ModalUnirseEscena = preload("res://modal_unirse.tscn")
var GestionAlianzaEscena = preload("res://gestion_alianza.tscn")

@onready var btn_volver = $VBoxContainer/MarginContainer/HBoxContainer/Button2
@onready var label_titulo = $VBoxContainer/MarginContainer/HBoxContainer/Label
@onready var btn_solicitar = $VBoxContainer/MarginContainer/HBoxContainer/Button

@onready var label_info = $VBoxContainer/TabContainer/Info/Label

@onready var contenedor_miembros = (
	$VBoxContainer/TabContainer/Miembros/VBoxContainer/ScrollContainer/VBoxContainer
)

var id_actual: int = 0
var nombre_actual: String = ""
var requisito_actual: int = 0

var http_request: HTTPRequest
var btn_gestionar: Button


func _ready():
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	btn_solicitar.pressed.connect(_on_btn_solicitar_pressed)

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	btn_gestionar = Button.new()
	btn_gestionar.text = "Gestionar alianza"
	btn_gestionar.visible = false

	$VBoxContainer/MarginContainer/HBoxContainer.add_child(btn_gestionar)

	btn_gestionar.pressed.connect(_on_btn_gestionar_pressed)

	label_titulo.text = "🛡️ Cargando alianza..."
	label_info.text = "Cargando información..."
	btn_solicitar.visible = false


func configurar_vista(id_alianza: int, nombre_alianza: String, req_poder: int):
	id_actual = id_alianza
	nombre_actual = nombre_alianza
	requisito_actual = req_poder

	label_titulo.text = "🛡️ " + nombre_actual
	label_info.text = "Cargando detalle de la alianza..."

	print("Cargando alianza real con ID: ", id_actual)
	print("Nombre recibido: ", nombre_actual)

	_cargar_detalle_alianza()


func _on_btn_volver_pressed():
	queue_free()


func _on_btn_solicitar_pressed():
	if id_actual <= 0:
		label_info.text = "No se puede solicitar ingreso: ID de alianza inválido."
		return

	var nuevo_modal = ModalUnirseEscena.instantiate()

	# Primero entra al árbol.
	get_tree().current_scene.add_child(nuevo_modal)

	# Después se cargan los datos, porque usa @onready.
	nuevo_modal.configurar_modal(
		id_actual,
		nombre_actual,
		requisito_actual
	)


func _on_btn_gestionar_pressed():
	var gestion = GestionAlianzaEscena.instantiate()
	get_tree().current_scene.add_child(gestion)


func _cargar_detalle_alianza():
	if id_actual <= 0:
		label_info.text = "No se pudo cargar la alianza: ID inválido."
		return

	var url = APIManager.base_url + "/alianzas/" + str(id_actual)

	print("Solicitando detalle: ", url)

	var error = http_request.request(
		url,
		APIManager.get_auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		label_info.text = "No fue posible iniciar la solicitud del detalle."


func _on_request_completed(_result, response_code, _headers, body):
	var texto = body.get_string_from_utf8()

	print("Detalle de alianza - HTTP: ", response_code)
	print("Detalle de alianza - Body: ", texto)

	if response_code != 200:
		label_info.text = (
			"No fue posible cargar la alianza. Código HTTP: "
			+ str(response_code)
		)
		return

	var datos = JSON.parse_string(texto)

	if typeof(datos) != TYPE_DICTIONARY:
		label_info.text = "El servidor devolvió un detalle inválido."
		return

	_actualizar_vista(datos)


func _actualizar_vista(datos: Dictionary):
	id_actual = _convertir_a_entero(datos.get("id"), id_actual)
	nombre_actual = str(datos.get("nombre", nombre_actual))
	requisito_actual = _convertir_a_entero(
		datos.get("req_poder"),
		requisito_actual
	)

	var tag = str(datos.get("tag", "---"))
	var nivel = _convertir_a_entero(datos.get("nivel"), 1)

	var miembros_actuales = _convertir_a_entero(
		datos.get("miembros_actuales"),
		0
	)

	var miembros_maximos = _convertir_a_entero(
		datos.get("miembros_maximos"),
		0
	)

	var poder_total = str(datos.get("poder_total", "0"))
	var region = str(datos.get("region", "ES"))

	var lider_jugador_id = _convertir_a_entero(
		datos.get("lider_jugador_id"),
		0
	)

	var jugador_id = _convertir_a_entero(
		APIManager.usuario_actual.get("player_id"),
		0
	)

	var alliance_id_usuario = APIManager.usuario_actual.get("alliance_id")

	var usuario_tiene_alianza = (
		alliance_id_usuario != null
		and _convertir_a_entero(alliance_id_usuario, 0) > 0
	)

	var usuario_es_lider = (
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
		+ "Miembros: " + str(miembros_actuales)
		+ "/" + str(miembros_maximos) + "\n"
		+ "Poder total: " + poder_total + "\n"
		+ "Región: " + region + "\n"
		+ "Poder requerido: " + str(requisito_actual)
	)

	btn_gestionar.visible = usuario_es_lider

	# El líder no debe enviar solicitud a su propia alianza.
	# Un miembro ya aceptado tampoco.
	btn_solicitar.visible = not usuario_tiene_alianza

	var poder_jugador = _convertir_a_entero(
		APIManager.usuario_actual.get("poder"),
		0
	)

	if poder_jugador < requisito_actual:
		btn_solicitar.disabled = true
		btn_solicitar.text = "Poder insuficiente"
	else:
		btn_solicitar.disabled = false
		btn_solicitar.text = "📩 Solicitar"

	var miembros = datos.get("miembros", [])

	if typeof(miembros) != TYPE_ARRAY:
		miembros = []

	_cargar_miembros(miembros)


func _cargar_miembros(miembros: Array):
	for hijo in contenedor_miembros.get_children():
		hijo.queue_free()

	if miembros.is_empty():
		var label_vacio = Label.new()
		label_vacio.text = "No hay miembros reales registrados en esta alianza."
		contenedor_miembros.add_child(label_vacio)
		return

	for miembro in miembros:
		if typeof(miembro) != TYPE_DICTIONARY:
			continue

		var tarjeta = PanelContainer.new()
		var margen = MarginContainer.new()
		var label = Label.new()

		margen.add_theme_constant_override("margin_left", 12)
		margen.add_theme_constant_override("margin_top", 8)
		margen.add_theme_constant_override("margin_right", 12)
		margen.add_theme_constant_override("margin_bottom", 8)

		var es_lider = bool(miembro.get("es_lider", false))

		var rango = "Líder" if es_lider else "Miembro"

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


func _convertir_a_entero(valor, valor_por_defecto: int = 0) -> int:
	if valor == null:
		return valor_por_defecto

	if typeof(valor) == TYPE_INT:
		return valor

	if typeof(valor) == TYPE_FLOAT:
		return int(valor)

	if typeof(valor) == TYPE_STRING:
		var texto = str(valor).strip_edges()

		if texto.is_valid_int():
			return texto.to_int()

	return valor_por_defecto
