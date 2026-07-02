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
	btn_ingresar.disabled = false 
	
	if response_code == 200:
		var json_respuesta = JSON.parse_string(body.get_string_from_utf8())
		APIManager.token_jwt = json_respuesta["access_token"]
		
		# Si el backend real nos envía datos del usuario, los guardaríamos aquí.
		# Por ahora, pasamos a la siguiente pantalla:
		get_tree().change_scene_to_file("res://menu_busqueda.tscn")
		
	elif response_code == 0:
		# TRUCO FRONTEND: Servidor apagado, simulamos inicio de sesión
		label_mensaje.modulate = Color.GREEN
		label_mensaje.text = "Modo Offline: Sesión simulada iniciada."
		
		# Guardamos los datos falsos usando lo que el jugador escribió en el LineEdit
		APIManager.usuario_actual = {
			"nombre": input_usuario.text.get_slice("@", 0), # Corta el texto antes del '@' para usarlo de nombre
			"rango": "Comandante Novato",
			"poder": 350000,
			"estado": "🟢 Online"
		}
		
		await get_tree().create_timer(1.0).timeout # Pequeña pausa dramática
		get_tree().change_scene_to_file("res://menu_busqueda.tscn")
		
	else:
		mostrar_error("Usuario o contraseña incorrectos.")

func mostrar_error(mensaje: String):
	label_mensaje.text = mensaje
	label_mensaje.modulate = Color.RED
	
	
func _on_btn_registro_pressed():
		get_tree().change_scene_to_file("res://menu_registro.tscn")
