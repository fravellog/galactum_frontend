extends "res://galactum_screen_base.gd"

var request: HTTPRequest
var status_label: Label
var profile_content: VBoxContainer

func _ready():
	var shell := build_shell("PERFIL", "IDENTIDAD DEL COMANDANTE")
	status_label = shell["status"]

	var card_bundle := make_margin_panel()
	var card: PanelContainer = card_bundle["panel"]
	var margin: MarginContainer = card_bundle["margin"]
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(card)

	profile_content = VBoxContainer.new()
	profile_content.add_theme_constant_override("separation", 14)
	margin.add_child(profile_content)
	profile_content.add_child(make_label("Cargando perfil del comandante...", 18, COLOR_MUTED))

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_profile_completed)
	finish_shell()
	_load_profile()


func _load_profile():
	set_status(status_label, "Consultando perfil...", COLOR_WARN)
	set_footer("Solicitando perfil al backend...")
	var error := request.request(api_url("/api/v1/player/profile"), auth_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la solicitud.", COLOR_DANGER)


func _on_profile_completed(_result, response_code, _headers, body):
	var text := body.get_string_from_utf8()
	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer("El backend no pudo entregar el perfil.", COLOR_DANGER)
		return

	var response = JSON.parse_string(text)
	if typeof(response) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El perfil no llegó en formato JSON válido.", COLOR_DANGER)
		return

	var data = response.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		data = {}

	clear_children(profile_content)
	var nickname := str(data.get("nickname", "Sin nombre"))
	var player_id := str(data.get("player_id", "-"))
	var user_id := str(data.get("user_id", "-"))
	var local_power := str(APIManager.usuario_actual.get("poder", 0))

	profile_content.add_child(make_label("COMANDANTE " + nickname.to_upper(), 26, COLOR_ACCENT))
	profile_content.add_child(make_label("Identificador de jugador: " + player_id, 16))
	profile_content.add_child(make_label("Identificador de usuario: " + user_id, 16))
	profile_content.add_child(make_label("Poder actual: " + local_power, 16))
	profile_content.add_child(make_label("Estado: Sesión autenticada mediante JWT.", 15, COLOR_OK))

	set_status(status_label, "Perfil cargado", COLOR_OK)
	set_footer("Datos recibidos desde FastAPI.", COLOR_OK)
