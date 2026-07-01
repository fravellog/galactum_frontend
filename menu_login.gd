extends Control

@onready var input_usuario = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Usuario
@onready var input_password = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Password
@onready var btn_ingresar = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Ingresar
@onready var label_mensaje = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label_Mensaje
@onready var btn_registro = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Registro
@onready var http_request = $HTTPRequest

func _ready():
	btn_ingresar.pressed.connect(_on_btn_ingresar_pressed)
	btn_registro.pressed.connect(_on_btn_registro_pressed)
	http_request.request_completed.connect(_on_request_completed)
	

func _on_btn_ingresar_pressed():
	# Bloqueamos el botón para evitar doble clic
	btn_ingresar.disabled = true
	label_mensaje.text = "Conectando al servidor..."
	label_mensaje.modulate = Color.WHITE
	
	# CORRECCIÓN 1: Cambiamos "username" por "email" según pide el Swagger
	var datos_login = {
		"email": input_usuario.text, 
		"password": input_password.text
	}
	var json_enviar = JSON.stringify(datos_login)
	
	# CORRECCIÓN 2: Ajustamos la URL exacta del backend
	var url = APIManager.base_url + "/auth/login" 
	var headers = ["Content-Type: application/json"]
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_enviar)
	if error != OK:
		mostrar_error("Error crítico de conexión HTTP.")

func _on_request_completed(result, response_code, headers, body):
	btn_ingresar.disabled = false # Desbloqueamos el botón
	
	if response_code == 200:
		var json_respuesta = JSON.parse_string(body.get_string_from_utf8())
		
		# ¡Éxito! Guardamos el token en nuestro APIManager global
		APIManager.token_jwt = json_respuesta["access_token"]
		
		# Cambiamos de escena al menú de búsqueda de alianzas
		get_tree().change_scene_to_file("res://menu_busqueda.tscn")
	else:
		# Si el backend rechaza las credenciales (ej. código 401)
		mostrar_error("Usuario o contraseña incorrectos.")

func mostrar_error(mensaje: String):
	label_mensaje.text = mensaje
	label_mensaje.modulate = Color.RED
	
	
func _on_btn_registro_pressed():
		get_tree().change_scene_to_file("res://menu_registro.tscn")
