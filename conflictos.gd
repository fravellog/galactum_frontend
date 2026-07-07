extends "res://galactum_screen_base.gd"

var list_request: HTTPRequest
var action_request: HTTPRequest
var status_label: Label
var list_box: VBoxContainer

func _ready():
	var shell := build_shell("CONFLICTOS", "OPERACIONES DE COMBATE")
	status_label = shell["status"]

	var info_bundle := make_margin_panel()
	var info_panel: PanelContainer = info_bundle["panel"]
	var info_margin: MarginContainer = info_bundle["margin"]
	content_box.add_child(info_panel)
	info_margin.add_child(make_label("Las operaciones de combate se validan en servidor. Esta versión despliega un crucero por operación para comprobar el flujo de integración.", 16, COLOR_MUTED))

	content_box.add_child(make_section_title("CONFLICTOS ACTIVOS"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 12)
	scroll.add_child(list_box)

	list_request = HTTPRequest.new()
	action_request = HTTPRequest.new()
	add_child(list_request)
	add_child(action_request)
	list_request.request_completed.connect(_on_list_completed)
	action_request.request_completed.connect(_on_attack_completed)
	finish_shell()
	_load_conflicts()


func _load_conflicts():
	set_status(status_label, "Cargando conflictos...", COLOR_WARN)
	set_footer("Consultando operaciones activas...")
	var error := list_request.request(api_url("/conflicto/activos"), auth_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la consulta.", COLOR_DANGER)


func _on_list_completed(_result, response_code, _headers, body):
	var text: String = body.get_string_from_utf8()
	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer("No se pudieron cargar los conflictos.", COLOR_DANGER)
		return
	var conflicts = JSON.parse_string(text)
	if typeof(conflicts) != TYPE_ARRAY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend no devolvió una lista de conflictos.", COLOR_DANGER)
		return
	clear_children(list_box)
	for conflict in conflicts:
		if typeof(conflict) == TYPE_DICTIONARY:
			_add_conflict_card(conflict)
	set_status(status_label, str(conflicts.size()) + " conflictos activos", COLOR_OK)
	set_footer("Selecciona una operación de combate.", COLOR_OK)


func _add_conflict_card(conflict: Dictionary):
	var bundle := make_margin_panel()
	var card: PanelContainer = bundle["panel"]
	var margin: MarginContainer = bundle["margin"]
	card.custom_minimum_size.y = 145
	list_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 6)
	row.add_child(details)
	var conflict_id := int(conflict.get("id", 0))
	details.add_child(make_label(str(conflict.get("facción_enemiga", "Facción desconocida")), 20, COLOR_ACCENT))
	details.add_child(make_label("Sector: " + str(conflict.get("sector", "-")), 15, COLOR_MUTED))
	details.add_child(make_label("Estado: " + str(conflict.get("estado", "-")) + "  |  Peligro: " + str(conflict.get("peligro", "-")), 15))

	var button := make_button("Enviar 1 crucero", COLOR_DANGER)
	button.custom_minimum_size = Vector2(150, 42)
	button.pressed.connect(_attack.bind(conflict_id))
	row.add_child(button)


func _attack(conflict_id: int):
	if conflict_id <= 0:
		set_footer("Conflicto inválido.", COLOR_DANGER)
		return
	set_status(status_label, "Desplegando flota...", COLOR_WARN)
	set_footer("Enviando orden de ataque al backend...")
	var path := "/conflicto/atacar?conflicto_id=" + str(conflict_id) + "&naves_enviadas=1"
	var error := action_request.request(api_url(path), auth_headers(), HTTPClient.METHOD_POST, "")
	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible enviar la orden de ataque.", COLOR_DANGER)


func _on_attack_completed(_result, response_code, _headers, body):
	var text: String = body.get_string_from_utf8()
	if response_code != 200:
		set_status(status_label, "Ataque rechazado", COLOR_DANGER)
		set_footer("Error HTTP " + str(response_code) + ": " + text, COLOR_DANGER)
		return
	var response = JSON.parse_string(text)
	var message := "Flota desplegada correctamente."
	if typeof(response) == TYPE_DICTIONARY:
		message = str(response.get("mensaje", message))
	set_status(status_label, "Flota en camino", COLOR_OK)
	set_footer(message, COLOR_OK)
