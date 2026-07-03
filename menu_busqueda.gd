extends Control

var TarjetaAlianzaEscena = preload("res://tarjeta_alianza.tscn")
var MapaGalacticoEscena = preload("res://mapa_galactico.tscn")
var GestionTripulacionEscena = preload("res://gestion_tripulacion.tscn")
var ModalCrearEscena = preload("res://modal_crear_alianza.tscn")
var VistaDetalladaEscena = preload("res://vista_detallada.tscn")

@onready var input_busqueda = $VBoxContainer/HBoxContainer/LineEdit
@onready var btn_buscar = $VBoxContainer/HBoxContainer/Button_Buscar
@onready var btn_fundar = $VBoxContainer/HBoxContainer/Button_Fundar

@onready var btn_mi_alianza = $VBoxContainer/Header/HBoxContainer/Button_MiAlianza
@onready var btn_mapa = $VBoxContainer/Header/HBoxContainer/Button_Mapa
@onready var btn_tripulacion = $VBoxContainer/Header/HBoxContainer/Button_Tripulacion
@onready var btn_salir = $VBoxContainer/Header/HBoxContainer/Button_Salir

@onready var label_saludo = $VBoxContainer/Header/HBoxContainer/Label_Saludo
@onready var label_estado = $VBoxContainer/Label_Estado

@onready var http_request = $HTTPRequest
@onready var contenedor_lista = $VBoxContainer/ScrollContainer/VBoxContainer

var tipo_solicitud: String = ""


func _ready():
	btn_buscar.pressed.connect(_on_btn_buscar_pressed)
	btn_fundar.pressed.connect(_on_btn_crear_alianza_pressed)

	btn_mi_alianza.pressed.connect(_on_btn_mi_alianza_pressed)
	btn_mapa.pressed.connect(_on_btn_mapa_pressed)
	btn_tripulacion.pressed.connect(_on_btn_tripulacion_pressed)
	btn_salir.pressed.connect(_on_btn_salir_pressed)

	input_busqueda.text_submitted.connect(_on_busqueda_enviada)

	http_request.request_completed.connect(_on_request_completed)

	_actualizar_saludo()
	_buscar_alianzas("")


func _actualizar_saludo():
	if APIManager.usuario_actual.has("nombre"):
		var nombre = str(APIManager.usuario_actual["nombre"])
		var poder = str(APIManager.usuario_actual.get("poder", 0))

		label_saludo.text = "Comandante: " + nombre + " | Poder: " + poder
	else:
		label_saludo.text = "Sesión no detectada."


func _obtener_headers_autenticados() -> PackedStringArray:
	return APIManager.get_auth_headers()


func _limpiar_lista():
	for hijo in contenedor_lista.get_children():
		hijo.queue_free()


func _mostrar_estado(mensaje: String):
	label_estado.text = mensaje


func _on_btn_buscar_pressed():
	var termino = input_busqueda.text.strip_edges()
	_buscar_alianzas(termino)


func _on_busqueda_enviada(texto: String):
	_buscar_alianzas(texto.strip_edges())


func _buscar_alianzas(termino: String):
	tipo_solicitud = "buscar"

	_limpiar_lista()

	if termino.is_empty():
		_mostrar_estado("Cargando alianzas disponibles...")
	else:
		_mostrar_estado("Buscando alianzas...")

	var url = APIManager.base_url + "/alianzas/buscar?search=" + termino.uri_encode()

	var error = http_request.request(
		url,
		_obtener_headers_autenticados(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_mostrar_estado("No fue posible iniciar la conexión con el servidor.")


func _on_btn_mi_alianza_pressed():
	tipo_solicitud = "mi_alianza"

	_mostrar_estado("Consultando tu alianza...")

	var url = APIManager.base_url + "/alianzas/mi-alianza"

	var error = http_request.request(
		url,
		_obtener_headers_autenticados(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_mostrar_estado("No fue posible iniciar la consulta de tu alianza.")


func _on_request_completed(_result, response_code, _headers, body):
	var texto = body.get_string_from_utf8()

	if tipo_solicitud == "mi_alianza":
		_procesar_mi_alianza(response_code, texto)
		return

	_procesar_busqueda(response_code, texto)


func _procesar_busqueda(response_code: int, texto: String):
	if response_code != 200:
		_mostrar_estado("Error al cargar alianzas. Código HTTP: " + str(response_code))
		return

	var json_recibido = JSON.parse_string(texto)

	if json_recibido == null:
		_mostrar_estado("El servidor devolvió una respuesta inválida.")
		return

	var lista_alianzas = _convertir_respuesta_a_lista(json_recibido)

	if lista_alianzas.is_empty():
		_mostrar_estado("No se encontraron alianzas.")
		return

	_mostrar_estado(str(lista_alianzas.size()) + " alianza(s) encontrada(s).")

	for datos in lista_alianzas:
		if typeof(datos) != TYPE_DICTIONARY:
			continue

		var nueva_tarjeta = TarjetaAlianzaEscena.instantiate()
		contenedor_lista.add_child(nueva_tarjeta)
		nueva_tarjeta.configurar_tarjeta(datos)


func _procesar_mi_alianza(response_code: int, texto: String):
	if response_code != 200:
		_mostrar_estado(
			"No fue posible consultar tu alianza. Código HTTP: "
			+ str(response_code)
		)
		print("Error Mi alianza: ", texto)
		return

	if texto.strip_edges() == "null":
		_mostrar_estado("Actualmente no perteneces a ninguna alianza.")
		return

	var datos_alianza = JSON.parse_string(texto)

	if typeof(datos_alianza) != TYPE_DICTIONARY:
		_mostrar_estado("La respuesta de tu alianza no tiene un formato válido.")
		print("Respuesta inválida Mi alianza: ", texto)
		return

	var alianza_id = _convertir_a_entero(datos_alianza.get("id"), 0)

	if alianza_id <= 0:
		_mostrar_estado("La alianza recibida no contiene un ID válido.")
		print("Alianza sin ID válido: ", datos_alianza)
		return

	var nombre_alianza = str(datos_alianza.get("nombre", "Mi alianza"))
	var requisito_poder = _convertir_a_entero(
		datos_alianza.get("req_poder"),
		0
	)

	_mostrar_estado("Cargando " + nombre_alianza + "...")

	var vista = VistaDetalladaEscena.instantiate()

	# La escena debe entrar al árbol antes de usar nodos @onready.
	get_tree().current_scene.add_child(vista)

	# Esta función carga el detalle real usando GET /alianzas/{id}.
	vista.configurar_vista(
		alianza_id,
		nombre_alianza,
		requisito_poder
	)
func _convertir_respuesta_a_lista(json_recibido) -> Array:
	if typeof(json_recibido) == TYPE_ARRAY:
		return json_recibido

	if typeof(json_recibido) == TYPE_DICTIONARY:
		if json_recibido.has("alianzas"):
			return json_recibido["alianzas"]

		if json_recibido.has("data"):
			return json_recibido["data"]

		if json_recibido.has("results"):
			return json_recibido["results"]

	return []


func _on_btn_salir_pressed():
	APIManager.usuario_actual = {}
	APIManager.token_jwt = ""

	get_tree().change_scene_to_file("res://menu_login.tscn")


func _on_btn_mapa_pressed():
	var nuevo_mapa = MapaGalacticoEscena.instantiate()
	get_tree().current_scene.add_child(nuevo_mapa)


func _on_btn_tripulacion_pressed():
	var nueva_tripulacion = GestionTripulacionEscena.instantiate()
	get_tree().current_scene.add_child(nueva_tripulacion)


func _on_btn_crear_alianza_pressed():
	var nuevo_modal = ModalCrearEscena.instantiate()
	get_tree().current_scene.add_child(nuevo_modal)
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
