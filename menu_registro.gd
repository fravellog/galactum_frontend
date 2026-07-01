extends Control

# Referencias a los nodos
@onready var input_email = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Email
@onready var input_username = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Username
@onready var input_password = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Password
@onready var btn_registrar = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Registro
@onready var btn_volver = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Volver
@onready var label_mensaje = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label_Mensaje
@onready var http_request = $HTTPRequest

func _ready():
	btn_registrar.pressed.connect(_on_btn_registrar_pressed)
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	http_request.request_completed.connect(_on_request_completed)

# Botón para regresar si el usuario se arrepiente
func _on_btn_volver_pressed():
	get_tree().change_scene_to_file("res://menu_login.tscn")

func _on_btn_registrar_pressed():
	# Bloqueamos el botón y avisamos al usuario
	btn_registrar.disabled = true
	label_mensaje.text = "Creando cuenta en el servidor..."
	label_mensaje.modulate = Color.WHITE
	
	# Preparamos el diccionario exactamente como lo pide el Swagger
	var datos_registro = {
		"email": input_email.text,
		"username": input_username.text,
		"password": input_password.text
	}
	var json_enviar = JSON.stringify(datos_registro)
	
	# Usamos la ruta de registro
	var url = APIManager.base_url + "/auth/register" 
	var headers = ["Content-Type: application/json"]
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_enviar)
	if error != OK:
		mostrar_error("Error crítico al intentar conectar.")

func _on_request_completed(result, response_code, headers, body):
	btn_registrar.disabled = false
	
	# Códigos HTTP 200 o 201 significan que se creó con éxito
	if response_code == 200 or response_code == 201:
		label_mensaje.modulate = Color.GREEN
		label_mensaje.text = "¡Cuenta creada! Volviendo al inicio..."
		
		# Hacemos una pequeña pausa de 1.5 segundos para que el jugador lea el éxito
		await get_tree().create_timer(1.5).timeout
		
		# Lo enviamos de regreso al login para que inicie sesión
		get_tree().change_scene_to_file("res://menu_login.tscn")
	else:
		mostrar_error("Error del servidor: Código " + str(response_code))

func mostrar_error(mensaje: String):
	label_mensaje.text = mensaje
	label_mensaje.modulate = Color.RED
