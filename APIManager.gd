extends Node

# Aquí guardaremos la URL base de tu servidor (Render o Localhost)
var base_url : String = "http://127.0.0.1:8000" 

# Aquí guardaremos el token JWT cuando el jugador inicie sesión
var token_jwt : String = ""

# Esta función la usaremos después para armar los encabezados de seguridad
func get_auth_headers() -> PackedStringArray:
	if token_jwt == "":
		return ["Content-Type: application/json"]
	else:
		return [
			"Content-Type: application/json",
			"Authorization: Bearer " + token_jwt
		]
