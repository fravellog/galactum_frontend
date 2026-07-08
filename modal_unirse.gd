extends Control

@onready var label_titulo: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label_Titulo
@onready var label_req: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label2
@onready var label_estado: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label_Estado

@onready var input_mensaje: TextEdit = $CenterContainer/Panel/MarginContainer/VBoxContainer/TextEdit_Mensaje
@onready var checkbox_reglas: CheckBox = $CenterContainer/Panel/MarginContainer/VBoxContainer/CheckBox_Reglas

@onready var btn_enviar: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button_Enviar
@onready var btn_cancelar: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button_Cancelar

@onready var http_request: HTTPRequest = $HTTPRequest

var id_alianza_destino: int = 0
var nombre_alianza_destino: String = ""
var requisito_poder: int = 0


func _ready() -> void:
	btn_enviar.disabled = true

	checkbox_reglas.toggled.connect(_on_checkbox_reglas_toggled)
	btn_cancelar.pressed.connect(_on_btn_cancelar_pressed)
	btn_enviar.pressed.connect(_on_btn_enviar_pressed)
	http_request.request_completed.connect(_on_request_completed)


func configurar_modal(
	id_alianza: int,
	nombre_alianza: String,
	req_poder: int
) -> void:
	id_alianza_destino = id_alianza
	nombre_alianza_destino = nombre_alianza
	requisito_poder = req_poder

	var poder_jugador: int = _to_int(
		APIManager.usuario_actual.get("poder", 0),
		0
	)

	label_titulo.text = (
		"📩 Solicitud para "
		+ nombre_alianza_destino
	)

	label_req.text = (
		"ID alianza: "
		+ str(id_alianza_destino)
		+ " | Poder requerido: "
		+ str(requisito_poder)
		+ " | Tu poder: "
		+ str(poder_jugador)
	)

	if id_alianza_destino <= 0:
		label_estado.text = "Error: ID de alianza inválido."
		checkbox_reglas.disabled = true
		btn_enviar.disabled = true
		return

	if poder_jugador < requisito_poder:
		label_estado.text = "No cumples el requisito mínimo de poder."
		checkbox_reglas.disabled = true
		btn_enviar.disabled = true
		return

	label_estado.text = "Escribe un mensaje opcional para el líder."
	checkbox_reglas.disabled = false
	btn_enviar.disabled = not checkbox_reglas.button_pressed


func _on_checkbox_reglas_toggled(esta_marcado: bool) -> void:
	var poder_jugador: int = _to_int(
		APIManager.usuario_actual.get("poder", 0),
		0
	)

	btn_enviar.disabled = (
		not esta_marcado
		or poder_jugador < requisito_poder
		or id_alianza_destino <= 0
	)


func _on_btn_cancelar_pressed() -> void:
	queue_free()


func _on_btn_enviar_pressed() -> void:
	if id_alianza_destino <= 0:
		label_estado.text = "No se puede enviar: ID de alianza inválido."
		return

	btn_enviar.disabled = true
	btn_enviar.text = "Enviando..."
	label_estado.text = "Registrando solicitud en FastAPI..."

	var payload: Dictionary = {
		"mensaje": input_mensaje.text.strip_edges()
	}

	var url: String = (
		APIManager.base_url
		+ "/alianzas/"
		+ str(id_alianza_destino)
		+ "/solicitudes"
	)

	print("=== SOLICITUD DE ALIANZA ===")
	print("Usuario actual: ", APIManager.usuario_actual)
	print("URL POST: ", url)
	print("Payload: ", JSON.stringify(payload))

	var error: int = http_request.request(
		url,
		PackedStringArray(APIManager.get_auth_headers()),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		btn_enviar.disabled = false
		btn_enviar.text = "📩 Enviar solicitud"
		label_estado.text = "No fue posible iniciar la conexión. Error: " + str(error)


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var response_text: String = body.get_string_from_utf8()

	print("=== RESPUESTA SOLICITUD ALIANZA ===")
	print("HTTP: ", response_code)
	print("Body: ", response_text)

	if response_code == 201:
		label_estado.text = "Solicitud enviada correctamente."
		btn_enviar.text = "Solicitud enviada"
		btn_enviar.disabled = true
		checkbox_reglas.disabled = true

		await get_tree().create_timer(1.5).timeout

		queue_free()
		return

	btn_enviar.disabled = false
	btn_enviar.text = "📩 Enviar solicitud"
	label_estado.text = _extraer_error_backend(response_text, response_code)


func _extraer_error_backend(
	response_text: String,
	response_code: int
) -> String:
	if response_text.strip_edges().is_empty():
		return "Error al enviar solicitud. Código: " + str(response_code)

	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed as Dictionary

		if response.has("detail"):
			return str(response["detail"])

		if response.has("mensaje"):
			return str(response["mensaje"])

	return (
		"Error al enviar solicitud. Código: "
		+ str(response_code)
		+ " | "
		+ response_text
	)


func _on_color_rect_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		queue_free()


func _to_int(value: Variant, fallback: int = 0) -> int:
	if value == null:
		return fallback

	if typeof(value) == TYPE_INT:
		return int(value)

	if typeof(value) == TYPE_FLOAT:
		return int(value)

	if typeof(value) == TYPE_STRING:
		var text_value: String = str(value).strip_edges()

		if text_value.is_valid_int():
			return text_value.to_int()

	return fallback
