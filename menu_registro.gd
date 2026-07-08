extends Control


@onready var input_email: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Email
@onready var input_username: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Username
@onready var input_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEdit_Password
@onready var btn_registrar: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Registro
@onready var btn_volver: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Button_Volver
@onready var label_mensaje: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label_Mensaje
@onready var http_request: HTTPRequest = $HTTPRequest


func _ready() -> void:
	btn_registrar.pressed.connect(_on_btn_registrar_pressed)
	btn_volver.pressed.connect(_on_btn_volver_pressed)
	http_request.request_completed.connect(_on_request_completed)


func _on_btn_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://menu_login.tscn")


func _on_btn_registrar_pressed() -> void:
	var email: String = input_email.text.strip_edges().to_lower()
	var username: String = input_username.text.strip_edges()
	var password: String = input_password.text

	if email.is_empty() or username.is_empty() or password.is_empty():
		mostrar_error("Completa correo, usuario y contraseña.")
		return

	if username.length() < 3:
		mostrar_error("El nombre de usuario debe tener al menos 3 caracteres.")
		return

	if password.length() < 6:
		mostrar_error("La contraseña debe tener al menos 6 caracteres.")
		return

	btn_registrar.disabled = true
	label_mensaje.text = "Creando cuenta en el servidor..."
	label_mensaje.modulate = Color.WHITE

	var datos_registro: Dictionary = {
		"email": email,
		"username": username,
		"password": password
	}

	var json_enviar: String = JSON.stringify(datos_registro)

	var url: String = APIManager.base_url + "/auth/register"

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json"
	])

	var error: int = http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_enviar
	)

	if error != OK:
		btn_registrar.disabled = false
		mostrar_error("No se pudo conectar con el backend. Error: " + str(error))


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	btn_registrar.disabled = false

	var response_text: String = body.get_string_from_utf8()

	if response_code == 200 or response_code == 201:
		label_mensaje.modulate = Color.GREEN
		label_mensaje.text = "¡Cuenta creada correctamente! Volviendo al inicio..."

		await get_tree().create_timer(1.5).timeout

		get_tree().change_scene_to_file("res://menu_login.tscn")
		return

	mostrar_error(_obtener_mensaje_backend(response_code, response_text))


func _obtener_mensaje_backend(
	response_code: int,
	response_text: String
) -> String:
	if response_text.strip_edges().is_empty():
		return "Error del servidor: Código " + str(response_code)

	var parsed: Variant = JSON.parse_string(response_text)

	if typeof(parsed) == TYPE_DICTIONARY:
		var respuesta: Dictionary = parsed as Dictionary
		var detail: Variant = respuesta.get("detail", "")

		if typeof(detail) == TYPE_STRING:
			var mensaje: String = str(detail).strip_edges()

			if not mensaje.is_empty():
				return mensaje

		if typeof(detail) == TYPE_ARRAY:
			var errores: Array = detail as Array

			if not errores.is_empty():
				var primer_error: Variant = errores[0]

				if typeof(primer_error) == TYPE_DICTIONARY:
					var error_dict: Dictionary = primer_error as Dictionary
					var mensaje_validacion: String = str(
						error_dict.get(
							"msg",
							"Datos de registro inválidos."
						)
					)

					return mensaje_validacion

	return "Error del servidor: Código " + str(response_code)


func mostrar_error(mensaje: String) -> void:
	label_mensaje.text = mensaje
	label_mensaje.modulate = Color.RED
