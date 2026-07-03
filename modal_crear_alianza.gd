extends Control

@onready var btn_cancelar = $PanelCentral/MarginContainer/VBoxContainer/HBoxContainer_Botones/Button_Cancelar
@onready var btn_confirmar = $PanelCentral/MarginContainer/VBoxContainer/HBoxContainer_Botones/Button_Confirmar
@onready var input_nombre = $PanelCentral/MarginContainer/VBoxContainer/LineEdit_Nombre
@onready var input_tag = $PanelCentral/MarginContainer/VBoxContainer/LineEdit_Region
@onready var input_req_poder = $PanelCentral/MarginContainer/VBoxContainer/LineEdit_RequisitoPoder
@onready var label_estado = $PanelCentral/MarginContainer/VBoxContainer/Label_Estado
@onready var http_request = $HTTPRequest


func _ready():
	btn_cancelar.pressed.connect(_on_btn_cancelar_pressed)
	btn_confirmar.pressed.connect(_on_btn_confirmar_pressed)
	http_request.request_completed.connect(_on_request_completed)


func _on_btn_cancelar_pressed():
	queue_free()


func _on_btn_confirmar_pressed():
	var nombre = input_nombre.text.strip_edges()
	var tag = input_tag.text.strip_edges().to_upper()
	var req_text = input_req_poder.text.strip_edges()

	if nombre.length() < 3 or tag.length() < 2:
		label_estado.text = "El nombre debe tener al menos 3 caracteres y el TAG al menos 2."
		return

	var req_poder = 0
	if not req_text.is_empty():
		if not req_text.is_valid_int() or int(req_text) < 0:
			label_estado.text = "El requisito de poder debe ser un número entero igual o mayor que 0."
			return
		req_poder = int(req_text)

	btn_confirmar.disabled = true
	btn_confirmar.text = "Creando..."
	label_estado.text = "Registrando alianza en el servidor..."

	var datos_alianza = {
		"nombre": nombre,
		"tag": tag,
		"req_poder": req_poder,
	}

	var error = http_request.request(
		APIManager.base_url + "/alianzas/crear",
		APIManager.get_auth_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(datos_alianza)
	)

	if error != OK:
		btn_confirmar.disabled = false
		btn_confirmar.text = "Confirmar"
		label_estado.text = "No fue posible iniciar la conexión."


func _on_request_completed(_result, response_code, _headers, body):
	var response_text = body.get_string_from_utf8()

	if response_code == 201:
		label_estado.text = "Alianza creada. Eres su líder."
		await get_tree().create_timer(1.2).timeout
		queue_free()
		return

	btn_confirmar.disabled = false
	btn_confirmar.text = "Confirmar"
	var response = JSON.parse_string(response_text)
	if typeof(response) == TYPE_DICTIONARY and response.has("detail"):
		label_estado.text = str(response["detail"])
	else:
		label_estado.text = "Error al crear alianza. Código: " + str(response_code)
