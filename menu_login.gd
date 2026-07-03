extends Control

@onready var input_usuario = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Usuario
@onready var input_password = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Password
@onready var btn_ingresar = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Ingresar
@onready var label_mensaje = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label_Mensaje
@onready var btn_registro = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Registro
@onready var http_request = $HTTPRequest

var solicitud_actual := ""


func _ready():
	btn_ingresar.pressed.connect(_on_btn_ingresar_pressed)
	btn_registro.pressed.connect(_on_btn_registro_pressed)
	http_request.request_completed.connect(_on_request_completed)


func _on_btn_ingresar_pressed():
	btn_ingresar.disabled = true
	label_mensaje.text = "Conectando al servidor..."
	label_mensaje.modulate = Color.WHITE
	solicitud_actual = "login"

	var datos_login = {
		"email": input_usuario.text.strip_edges(),
		"password": input_password.text,
	}
	var error = http_request.request(
		APIManager.base_url + "/auth/login",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(datos_login)
	)

	if error != OK:
		mostrar_error("No fue posible conectar con el servidor.")
		btn_ingresar.disabled = false


func _on_request_completed(_result, response_code, _headers, body):
	var response_text = body.get_string_from_utf8()

	if solicitud_actual == "login":
		_procesar_login(response_code, response_text)
	elif solicitud_actual == "verify":
		_procesar_verify(response_code, response_text)


func _procesar_login(response_code: int, response_text: String):
	if response_code != 200:
		btn_ingresar.disabled = false
		mostrar_error("Correo o contraseña incorrectos.")
		return

	var response_json = JSON.parse_string(response_text)
	if typeof(response_json) != TYPE_DICTIONARY or not response_json.has("access_token"):
		btn_ingresar.disabled = false
		mostrar_error("El servidor devolvió una respuesta inválida.")
		return

	APIManager.token_jwt = str(response_json["access_token"])
	solicitud_actual = "verify"
	label_mensaje.text = "Cargando perfil del comandante..."

	var error = http_request.request(
		APIManager.base_url + "/auth/verify",
		APIManager.get_auth_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		btn_ingresar.disabled = false
		mostrar_error("No fue posible cargar el perfil.")


func _procesar_verify(response_code: int, response_text: String):
	btn_ingresar.disabled = false

	if response_code != 200:
		mostrar_error("El token fue creado, pero no se pudo cargar el perfil.")
		return

	var profile = JSON.parse_string(response_text)
	if typeof(profile) != TYPE_DICTIONARY:
		mostrar_error("El perfil recibido no tiene un formato válido.")
		return

	APIManager.usuario_actual = {
		"player_id": int(profile.get("player_id", 0)),
		"nombre": str(profile.get("player_nickname", "Comandante")),
		"poder": int(profile.get("player_power", 0)),
		"alliance_id": profile.get("alliance_id", null),
	}

	get_tree().change_scene_to_file("res://menu_busqueda.tscn")


func mostrar_error(mensaje: String):
	label_mensaje.text = mensaje
	label_mensaje.modulate = Color.RED


func _on_btn_registro_pressed():
	get_tree().change_scene_to_file("res://menu_registro.tscn")
