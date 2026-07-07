extends "res://galactum_screen_base.gd"

var request: HTTPRequest
var status_label: Label
var commander_label: Label
var total_label: Label
var grid: GridContainer

func _ready():
	var shell := build_shell("INVENTARIO", "RECURSOS DISPONIBLES DEL COMANDANTE")
	status_label = shell["status"]

	var bundle := make_margin_panel()
	var summary: PanelContainer = bundle["panel"]
	var margin: MarginContainer = bundle["margin"]
	summary.custom_minimum_size.y = 92
	content_box.add_child(summary)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	commander_label = make_label("Comandante: Cargando...", 18)
	left.add_child(commander_label)
	left.add_child(make_label("Consulta de materiales almacenados en la bodega.", 14, COLOR_MUTED))
	total_label = make_label("Recursos: -", 17, COLOR_ACCENT)
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(total_label)

	content_box.add_child(make_section_title("BODEGA DE RECURSOS"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	request = HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(_on_inventory_completed)
	finish_shell()
	_load_inventory()


func _load_inventory():
	set_status(status_label, "Cargando recursos...", COLOR_WARN)
	set_footer("Consultando bodega en el servidor...")
	var error := request.request(api_url("/inventario/materiales"), auth_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		set_status(status_label, "Error de conexión", COLOR_DANGER)
		set_footer("No fue posible iniciar la consulta.", COLOR_DANGER)


func _on_inventory_completed(_result, response_code, _headers, body):
	var text: String = body.get_string_from_utf8()

	if response_code != 200:
		set_status(status_label, "Error HTTP " + str(response_code), COLOR_DANGER)
		set_footer("No se pudo cargar el inventario.", COLOR_DANGER)
		return

	var response: Variant = JSON.parse_string(text)

	if typeof(response) != TYPE_DICTIONARY:
		set_status(status_label, "Respuesta inválida", COLOR_DANGER)
		set_footer("El backend no devolvió un JSON válido.", COLOR_DANGER)
		return

	_show_inventory(response)

func _show_inventory(response: Dictionary):
	var storage = response.get("bodega", [])
	if typeof(storage) != TYPE_ARRAY:
		set_status(status_label, "Datos inválidos", COLOR_DANGER)
		set_footer("La bodega no llegó como una lista.", COLOR_DANGER)
		return
	commander_label.text = "Comandante: " + str(response.get("comandante", "Desconocido"))
	total_label.text = "Recursos: " + str(storage.size()) + " tipos"
	clear_children(grid)
	for resource in storage:
		if typeof(resource) == TYPE_DICTIONARY:
			_add_resource_card(resource)
	set_status(status_label, "Inventario cargado", COLOR_OK)
	set_footer("Recursos recibidos desde FastAPI.", COLOR_OK)


func _add_resource_card(resource: Dictionary):
	var bundle := make_margin_panel()
	var card: PanelContainer = bundle["panel"]
	var margin: MarginContainer = bundle["margin"]
	card.custom_minimum_size.y = 145
	grid.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var name := str(resource.get("recurso", "Recurso"))
	var quantity := int(resource.get("cantidad", 0))
	var unit := str(resource.get("unidad", "unidades"))
	box.add_child(make_label(_resource_icon(name) + " " + name.to_upper(), 18, COLOR_ACCENT))
	var line := HSeparator.new()
	box.add_child(line)
	box.add_child(make_label(_format_number(quantity), 28))
	box.add_child(make_label(unit, 14, COLOR_MUTED))
	box.add_child(make_label(_resource_description(name), 13, COLOR_MUTED))


func _resource_icon(name: String) -> String:
	var value := name.to_lower()
	if "helio" in value: return "⚡"
	if "titanio" in value: return "◆"
	if "crédito" in value or "credito" in value: return "◈"
	if "litio" in value: return "◉"
	if "cobre" in value: return "⬡"
	if "kliptium" in value: return "✦"
	return "▣"


func _resource_description(name: String) -> String:
	var value := name.to_lower()
	if "helio" in value: return "Combustible energético para operaciones de nave."
	if "titanio" in value: return "Material estructural para construcción y mejoras."
	if "crédito" in value or "credito" in value: return "Moneda operativa del sistema."
	return "Material almacenado en la bodega."


func _format_number(number: int) -> String:
	var text := str(number)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		result = text[i] + result
		count += 1
		if count % 3 == 0 and i > 0:
			result = "." + result
	return result
