extends "res://galactum_screen_base.gd"

var list_request: HTTPRequest
var action_request: HTTPRequest
var status_label: Label
var grid: GridContainer

func _ready():
	var shell := build_shell("MINERÍA", "ESCANEO Y EXTRACCIÓN DE ASTEROIDES")
	status_label = shell["status"]

	var info_bundle := make_margin_panel()
	var info_panel: PanelContainer = info_bundle["panel"]
	var info_margin: MarginContainer = info_bundle["margin"]
	content_box.add_child(info_panel)
	info_margin.add_child(make_label("El escáner identifica cuerpos cercanos. Cada operación de extracción se envía al backend con duración inicial de una hora.", 16, COLOR_MUTED))

	content_box.add_child(make_section_title("ASTEROIDES DETECTADOS"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	list_request = HTTPRequest.new()
	action_request = HTTPRequest.new()
	add_child(list_request)
	add_child(action_request)
	list_request.request_completed.connect(_on_scan_completed)
	action_request.request_completed.connect(_on_mining_completed)
	finish_shell()
	_scan_asteroids()


func _scan_asteroids():
	set_status(status_label, "Escaneando sector...", COLOR_WARN)
	set_footer("Consultando asteroides cercanos...")
	var error := list_request.request(api_url("/mining/asteroides"), auth_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar el escaneo.", COLOR_DANGER)


func _on_scan_completed(_result, response_code, _headers, body):
	var text: String = body.get_string_from_utf8()
	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer("No fue posible cargar asteroides.", COLOR_DANGER)
		return
	var asteroids = JSON.parse_string(text)
	if typeof(asteroids) != TYPE_ARRAY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend no devolvió una lista de asteroides.", COLOR_DANGER)
		return
	clear_children(grid)
	for asteroid in asteroids:
		if typeof(asteroid) == TYPE_DICTIONARY:
			_add_asteroid_card(asteroid)
	set_status(status_label, str(asteroids.size()) + " objetivos detectados", COLOR_OK)
	set_footer("Selecciona un objetivo para iniciar la extracción.", COLOR_OK)


func _add_asteroid_card(asteroid: Dictionary):
	var bundle := make_margin_panel()
	var card: PanelContainer = bundle["panel"]
	var margin: MarginContainer = bundle["margin"]
	card.custom_minimum_size.y = 190
	grid.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var asteroid_id := int(asteroid.get("id", 0))
	box.add_child(make_label(str(asteroid.get("nombre", "Asteroide")), 20, COLOR_ACCENT))
	box.add_child(make_label("Recurso: " + str(asteroid.get("recurso", "Desconocido")), 16))
	box.add_child(make_label("Riqueza: " + str(asteroid.get("riqueza", "-")), 15, COLOR_MUTED))
	box.add_child(make_label("Distancia: " + str(asteroid.get("distancia_al", "-")), 15, COLOR_MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var btn := make_button("Extraer durante 1 hora", COLOR_OK)
	btn.pressed.connect(_launch_mining.bind(asteroid_id))
	box.add_child(btn)


func _launch_mining(asteroid_id: int):
	if asteroid_id <= 0:
		set_footer("Asteroide inválido.", COLOR_DANGER)
		return
	set_status(status_label, "Enviando sondas...", COLOR_WARN)
	set_footer("Iniciando operación minera...")
	var path := "/mining/extraer?asteroide_id=" + str(asteroid_id) + "&horas=1"
	var error := action_request.request(api_url(path), auth_headers(), HTTPClient.METHOD_POST, "")
	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la operación.", COLOR_DANGER)


func _on_mining_completed(_result, response_code, _headers, body):
	var text: String = body.get_string_from_utf8()
	if response_code != 200:
		set_status(status_label, "Operación fallida", COLOR_DANGER)
		set_footer("Error HTTP " + str(response_code) + ": " + text, COLOR_DANGER)
		return
	var response = JSON.parse_string(text)
	var message := "Sondas mineras desplegadas correctamente."
	if typeof(response) == TYPE_DICTIONARY:
		var details = response.get("detalles", {})
		if typeof(details) == TYPE_DICTIONARY:
			message = str(details.get("mensaje", message))
	set_status(status_label, "Operación iniciada", COLOR_OK)
	set_footer(message, COLOR_OK)
