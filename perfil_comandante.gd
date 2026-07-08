extends "res://galactum_screen_base.gd"

var request: HTTPRequest
var status_label: Label
var profile_content: VBoxContainer


func _ready() -> void:
	var shell: Dictionary = build_shell("PERFIL", "IDENTIDAD DEL COMANDANTE")
	status_label = shell["status"] as Label

	var card_bundle: Dictionary = make_margin_panel()
	var card: PanelContainer = card_bundle["panel"] as PanelContainer
	var margin: MarginContainer = card_bundle["margin"] as MarginContainer
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(card)

	profile_content = VBoxContainer.new()
	profile_content.add_theme_constant_override("separation", 14)
	margin.add_child(profile_content)
	profile_content.add_child(
		make_label("Cargando perfil del comandante...", 18, COLOR_MUTED)
	)

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_profile_completed)

	finish_shell()
	_load_profile()


func _load_profile() -> void:
	set_status(status_label, "Consultando perfil...", COLOR_WARN)
	set_footer("Solicitando perfil al backend...")

	var error: int = request.request(
		api_url("/api/v1/player/profile"),
		auth_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la solicitud.", COLOR_DANGER)


func _on_profile_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer("El backend no pudo entregar el perfil.", COLOR_DANGER)
		return

	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El perfil no llegó en formato JSON válido.", COLOR_DANGER)
		return

	var response: Dictionary = parsed as Dictionary
	var raw_data: Variant = response.get("data", {})
	var data: Dictionary = {}

	if typeof(raw_data) == TYPE_DICTIONARY:
		data = raw_data as Dictionary

	clear_children(profile_content)

	var nickname: String = str(data.get("nickname", "Sin nombre"))
	var player_id: String = str(data.get("player_id", "-"))
	var user_id: String = str(data.get("user_id", "-"))
	var local_power: String = str(APIManager.usuario_actual.get("poder", 0))

	profile_content.add_child(
		make_label("COMANDANTE " + nickname.to_upper(), 26, COLOR_ACCENT)
	)
	profile_content.add_child(make_label("Identificador de jugador: " + player_id, 16))
	profile_content.add_child(make_label("Identificador de usuario: " + user_id, 16))
	profile_content.add_child(make_label("Poder actual: " + local_power, 16))
	profile_content.add_child(
		make_label("Estado: Sesión autenticada mediante JWT.", 15, COLOR_OK)
	)

	set_status(status_label, "Perfil cargado", COLOR_OK)
	set_footer("Datos recibidos desde FastAPI.", COLOR_OK)
