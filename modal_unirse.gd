extends Control

@onready var label_titulo = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label_Titulo
@onready var label_req = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label2
@onready var label_estado = $CenterContainer/Panel/MarginContainer/VBoxContainer/Label_Estado

@onready var input_mensaje = $CenterContainer/Panel/MarginContainer/VBoxContainer/TextEdit_Mensaje
@onready var checkbox_reglas = $CenterContainer/Panel/MarginContainer/VBoxContainer/CheckBox_Reglas

@onready var btn_enviar = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button_Enviar
@onready var btn_cancelar = $CenterContainer/Panel/MarginContainer/VBoxContainer/HBoxContainer/Button_Cancelar

@onready var http_request = $HTTPRequest
var id_alianza_destino: int = 0
var requisito_poder: int = 0


func _ready():
	btn_enviar.disabled = true
	checkbox_reglas.toggled.connect(_on_checkbox_reglas_toggled)
	btn_cancelar.pressed.connect(_on_btn_cancelar_pressed)
	btn_enviar.pressed.connect(_on_btn_enviar_pressed)
	http_request.request_completed.connect(_on_request_completed)


func _on_checkbox_reglas_toggled(esta_marcado: bool):
	var poder_jugador = int(APIManager.usuario_actual.get("poder", 0))
	btn_enviar.disabled = not esta_marcado or poder_jugador < requisito_poder


func _on_btn_cancelar_pressed():
	queue_free()


func _on_btn_enviar_pressed():
	btn_enviar.disabled = true
	btn_enviar.text = "Enviando..."
	label_estado.text = "Registrando solicitud..."

	var payload = {"mensaje": input_mensaje.text.strip_edges()}
	var url = APIManager.base_url + "/alianzas/" + str(id_alianza_destino) + "/solicitudes"
	var error = http_request.request(
		url,
		APIManager.get_auth_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		btn_enviar.disabled = false
		btn_enviar.text = "📩 Enviar solicitud"
		label_estado.text = "No fue posible iniciar la conexión."


func _on_request_completed(_result, response_code, _headers, body):
	var response_text = body.get_string_from_utf8()

	if response_code == 201:
		label_estado.text = "Solicitud enviada. Espera la decisión del líder."
		btn_enviar.text = "Solicitud enviada"
		checkbox_reglas.disabled = true
		await get_tree().create_timer(1.5).timeout
		queue_free()
		return

	btn_enviar.disabled = false
	btn_enviar.text = "📩 Enviar solicitud"

	var response_json = JSON.parse_string(response_text)
	if typeof(response_json) == TYPE_DICTIONARY and response_json.has("detail"):
		label_estado.text = str(response_json["detail"])
	else:
		label_estado.text = "Error al enviar solicitud. Código: " + str(response_code)


func configurar_modal(id_alianza: int, nombre_alianza: String, req_poder: int):
	if label_titulo == null:
		push_error("No se encontró Label de título en modal_unirse.tscn")
		return

	if label_req == null:
		push_error("No se encontró Label2 de requisito en modal_unirse.tscn")
		return

	if label_estado == null:
		push_error("No se encontró Label_Estado en modal_unirse.tscn")
		return

	id_alianza_destino = id_alianza
	requisito_poder = req_poder

	var poder_jugador = _convertir_a_entero(
		APIManager.usuario_actual.get("poder"),
		0
	)

	label_titulo.text = "📩 Solicitud para " + nombre_alianza
	label_req.text = (
		"Poder requerido: " + str(req_poder)
		+ " | Tu poder: " + str(poder_jugador)
	)

	if poder_jugador < requisito_poder:
		label_estado.text = "No cumples el requisito mínimo de poder."
		checkbox_reglas.disabled = true
		btn_enviar.disabled = true
	else:
		label_estado.text = "Escribe un mensaje opcional para el líder."
		checkbox_reglas.disabled = false
		btn_enviar.disabled = not checkbox_reglas.button_pressed

func _on_color_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
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
